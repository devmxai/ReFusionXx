import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';

type JsonMap = Record<string, unknown>;

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, content-type, x-refusion-dev-token',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const devToken = Deno.env.get('REFUSION_MCP_DEV_TOKEN') ?? '';
const devUserId = Deno.env.get('REFUSION_MCP_DEV_USER_ID') ?? '';
const allowNoAuthDevMode =
  (Deno.env.get('REFUSION_MCP_ALLOW_NO_AUTH') ?? '').toLowerCase() === 'true';

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
});

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method === 'GET') {
    return json({
      ok: true,
      name: 'refusion-mcp',
      transport: 'streamable-http',
      message: 'Use POST for JSON-RPC MCP requests.',
    });
  }
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  let body: JsonMap;
  try {
    body = await request.json();
  } catch (_error) {
    return rpcError(null, -32700, 'Parse error.');
  }

  const id = body.id ?? null;
  try {
    return await handleRpc(request, id, body);
  } catch (error) {
    return rpcError(
      id,
      -32603,
      error instanceof Error ? error.message : String(error),
    );
  }
});

async function handleRpc(request: Request, id: unknown, body: JsonMap) {
  const method = body.method;
  if (method === 'initialize') {
    return rpcResult(id, {
      protocolVersion: '2025-03-26',
      serverInfo: { name: 'refusion-mcp', version: '0.1.0' },
      capabilities: { tools: {}, resources: {} },
    });
  }
  if (method === 'tools/list') {
    return rpcResult(id, { tools: tools() });
  }
  if (method === 'tools/call') {
    const params = readMap(body.params);
    const name = params.name;
    const args = readMap(params.arguments);
    if (typeof name !== 'string') {
      return rpcError(id, -32602, 'tools/call requires params.name.');
    }
    const userId = await resolveUserId(request);
    const result = await callTool(name, args, userId);
    return rpcResult(id, {
      isError: !result.ok,
      content: [{ type: 'text', text: result.summary }],
      structuredContent: result,
    });
  }
  return rpcError(id, -32601, `Method not found: ${method}`);
}

async function resolveUserId(request: Request): Promise<string> {
  const auth = request.headers.get('authorization') ?? '';
  const bearer = auth.toLowerCase().startsWith('bearer ')
    ? auth.slice(7).trim()
    : '';
  if (bearer) {
    const { data, error } = await admin.auth.getUser(bearer);
    if (!error && data.user?.id) {
      return data.user.id;
    }
  }

  const requestUrl = new URL(request.url);
  const providedDevToken =
    request.headers.get('x-refusion-dev-token') ??
    requestUrl.searchParams.get('dev_token') ??
    '';
  if (devToken && devUserId && providedDevToken === devToken) {
    return devUserId;
  }
  if (allowNoAuthDevMode && devUserId) {
    return devUserId;
  }
  throw new Error('Authentication required.');
}

async function callTool(name: string, args: JsonMap, userId: string) {
  const canonicalToolName = normalizeToolName(name);
  switch (canonicalToolName) {
    case 'refusion.get_active_context':
    case 'refusion.get_project_state':
      return ok('Active context loaded.', await getActiveContext(userId));
    case 'refusion.create_project':
      return ok('Project created.', await createProject(userId, args));
    case 'refusion.set_active_context':
      return ok('Active context updated.', await setActiveContext(userId, args));
    case 'refusion.touch_editor_session':
      return ok('Editor session touched.', await touchEditorSession(userId, args));
    case 'refusion.insert_layer':
      return ok('Layer inserted.', await insertLayer(userId, args));
    case 'refusion.apply_scene_program':
      return ok('Scene program applied.', await applySceneProgram(userId, args));
    case 'refusion.get_layers':
      return ok('Layers loaded.', await getLayers(userId, args));
    case 'refusion.get_command_status':
      return ok('Command status loaded.', await getCommandStatus(userId, args));
    default:
      return fail(`Unsupported command type \`${name}\`.`, {
        supportedTools: tools().map((tool) => tool.name),
      });
  }
}

function normalizeToolName(name: string): string {
  const value = name.trim();
  if (value.startsWith('refusion.')) {
    return value;
  }
  const aliases: Record<string, string> = {
    get_active_context: 'refusion.get_active_context',
    get_project_state: 'refusion.get_project_state',
    create_project: 'refusion.create_project',
    set_active_context: 'refusion.set_active_context',
    touch_editor_session: 'refusion.touch_editor_session',
    insert_layer: 'refusion.insert_layer',
    apply_scene_program: 'refusion.apply_scene_program',
    get_layers: 'refusion.get_layers',
    get_command_status: 'refusion.get_command_status',
  };
  return aliases[value] ?? value;
}

async function getActiveContext(userId: string) {
  const { data: sessionRows, error: sessionError } = await admin
    .from('refusion_editor_sessions')
    .select('*')
    .eq('owner_id', userId)
    .in('status', ['online', 'background'])
    .order('foreground', { ascending: false })
    .order('last_seen_at', { ascending: false })
    .limit(1);
  if (sessionError) throw sessionError;
  const session = (sessionRows ?? [])[0] as JsonMap | null;

  let projectId = stringValue(session?.project_id);
  let compositionId = stringValue(session?.composition_id);

  if (!projectId) {
    const project = await selectSingle('refusion_projects', {
      owner_id: userId,
      status: 'active',
    }, 'updated_at', false);
    projectId = stringValue(project?.id);
  }

  if (!projectId) {
    const created = await createProject(userId, {
      projectName: 'MCP Project',
      compositionName: 'Story',
    });
    projectId = stringValue(created.projectId);
    compositionId = stringValue(created.compositionId);
  }

  const project = await selectById('refusion_projects', projectId);
  if (!compositionId) {
    const composition = await selectSingle('refusion_compositions', {
      owner_id: userId,
      project_id: projectId,
    }, 'updated_at', false);
    compositionId = stringValue(composition?.id);
  }
  const composition = await selectById('refusion_compositions', compositionId);
  const revision = await projectRevision(projectId);

  return {
    hasProject: true,
    project: {
      id: projectId,
      name: project?.name ?? 'Untitled Project',
      revision,
    },
    composition: {
      id: compositionId,
      name: composition?.name ?? 'Story',
      aspect: composition?.aspect ?? 'story',
      width: composition?.width ?? 1080,
      height: composition?.height ?? 1920,
      durationMs: composition?.duration_ms ?? 8000,
      fps: composition?.fps ?? 30,
    },
    timeline: {
      id: session?.timeline_id ?? 'main',
      playheadMs: session?.playhead_ms ?? 0,
    },
    liveEditor: {
      online: isSessionOnline(session),
      sessionId: session?.id ?? null,
      deviceId: session?.device_id ?? null,
      foreground: session?.foreground ?? false,
      lastSeenAt: session?.last_seen_at ?? null,
    },
  };
}

async function createProject(userId: string, args: JsonMap) {
  const projectName = text(args.projectName, 'MCP Project');
  const compositionName = text(args.compositionName, 'Story');
  const aspect = text(args.aspect, 'story');
  const width = numberValue(args.width, 1080);
  const height = numberValue(args.height, 1920);
  const durationMs = numberValue(args.durationMs, 8000);
  const fps = numberValue(args.fps, 30);

  const { data: project, error: projectError } = await admin
    .from('refusion_projects')
    .insert({ owner_id: userId, name: projectName })
    .select()
    .single();
  if (projectError) throw projectError;

  const { data: composition, error: compositionError } = await admin
    .from('refusion_compositions')
    .insert({
      owner_id: userId,
      project_id: project.id,
      name: compositionName,
      aspect,
      width,
      height,
      duration_ms: durationMs,
      fps,
      is_active: true,
    })
    .select()
    .single();
  if (compositionError) throw compositionError;

  const { error: revisionError } = await admin
    .from('refusion_project_revisions')
    .insert({ owner_id: userId, project_id: project.id, revision: 1 });
  if (revisionError) throw revisionError;

  return {
    projectId: project.id,
    compositionId: composition.id,
    revision: 1,
  };
}

async function setActiveContext(userId: string, args: JsonMap) {
  const active = await getActiveContext(userId);
  const currentProjectId = stringValue(readMap(active.project).id);
  const currentCompositionId = stringValue(readMap(active.composition).id);
  const projectId = stringValue(args.projectId) || currentProjectId;
  const compositionId = stringValue(args.compositionId) || currentCompositionId;
  const deviceId = text(args.deviceId, 'chatgpt-remote');
  const timelineId = text(args.timelineId, 'main');
  const playheadMs = numberValue(args.playheadMs, 0);
  const status = text(args.status, 'online');
  const foreground = args.foreground === false ? false : true;
  const appVersion = text(args.appVersion, 'mcp-remote');
  const platform = text(args.platform, 'chatgpt');

  await touchEditorSession(userId, {
    deviceId,
    projectId,
    compositionId,
    timelineId,
    playheadMs,
    status,
    foreground,
    appVersion,
    platform,
  });

  return await getActiveContext(userId);
}

async function touchEditorSession(userId: string, args: JsonMap) {
  const active = await getActiveContext(userId);
  const projectId = stringValue(args.projectId) || stringValue(readMap(active.project).id);
  const compositionId =
    stringValue(args.compositionId) || stringValue(readMap(active.composition).id);
  const deviceId = text(args.deviceId, 'chatgpt-remote');
  const timelineId = text(args.timelineId, 'main');
  const playheadMs = numberValue(args.playheadMs, 0);
  const status = text(args.status, 'online');
  const foreground = args.foreground === false ? false : true;
  const appVersion = text(args.appVersion, 'mcp-remote');
  const platform = text(args.platform, 'chatgpt');
  const metadata = readMap(args.metadata);

  const { data: existing, error: existingError } = await admin
    .from('refusion_editor_sessions')
    .select('id')
    .eq('owner_id', userId)
    .eq('device_id', deviceId)
    .maybeSingle();
  if (existingError) throw existingError;

  const payload = {
    owner_id: userId,
    device_id: deviceId,
    project_id: projectId,
    composition_id: compositionId,
    timeline_id: timelineId,
    playhead_ms: playheadMs,
    status,
    foreground,
    app_version: appVersion,
    platform,
    metadata,
    last_seen_at: new Date().toISOString(),
  };

  if (existing?.id) {
    const { error } = await admin
      .from('refusion_editor_sessions')
      .update(payload)
      .eq('id', existing.id);
    if (error) throw error;
    return { sessionId: existing.id, deviceId, projectId, compositionId };
  }

  const { data: inserted, error } = await admin
    .from('refusion_editor_sessions')
    .insert(payload)
    .select('id')
    .single();
  if (error) throw error;
  return {
    sessionId: inserted.id,
    deviceId,
    projectId,
    compositionId,
  };
}

async function insertLayer(userId: string, args: JsonMap) {
  const context = await getActiveContext(userId);
  const project = readMap(context.project);
  const composition = readMap(context.composition);
  const projectId = stringValue(args.projectId) || stringValue(project.id);
  const compositionId =
    stringValue(args.compositionId) || stringValue(composition.id);
  const currentRevision = await projectRevision(projectId);
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('Revision conflict.', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }

  const layerKind = text(args.layerKind ?? args.kind, 'solid');
  const payload = readMap(args.payload);
  const color = text(args.color ?? payload.color, '#FFFFFF');
  const name = text(args.name, layerKind === 'solid' ? 'Background' : 'Layer');
  const durationMs = numberValue(
    args.durationMs,
    numberValue(composition.durationMs, 8000),
  );

  const { data: layer, error } = await admin
    .from('refusion_layers')
    .insert({
      owner_id: userId,
      project_id: projectId,
      composition_id: compositionId,
      layer_kind: layerKind,
      name,
      start_ms: numberValue(args.startMs, 0),
      duration_ms: durationMs,
      z_index: numberValue(args.zIndex, layerKind === 'solid' ? -1000 : 0),
      payload: {
        ...payload,
        ...(layerKind === 'solid' ? { color } : {}),
      },
      created_by: 'mcp',
    })
    .select()
    .single();
  if (error) throw error;

  const revisionAfter = currentRevision + 1;
  await updateRevision(projectId, revisionAfter);
  await recordCommand(userId, projectId, compositionId, 'refusion.insert_layer', {
    layerId: layer.id,
    layerKind,
    color,
  }, currentRevision, revisionAfter);

  return {
    projectId,
    compositionId,
    layerId: layer.id,
    revisionBefore: currentRevision,
    revisionAfter,
  };
}

async function applySceneProgram(userId: string, args: JsonMap) {
  const source = text(args.source, '');
  const color = inferColor(source) ?? '#FFFFFF';
  return await insertLayer(userId, {
    ...args,
    layerKind: 'solid',
    name: text(args.name, 'Scene Background'),
    color,
  });
}

async function getLayers(userId: string, args: JsonMap) {
  const context = await getActiveContext(userId);
  const project = readMap(context.project);
  const composition = readMap(context.composition);
  const projectId = stringValue(args.projectId) || stringValue(project.id);
  const compositionId =
    stringValue(args.compositionId) || stringValue(composition.id);
  if (!projectId || !compositionId) {
    return fail('Active project/composition is not available.');
  }
  const revision = await projectRevision(projectId);
  const { data, error } = await admin
    .from('refusion_layers')
    .select(
      'id, layer_kind, name, start_ms, duration_ms, z_index, payload, updated_at',
    )
    .eq('owner_id', userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('z_index', { ascending: true })
    .order('start_ms', { ascending: true })
    .order('created_at', { ascending: true });
  if (error) throw error;
  return {
    projectId,
    compositionId,
    revision,
    layers: data ?? [],
  };
}

async function getCommandStatus(userId: string, args: JsonMap) {
  const commandId = stringValue(args.commandId);
  if (!commandId) return fail('commandId is required.');
  const { data, error } = await admin
    .from('refusion_agent_commands')
    .select('*')
    .eq('owner_id', userId)
    .eq('id', commandId)
    .single();
  if (error) throw error;
  return data;
}

async function recordCommand(
  userId: string,
  projectId: string,
  compositionId: string,
  commandType: string,
  payload: JsonMap,
  revisionBefore: number,
  revisionAfter: number,
) {
  const { error } = await admin.from('refusion_agent_commands').insert({
    owner_id: userId,
    project_id: projectId,
    composition_id: compositionId,
    command_type: commandType,
    payload,
    revision_before: revisionBefore,
    revision_after: revisionAfter,
    status: 'succeeded',
    result: payload,
    completed_at: new Date().toISOString(),
  });
  if (error) throw error;
}

async function projectRevision(projectId: string): Promise<number> {
  const { data, error } = await admin
    .from('refusion_project_revisions')
    .select('revision')
    .eq('project_id', projectId)
    .single();
  if (error) throw error;
  return numberValue(data?.revision, 1);
}

async function updateRevision(projectId: string, revision: number) {
  const { error } = await admin
    .from('refusion_project_revisions')
    .update({ revision, updated_at: new Date().toISOString() })
    .eq('project_id', projectId);
  if (error) throw error;
}

async function selectById(table: string, id: unknown) {
  if (!id) return null;
  const { data } = await admin.from(table).select('*').eq('id', id).maybeSingle();
  return data as JsonMap | null;
}

async function selectSingle(
  table: string,
  filters: JsonMap,
  orderColumn: string,
  ascending: boolean,
) {
  let query = admin.from(table).select('*');
  for (const [key, value] of Object.entries(filters)) {
    query = query.eq(key, value);
  }
  const { data } = await query.order(orderColumn, { ascending }).limit(1)
    .maybeSingle();
  return data as JsonMap | null;
}

function tools() {
  return [
    tool(
      'refusion.get_active_context',
      'Get Active Context',
      'Return active project, composition, playhead, revision, and live editor status.',
    ),
    tool('refusion.get_project_state', 'Get Project State', 'Alias for active context.'),
    tool('refusion.create_project', 'Create Project', 'Create a project and default composition.', true),
    tool('refusion.set_active_context', 'Set Active Context', 'Set active project/composition and bind editor session.', true),
    tool('refusion.touch_editor_session', 'Touch Editor Session', 'Refresh active editor session heartbeat.', true),
    tool('refusion.insert_layer', 'Insert Layer', 'Insert a layer into the active composition.', true),
    tool('refusion.apply_scene_program', 'Apply Scene Program', 'Apply a minimal SceneProgram as a layer mutation.', true),
    tool('refusion.get_layers', 'Get Layers', 'Return composition layers ordered by z-index and start.'),
    tool('refusion.get_command_status', 'Get Command Status', 'Return a command status by id.'),
  ];
}

function tool(name: string, title: string, description: string, mutating = false) {
  return {
    name,
    title,
    description,
    inputSchema: {
      type: 'object',
      properties: {},
      additionalProperties: true,
    },
    annotations: mutating ? { destructiveHint: false, readOnlyHint: false } : {
      readOnlyHint: true,
    },
  };
}

function ok(summary: string, payload: unknown) {
  return { ok: true, summary, payload };
}

function fail(summary: string, payload: unknown = {}) {
  return { ok: false, summary, payload };
}

function rpcResult(id: unknown, value: unknown) {
  return json({ jsonrpc: '2.0', id, result: value });
}

function rpcError(id: unknown, code: number, message: string) {
  return json({ jsonrpc: '2.0', id, error: { code, message } });
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

function readMap(value: unknown): JsonMap {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as JsonMap
    : {};
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function text(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

function numberValue(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.round(value)
    : fallback;
}

function optionalNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.round(value)
    : null;
}

function inferColor(source: string): string | null {
  const match = source.match(/#[0-9a-fA-F]{6}/);
  return match ? match[0].toUpperCase() : null;
}

function isSessionOnline(session: JsonMap | null): boolean {
  if (!session?.last_seen_at) return false;
  const lastSeen = Date.parse(String(session.last_seen_at));
  return Number.isFinite(lastSeen) && Date.now() - lastSeen < 45_000;
}
