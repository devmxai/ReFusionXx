import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4';

type JsonMap = Record<string, unknown>;
type ToolResult = ReturnType<typeof ok> | ReturnType<typeof fail>;

type AgentSessionRow = {
  id: string;
  owner_id: string;
  project_id: string;
  composition_id: string;
  active_context_id: string;
  app_session_id: string;
  device_ref: string;
  granted_capabilities: string[];
  status: string;
  expires_at: string;
};

type RequestContext = {
  userId: string;
  authSource: 'agent-session' | 'bearer' | 'dev-token' | 'dev-no-auth';
  agentSession: AgentSessionRow | null;
  agentSessionToken: string | null;
};

type PairingContext = {
  userId: string;
  deviceId: string;
  deviceRefId: string;
  appSessionId: string;
  activeContextId: string;
  projectId: string;
  compositionId: string;
  timelineRevision: number;
  timelineId: string;
  playheadMs: number;
};

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers':
    'authorization, content-type, x-refusion-dev-token, x-refusion-agent-session',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const devToken = Deno.env.get('REFUSION_MCP_DEV_TOKEN') ?? '';
const devUserId = Deno.env.get('REFUSION_MCP_DEV_USER_ID') ?? '';
const allowNoAuthDevMode =
  (Deno.env.get('REFUSION_MCP_ALLOW_NO_AUTH') ?? '').toLowerCase() === 'true';
const pairingLinkBase =
  Deno.env.get('REFUSION_PAIRING_LINK_BASE') ?? 'https://refusion.app/agent/';
const agentSessionSalt = Deno.env.get('REFUSION_AGENT_SESSION_SALT') ?? '';
const pairingCodeTtlMinutes = Number.parseInt(
  Deno.env.get('REFUSION_PAIRING_CODE_TTL_MINUTES') ?? '10',
  10,
);
const agentSessionTtlHours = Number.parseInt(
  Deno.env.get('REFUSION_AGENT_SESSION_TTL_HOURS') ?? '4',
  10,
);

const publicTools = new Set<string>([
  'refusion.attach_pairing_code',
]);

const writeTools = new Set<string>([
  'refusion.insert_layer',
  'refusion.apply_scene_program',
  'refusion.apply_motion_patch',
  'refusion.apply_animation_recipe',
  'refusion.apply_keyframes',
  'refusion.keyframe_edit',
  'refusion.set_element_transform',
  'refusion.trim_clip',
  'refusion.split_clip',
  'refusion.set_layer_mask',
  'refusion.set_border',
  'refusion.set_glow',
  'refusion.set_layer_style',
  'refusion.position_at_anchor',
]);

const userOnlyTools = new Set<string>([
  'refusion.create_project',
  'refusion.set_active_context',
  'refusion.touch_editor_session',
  'refusion.sync_editor_layers',
  'refusion.generate_pairing_code',
  'refusion.get_pairing_code_status',
]);

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
      serverInfo: { name: 'refusion-mcp', version: '0.2.0' },
      capabilities: { tools: {}, resources: {} },
    });
  }
  if (method === 'tools/list') {
    return rpcResult(id, { tools: tools() });
  }
  if (method === 'tools/call') {
    const params = readMap(body.params);
    const rawName = params.name;
    const args = readMap(params.arguments);
    if (typeof rawName !== 'string') {
      return rpcError(id, -32602, 'tools/call requires params.name.');
    }
    const toolName = normalizeToolName(rawName);
    const context = await resolveRequestContext(request, toolName, args);
    const result = await callTool(toolName, rawName, args, context);
    return rpcResult(id, {
      isError: !result.ok,
      content: [{ type: 'text', text: result.summary }],
      structuredContent: result,
    });
  }
  return rpcError(id, -32601, `Method not found: ${method}`);
}

async function resolveRequestContext(
  request: Request,
  toolName: string,
  args: JsonMap,
): Promise<RequestContext> {
  const agentSessionToken = readAgentSessionToken(request, args);
  if (agentSessionToken) {
    const agentSession = await validateAgentSessionToken(agentSessionToken);
    if (!agentSession) {
      throw new Error('AGENT_SESSION_REQUIRED');
    }
    return {
      userId: agentSession.owner_id,
      authSource: 'agent-session',
      agentSession,
      agentSessionToken,
    };
  }

  if (publicTools.has(toolName)) {
    const userId = await resolveUserIdFromAuthOrDev(request);
    return {
      userId: userId ?? '',
      authSource: userId ? 'bearer' : 'dev-no-auth',
      agentSession: null,
      agentSessionToken: null,
    };
  }

  const userId = await resolveUserIdFromAuthOrDev(request);
  if (!userId) {
    throw new Error('Authentication required.');
  }
  if (writeTools.has(toolName)) {
    throw new Error('AGENT_SESSION_REQUIRED');
  }
  return {
    userId,
    authSource: request.headers.get('authorization') != null
      ? 'bearer'
      : allowNoAuthDevMode
      ? 'dev-no-auth'
      : 'dev-token',
    agentSession: null,
    agentSessionToken: null,
  };
}

async function resolveUserIdFromAuthOrDev(
  request: Request,
): Promise<string | null> {
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
  return null;
}

async function callTool(
  canonicalToolName: string,
  originalName: string,
  args: JsonMap,
  context: RequestContext,
): Promise<ToolResult> {
  switch (canonicalToolName) {
    case 'refusion.get_active_context':
    case 'refusion.get_project_state':
      return ok(
        'Active context loaded.',
        await getActiveContext(context, args),
      );
    case 'refusion.create_project':
      ensureUserTool(canonicalToolName, context);
      return ok('Project created.', await createProject(context.userId, args));
    case 'refusion.set_active_context':
      ensureUserTool(canonicalToolName, context);
      return ok(
        'Active context updated.',
        await setActiveContext(context.userId, args),
      );
    case 'refusion.touch_editor_session':
      ensureUserTool(canonicalToolName, context);
      return ok(
        'Editor session touched.',
        await touchEditorSession(context.userId, args),
      );
    case 'refusion.sync_editor_layers':
      ensureUserTool(canonicalToolName, context);
      return ok(
        'Editor layers synced.',
        await syncEditorLayers(context.userId, args),
      );
    case 'refusion.generate_pairing_code':
      ensureUserTool(canonicalToolName, context);
      return ok(
        'Pairing code generated.',
        await generatePairingCode(context.userId, args),
      );
    case 'refusion.get_pairing_code_status':
      ensureUserTool(canonicalToolName, context);
      return ok(
        'Pairing status loaded.',
        await getPairingCodeStatus(context.userId, args),
      );
    case 'refusion.attach_pairing_code':
      return await attachPairingCode(context.userId, args);
    case 'refusion.insert_layer':
      ensureAgentWrite(canonicalToolName, context);
      return await insertLayer(context, args);
    case 'refusion.apply_scene_program':
      ensureAgentWrite(canonicalToolName, context);
      return await applySceneProgram(context, args);
    case 'refusion.apply_motion_patch':
    case 'refusion.apply_animation_recipe':
      ensureAgentWrite(canonicalToolName, context);
      return await applyMotionPatch(context, args);
    case 'refusion.apply_keyframes':
      ensureAgentWrite(canonicalToolName, context);
      return await applyKeyframes(context, args);
    case 'refusion.keyframe_edit':
      ensureAgentWrite(canonicalToolName, context);
      return await keyframeEdit(context, args);
    case 'refusion.set_element_transform':
      ensureAgentWrite(canonicalToolName, context);
      return await setElementTransform(context, args);
    case 'refusion.trim_clip':
      ensureAgentWrite(canonicalToolName, context);
      return await trimClip(context, args);
    case 'refusion.split_clip':
      ensureAgentWrite(canonicalToolName, context);
      return await splitClip(context, args);
    case 'refusion.set_layer_mask':
      ensureAgentWrite(canonicalToolName, context);
      return await setLayerMask(context, args);
    case 'refusion.set_border':
      ensureAgentWrite(canonicalToolName, context);
      return await setBorder(context, args);
    case 'refusion.set_glow':
      ensureAgentWrite(canonicalToolName, context);
      return await setGlow(context, args);
    case 'refusion.set_layer_style':
      ensureAgentWrite(canonicalToolName, context);
      return await setLayerStyle(context, args);
    case 'refusion.get_layers':
      return await getLayers(context, args);
    case 'refusion.get_project_snapshot':
      return await getProjectSnapshot(context, args);
    case 'refusion.get_composition_spec':
      return await getCompositionSpec(context, args);
    case 'refusion.get_timeline_graph':
      return await getTimelineGraph(context, args);
    case 'refusion.get_media_assets':
      return await getMediaAssets(context, args);
    case 'refusion.get_scene_layers':
      return await getSceneLayers(context, args);
    case 'refusion.get_canvas_metadata':
      return await getCanvasMetadata(context, args);
    case 'refusion.get_element_geometry':
      return await getElementGeometry(context, args);
    case 'refusion.get_visual_layout_summary':
      return await getVisualLayoutSummary(context, args);
    case 'refusion.position_at_anchor':
      ensureAgentWrite(canonicalToolName, context);
      return await positionAtAnchor(context, args);
    case 'refusion.evaluate_frame':
      return await evaluateFrame(context, args);
    case 'refusion.explain_capabilities':
      return await explainCapabilities(context, args);
    case 'refusion.get_motion_channels':
      return await getMotionChannels(context, args);
    case 'refusion.get_keyframes':
      return await getKeyframes(context, args);
    case 'refusion.get_command_status':
      return await getCommandStatus(context, args);
    case 'refusion.wait_for_apply':
      return await waitForApply(context, args);
    case 'refusion.disconnect_agent':
      return await disconnectAgent(context, args);
    default:
      return fail(`Unsupported command type \`${originalName}\`.`, {
        supportedTools: tools().map((tool) => tool.name),
      });
  }
}

function ensureUserTool(toolName: string, context: RequestContext) {
  if (!userOnlyTools.has(toolName)) {
    return;
  }
  if (context.agentSession) {
    throw new Error('CAPABILITY_DENIED');
  }
}

function ensureAgentWrite(toolName: string, context: RequestContext) {
  if (!writeTools.has(toolName)) {
    return;
  }
  if (!context.agentSession) {
    throw new Error('AGENT_SESSION_REQUIRED');
  }
}

function normalizeToolName(name: string): string {
  const value = name.trim();
  const aliases: Record<string, string> = {
    get_active_context: 'refusion.get_active_context',
    get_project_state: 'refusion.get_project_state',
    create_project: 'refusion.create_project',
    set_active_context: 'refusion.set_active_context',
    touch_editor_session: 'refusion.touch_editor_session',
    sync_editor_layers: 'refusion.sync_editor_layers',
    generate_pairing_code: 'refusion.generate_pairing_code',
    get_pairing_code_status: 'refusion.get_pairing_code_status',
    attach_pairing_code: 'refusion.attach_pairing_code',
    claim_pairing_code: 'refusion.attach_pairing_code',
    connect_pairing_code: 'refusion.attach_pairing_code',
    insert_layer: 'refusion.insert_layer',
    insert_text: 'refusion.insert_layer',
    add_text: 'refusion.insert_layer',
    create_text: 'refusion.insert_layer',
    insert_shape: 'refusion.insert_layer',
    add_shape: 'refusion.insert_layer',
    set_background: 'refusion.insert_layer',
    set_solid_background: 'refusion.insert_layer',
    background_set_solid: 'refusion.insert_layer',
    apply_scene_program: 'refusion.apply_scene_program',
    apply_motion_patch: 'refusion.apply_motion_patch',
    apply_animation_recipe: 'refusion.apply_animation_recipe',
    apply_keyframes: 'refusion.apply_keyframes',
    keyframe_edit: 'refusion.keyframe_edit',
    set_element_transform: 'refusion.set_element_transform',
    trim_clip: 'refusion.trim_clip',
    split_clip: 'refusion.split_clip',
    set_layer_mask: 'refusion.set_layer_mask',
    set_border: 'refusion.set_border',
    set_glow: 'refusion.set_glow',
    set_layer_style: 'refusion.set_layer_style',
    get_layers: 'refusion.get_layers',
    get_project_snapshot: 'refusion.get_project_snapshot',
    get_composition_spec: 'refusion.get_composition_spec',
    get_timeline_graph: 'refusion.get_timeline_graph',
    get_media_assets: 'refusion.get_media_assets',
    get_scene_layers: 'refusion.get_scene_layers',
    get_canvas_metadata: 'refusion.get_canvas_metadata',
    get_element_geometry: 'refusion.get_element_geometry',
    get_visual_layout_summary: 'refusion.get_visual_layout_summary',
    position_at_anchor: 'refusion.position_at_anchor',
    align_to_anchor: 'refusion.position_at_anchor',
    place_at_anchor: 'refusion.position_at_anchor',
    evaluate_frame: 'refusion.evaluate_frame',
    explain_capabilities: 'refusion.explain_capabilities',
    get_motion_channels: 'refusion.get_motion_channels',
    get_keyframes: 'refusion.get_keyframes',
    get_command_status: 'refusion.get_command_status',
    wait_for_apply: 'refusion.wait_for_apply',
    disconnect_agent: 'refusion.disconnect_agent',
    'refusion.insert_text': 'refusion.insert_layer',
    'refusion.claim_pairing_code': 'refusion.attach_pairing_code',
    'refusion.connect_pairing_code': 'refusion.attach_pairing_code',
    'refusion.add_text': 'refusion.insert_layer',
    'refusion.create_text': 'refusion.insert_layer',
    'refusion.insert_shape': 'refusion.insert_layer',
    'refusion.add_shape': 'refusion.insert_layer',
    'refusion.set_background': 'refusion.insert_layer',
    'refusion.set_solid_background': 'refusion.insert_layer',
    'refusion.background.set_solid': 'refusion.insert_layer',
    'refusion.apply_animation_recipe': 'refusion.apply_motion_patch',
    'refusion.trim_layer': 'refusion.trim_clip',
    'refusion.split_layer': 'refusion.split_clip',
    'refusion.set_mask': 'refusion.set_layer_mask',
    'refusion.apply_mask': 'refusion.set_layer_mask',
    'refusion.set_rounded_crop': 'refusion.set_layer_mask',
    'refusion.set_layer_border': 'refusion.set_border',
    'refusion.set_layer_glow': 'refusion.set_glow',
    'refusion.surface.position.at_anchor': 'refusion.position_at_anchor',
    'refusion.surface.align_to': 'refusion.position_at_anchor',
    'refusion.surface.fit_in_zone': 'refusion.position_at_anchor',
    'refusion.surface.center_in': 'refusion.position_at_anchor',
  };
  return aliases[value] ?? (value.startsWith('refusion.') ? value : value);
}

async function getActiveContext(context: RequestContext, args: JsonMap) {
  if (context.agentSession) {
    return await getBoundContext(context.agentSession);
  }

  const { data: sessionRows, error: sessionError } = await admin
    .from('refusion_editor_sessions')
    .select('*')
    .eq('owner_id', context.userId)
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
      owner_id: context.userId,
      status: 'active',
    }, 'updated_at', false);
    projectId = stringValue(project?.id);
  }

  if (!projectId) {
    const created = await createProject(context.userId, {
      projectName: 'MCP Project',
      compositionName: 'Story',
    });
    projectId = stringValue(created.projectId);
    compositionId = stringValue(created.compositionId);
  }

  const project = await selectById('refusion_projects', projectId);
  if (!compositionId) {
    const composition = await selectSingle('refusion_compositions', {
      owner_id: context.userId,
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
    auth: {
      source: context.authSource,
      viaAgentSession: false,
    },
  };
}

async function getBoundContext(agentSession: AgentSessionRow) {
  const project = await selectById('refusion_projects', agentSession.project_id);
  const composition = await selectById(
    'refusion_compositions',
    agentSession.composition_id,
  );
  const activeContext = await selectById(
    'refusion_active_contexts',
    agentSession.active_context_id,
  );
  const revision = await projectRevision(agentSession.project_id);

  return {
    hasProject: true,
    project: {
      id: agentSession.project_id,
      name: project?.name ?? 'Untitled Project',
      revision,
    },
    composition: {
      id: agentSession.composition_id,
      name: composition?.name ?? 'Story',
      aspect: composition?.aspect ?? 'story',
      width: composition?.width ?? 1080,
      height: composition?.height ?? 1920,
      durationMs: composition?.duration_ms ?? 8000,
      fps: composition?.fps ?? 30,
    },
    timeline: {
      id: activeContext?.timeline_id ?? 'main',
      playheadMs: activeContext?.playhead_ms ?? 0,
    },
    liveEditor: {
      online: true,
      sessionId: agentSession.app_session_id,
      deviceId: null,
      foreground: true,
      lastSeenAt: null,
    },
    auth: {
      source: 'agent-session',
      viaAgentSession: true,
      agentSessionId: agentSession.id,
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
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const currentProjectId = stringValue(readMap(active.project).id);
  const currentCompositionId = stringValue(readMap(active.composition).id);
  const projectId = stringValue(args.projectId) || currentProjectId;
  const compositionId = stringValue(args.compositionId) || currentCompositionId;
  const deviceId = text(args.deviceId, 'chatgpt-remote');
  const timelineId = text(args.timelineId, 'main');
  const playheadMs = numberValue(args.playheadMs, 0);
  const timelineRevision = optionalNumber(args.timelineRevision);
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
    timelineRevision,
    status,
    foreground,
    appVersion,
    platform,
  });

  await ensurePairingContext(userId, {
    deviceId,
    projectId,
    compositionId,
    timelineId,
    playheadMs,
    timelineRevision: timelineRevision ?? await projectRevision(projectId),
  });

  return await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
}

async function touchEditorSession(userId: string, args: JsonMap) {
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const projectId = stringValue(args.projectId) || stringValue(readMap(active.project).id);
  const compositionId =
    stringValue(args.compositionId) || stringValue(readMap(active.composition).id);
  const deviceId = text(args.deviceId, 'chatgpt-remote');
  const timelineId = text(args.timelineId, 'main');
  const playheadMs = numberValue(args.playheadMs, 0);
  const timelineRevision = optionalNumber(args.timelineRevision);
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
    timeline_revision: timelineRevision ?? await projectRevision(projectId),
    status,
    foreground,
    app_version: appVersion,
    platform,
    metadata,
    last_seen_at: new Date().toISOString(),
  };

  let sessionId = '';
  if (existing?.id) {
    const { error } = await admin
      .from('refusion_editor_sessions')
      .update(payload)
      .eq('id', existing.id);
    if (error) throw error;
    sessionId = existing.id as string;
  } else {
    const { data: inserted, error } = await admin
      .from('refusion_editor_sessions')
      .insert(payload)
      .select('id')
      .single();
    if (error) throw error;
    sessionId = inserted.id as string;
  }

  await ensurePairingContext(userId, {
    deviceId,
    projectId,
    compositionId,
    timelineId,
    playheadMs,
    timelineRevision: numberValue(payload.timeline_revision, 1),
    platform,
    appVersion,
    status,
  });

  return { sessionId, deviceId, projectId, compositionId };
}

async function syncEditorLayers(userId: string, args: JsonMap) {
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const projectId = stringValue(args.projectId) || stringValue(readMap(active.project).id);
  const compositionId =
    stringValue(args.compositionId) || stringValue(readMap(active.composition).id);
  if (!projectId || !compositionId) {
    return fail('ACTIVE_CONTEXT_REQUIRED');
  }

  const incomingLayers = readList(args.layers)
    .map(readMap)
    .filter((layer) => Object.keys(layer).length > 0);
  const nowIso = new Date().toISOString();

  const { data: existingRows, error: existingError } = await admin
    .from('refusion_layers')
    .select('id, payload')
    .eq('owner_id', userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .eq('created_by', 'editor')
    .filter('payload->>syncSource', 'eq', 'editorTimeline');
  if (existingError) throw existingError;

  const existingByKey = new Map<string, JsonMap>();
  for (const row of existingRows ?? []) {
    const rowMap = readMap(row);
    const payload = readMap(rowMap.payload);
    const key = editorTimelineLayerKey(payload);
    if (key) {
      existingByKey.set(key, rowMap);
    }
  }
  const seenKeys = new Set<string>();

  let syncedCount = 0;
  for (let index = 0; index < incomingLayers.length; index += 1) {
    const layer = incomingLayers[index];
    const payload = sanitizeLayerPayload(readMap(layer.payload));
    const key = editorTimelineLayerKey(payload);
    if (key) {
      seenKeys.add(key);
    }
    const existing = key ? existingByKey.get(key) : null;
    const existingPayload = readMap(existing?.payload);
    const nextPayload = mergeEditorTimelinePayload(existingPayload, {
      ...payload,
      syncSource: 'editorTimeline',
      syncedAt: nowIso,
    });
    const layerKind = inferLayerKind(
      {
        ...nextPayload,
        kind: firstDefined(layer.layerKind, layer.layer_kind, nextPayload.kind),
        type: firstDefined(layer.type, nextPayload.type),
      },
      nextPayload,
    );
    const row = {
      layer_kind: layerKind === 'solid' ? 'media' : layerKind,
      name: text(
        firstDefined(layer.name, nextPayload.name, nextPayload.label),
        `Editor Media ${index + 1}`,
      ),
      start_ms: Math.max(0, numberValue(firstDefined(layer.startMs, layer.start_ms), 0)),
      duration_ms: Math.max(1, numberValue(firstDefined(layer.durationMs, layer.duration_ms), 1)),
      z_index: numberValue(firstDefined(layer.zIndex, layer.z_index), index),
      payload: nextPayload,
      created_by: 'editor',
    };

    if (existing?.id) {
      const { error: updateError } = await admin
        .from('refusion_layers')
        .update(row)
        .eq('id', existing.id);
      if (updateError) throw updateError;
    } else {
      const { error: insertError } = await admin.from('refusion_layers').insert({
        ...row,
        owner_id: userId,
        project_id: projectId,
        composition_id: compositionId,
      });
      if (insertError) throw insertError;
    }
    syncedCount += 1;
  }

  const staleIds = <string[]>[];
  for (const row of existingRows ?? []) {
    const rowMap = readMap(row);
    const key = editorTimelineLayerKey(readMap(rowMap.payload));
    const rowId = stringValue(rowMap.id);
    if (key && rowId && !seenKeys.has(key)) {
      staleIds.push(rowId);
    }
  }
  if (staleIds.length > 0) {
    const { error: staleDeleteError } = await admin
      .from('refusion_layers')
      .delete()
      .in('id', staleIds);
    if (staleDeleteError) throw staleDeleteError;
  }

  return {
    projectId,
    compositionId,
    syncedCount,
    staleRemovedCount: staleIds.length,
    syncedAt: nowIso,
  };
}

function editorTimelineLayerKey(payload: JsonMap): string {
  return firstText(
    payload.localLayerId,
    payload.clipId,
    payload.assetId && `asset:${payload.assetId}`,
  );
}

function mergeEditorTimelinePayload(
  existingPayload: JsonMap,
  incomingPayload: JsonMap,
): JsonMap {
  const existingStyle = readMap(existingPayload.style);
  const incomingStyle = readMap(incomingPayload.style);
  const preserved: JsonMap = {};
  for (const key of [
    'mask',
    'maskType',
    'border',
    'borderWidth',
    'borderColor',
    'glow',
    'animation',
    'effects',
    'style',
  ]) {
    if (existingPayload[key] != null && incomingPayload[key] == null) {
      preserved[key] = existingPayload[key];
    }
  }
  return {
    ...incomingPayload,
    ...preserved,
    style: {
      ...existingStyle,
      ...incomingStyle,
    },
  };
}

async function generatePairingCode(userId: string, args: JsonMap) {
  const context = await ensurePairingContext(userId, {
    deviceId: text(args.deviceId, ''),
    projectId: stringValue(args.projectId),
    compositionId: stringValue(args.compositionId),
    timelineId: text(args.timelineId, 'main'),
    playheadMs: numberValue(args.playheadMs, 0),
    timelineRevision: optionalNumber(args.timelineRevision) ?? 1,
    platform: text(args.platform, 'flutter'),
    appVersion: text(args.appVersion, 'refusion-app'),
    status: text(args.status, 'online'),
  });

  const generatedAt = new Date();
  const expiresAt = pairingCodeExpiresAtFrom(generatedAt);

  const existing = await reusablePairingCodeForContext(context);
  if (existing) {
    if (!isSafePairingCode(text(existing.code, ''))) {
      await admin.from('refusion_pairing_codes').update({
        status: 'revoked',
        revoked_at: generatedAt.toISOString(),
        revoke_reason: 'unsafe_pairing_code_regenerated',
      }).eq('id', existing.id);
    } else {
      const { error } = await admin.from('refusion_pairing_codes').update({
        expires_at: expiresAt.toISOString(),
      }).eq('id', existing.id);
      if (error) throw error;
      return pairingCodePayload(
        text(existing.code, ''),
        expiresAt,
        context,
        {
          status: text(existing.status, 'pending'),
          claimedAt: stringValue(existing.claimed_at),
          claimedByAgent: stringValue(existing.claimed_by_agent),
        },
      );
    }
  }

  const code = await generateUniquePairingCode();

  const { error } = await admin.from('refusion_pairing_codes').insert({
    code,
    owner_id: context.userId,
    device_ref: context.deviceRefId,
    app_session_id: context.appSessionId,
    active_context_id: context.activeContextId,
    project_id: context.projectId,
    composition_id: context.compositionId,
    timeline_revision: context.timelineRevision,
    status: 'pending',
    generated_at: generatedAt.toISOString(),
    expires_at: expiresAt.toISOString(),
  });
  if (error) throw error;

  await recordAuditEvent(context.userId, context.projectId, context.compositionId, {
    actor: 'user',
    eventType: 'pairing.generated',
    payload: {
      code,
      expiresAt: expiresAt.toISOString(),
      deviceId: context.deviceId,
    },
  });

  return pairingCodePayload(code, expiresAt, context, { status: 'pending' });
}

async function reusablePairingCodeForContext(context: PairingContext) {
  const { data, error } = await admin
    .from('refusion_pairing_codes')
    .select('*')
    .eq('owner_id', context.userId)
    .eq('app_session_id', context.appSessionId)
    .eq('project_id', context.projectId)
    .eq('composition_id', context.compositionId)
    .in('status', ['pending', 'claimed'])
    .order('generated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as JsonMap | null;
}

function pairingCodeExpiresAtFrom(anchor: Date): Date {
  return new Date(
    anchor.getTime() + safeTtlMinutes(pairingCodeTtlMinutes) * 60_000,
  );
}

function pairingCodePayload(
  code: string,
  expiresAt: Date,
  context: PairingContext,
  lifecycle: {
    status: string;
    claimedAt?: string;
    claimedByAgent?: string;
  },
) {
  return {
    code,
    status: lifecycle.status,
    claimedAt: lifecycle.claimedAt ?? '',
    claimedByAgent: lifecycle.claimedByAgent ?? '',
    expiresAt: expiresAt.toISOString(),
    qrData: `refusion://agent/${code}`,
    link: `${pairingLinkBase.replace(/\/+$/, '')}/${code}`,
    context: {
      projectId: context.projectId,
      compositionId: context.compositionId,
      timelineId: context.timelineId,
      playheadMs: context.playheadMs,
      timelineRevision: context.timelineRevision,
      deviceId: context.deviceId,
    },
  };
}

async function getPairingCodeStatus(userId: string, args: JsonMap) {
  const code = normalizePairingCode(stringValue(args.code));
  if (!code) {
    throw new Error('PAIRING_CODE_REQUIRED');
  }
  const { data: row, error } = await admin
    .from('refusion_pairing_codes')
    .select('*')
    .eq('owner_id', userId)
    .eq('code', code)
    .maybeSingle();
  if (error) throw error;
  if (!row) {
    return {
      code,
      status: 'not_found',
      exists: false,
    };
  }
  let status = text(row.status, 'pending');
  if (!isSafePairingCode(code) && (status === 'pending' || status === 'claimed')) {
    status = 'revoked';
    await admin.from('refusion_pairing_codes').update({
      status,
      revoked_at: new Date().toISOString(),
      revoke_reason: 'unsafe_pairing_code_regenerated',
    }).eq('id', row.id);
  }
  let expiresAtIso = stringValue(row.expires_at);
  let expiresAtMs = Date.parse(expiresAtIso);
  const nowMs = Date.now();
  const isExpired = Number.isFinite(expiresAtMs) && expiresAtMs <= nowMs;
  if (status === 'pending' && isExpired) {
    status = 'expired';
    await admin.from('refusion_pairing_codes')
      .update({ status: 'expired' })
      .eq('id', row.id);
  } else if (
    args.keepAlive === true && (status === 'pending' || status === 'claimed')
  ) {
    const keepAliveExpiresAt = pairingCodeExpiresAtFrom(new Date());
    const { error: keepAliveError } = await admin
      .from('refusion_pairing_codes')
      .update({ expires_at: keepAliveExpiresAt.toISOString() })
      .eq('id', row.id);
    if (keepAliveError) throw keepAliveError;
    expiresAtIso = keepAliveExpiresAt.toISOString();
    expiresAtMs = keepAliveExpiresAt.getTime();
  }
  const secondsRemaining = !Number.isFinite(expiresAtMs)
    ? 0
    : Math.max(0, Math.floor((expiresAtMs - nowMs) / 1000));
  return {
    exists: true,
    code,
    status,
    nextAction: status === 'pending'
      ? 'agent_call_attach_pairing_code_now'
      : status === 'claimed'
      ? 'agent_may_call_attach_pairing_code_again_to_get_its_own_session_token'
      : 'generate_new_pairing_code_in_app',
    agentInstruction: status === 'pending'
      ? 'Do not wait for app approval. Pending means the app is waiting for the agent. Call refusion.attach_pairing_code with this code to claim it.'
      : status === 'claimed'
      ? 'The code has already been claimed once. Call refusion.attach_pairing_code again if this agent needs its own session token.'
      : 'This code cannot be attached. Ask the user to generate a new numeric REF code from the ReFusion app.',
    generatedAt: stringValue(row.generated_at),
    expiresAt: expiresAtIso,
    claimedAt: stringValue(row.claimed_at),
    claimedByAgent: stringValue(row.claimed_by_agent),
    revokedAt: stringValue(row.revoked_at),
    revokeReason: stringValue(row.revoke_reason),
    failedAttempts: numberValue(row.failed_attempts, 0),
    projectId: stringValue(row.project_id),
    compositionId: stringValue(row.composition_id),
    isExpired,
    secondsRemaining,
  };
}

async function attachPairingCode(
  fallbackUserId: string,
  args: JsonMap,
): Promise<ToolResult> {
  const code = normalizePairingCode(stringValue(args.code));
  const agentClientName = text(args.agentClientName, 'unknown');
  const agentClientVersion = text(args.agentClientVersion, '');
  if (!code) {
    return fail('PAIRING_CODE_REQUIRED');
  }
  if (!isSafePairingCode(code)) {
    return fail('PAIRING_CODE_UNSAFE_REGENERATE', {
      hint: 'Generate a new numeric pairing code from the ReFusion app.',
    });
  }

  const { data: pairingRow, error } = await admin
    .from('refusion_pairing_codes')
    .select('*')
    .eq('code', code)
    .maybeSingle();
  if (error) throw error;
  if (!pairingRow) {
    return fail('PAIRING_CODE_NOT_FOUND');
  }

  const status = text(pairingRow.status, 'pending');
  const failedAttempts = numberValue(pairingRow.failed_attempts, 0);
  if (status === 'locked' || failedAttempts >= 5) {
    return fail('PAIRING_CODE_LOCKED');
  }
  if (status !== 'pending' && status !== 'claimed') {
    return fail('PAIRING_CODE_NOT_CLAIMABLE', { status });
  }
  const expiresAt = Date.parse(String(pairingRow.expires_at));
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    await admin.from('refusion_pairing_codes').update({ status: 'expired' }).eq(
      'id',
      pairingRow.id,
    );
    return fail('PAIRING_CODE_EXPIRED');
  }

  const ownerId = stringValue(pairingRow.owner_id) || fallbackUserId;
  if (!ownerId) {
    return fail('PAIRING_OWNER_NOT_FOUND');
  }

  const tokenRaw = `rfx_agent_${randomAlphaNumeric(40)}`;
  const tokenHash = await digestToken(tokenRaw);
  const now = new Date();
  const sessionExpiresAt = new Date(
    now.getTime() + safeTtlHours(agentSessionTtlHours) * 3_600_000,
  );
  const capabilities = [
    'project.read',
    'timeline.read',
    'timeline.write',
    'scene.write',
    'motion.write',
    'preview.read',
  ];

  const { data: agentSession, error: sessionError } = await admin
    .from('refusion_agent_sessions')
    .insert({
      owner_id: ownerId,
      device_ref: pairingRow.device_ref,
      app_session_id: pairingRow.app_session_id,
      active_context_id: pairingRow.active_context_id,
      project_id: pairingRow.project_id,
      composition_id: pairingRow.composition_id,
      token_hash: tokenHash,
      agent_client_name: agentClientName,
      agent_client_version: agentClientVersion,
      granted_capabilities: capabilities,
      status: 'active',
      created_at: now.toISOString(),
      last_used_at: now.toISOString(),
      expires_at: sessionExpiresAt.toISOString(),
    })
    .select()
    .single();
  if (sessionError) throw sessionError;

  const { error: pairingUpdateError } = await admin.from('refusion_pairing_codes').update({
    status: 'claimed',
    claimed_at: now.toISOString(),
    claimed_by_agent: agentClientName,
  }).eq('id', pairingRow.id);
  if (pairingUpdateError) throw pairingUpdateError;

  const activeContext = await selectById(
    'refusion_active_contexts',
    pairingRow.active_context_id,
  );

  await recordAuditEvent(ownerId, stringValue(pairingRow.project_id), stringValue(pairingRow.composition_id), {
    actor: 'agent',
    eventType: 'pairing.claimed',
    payload: {
      code,
      agentClientName,
      agentSessionId: agentSession.id,
    },
  });

  return ok('Pairing attached.', {
    agentSessionToken: tokenRaw,
    agentSessionId: agentSession.id,
    codeStatusBeforeAttach: status,
    codeStatusAfterAttach: 'claimed',
    agentInstruction:
      'Use agentSessionToken on all subsequent ReFusion MCP write/read calls. The app does not need a separate approval tap after code generation.',
    context: {
      projectId: pairingRow.project_id,
      compositionId: pairingRow.composition_id,
      timelineId: activeContext?.timeline_id ?? 'main',
      playheadMs: activeContext?.playhead_ms ?? 0,
      timelineRevision: pairingRow.timeline_revision ?? 1,
    },
    capabilities,
    expiresAt: sessionExpiresAt.toISOString(),
  });
}

async function disconnectAgent(context: RequestContext, args: JsonMap) {
  if (context.agentSession) {
    const { error } = await admin.from('refusion_agent_sessions').update({
      status: 'revoked',
      revoked_at: new Date().toISOString(),
      revoke_reason: text(args.reason, 'agent_disconnect'),
    }).eq('id', context.agentSession.id);
    if (error) throw error;
    return ok('Agent disconnected.', { disconnected: true });
  }

  const targetAgentSessionId = stringValue(args.agentSessionId);
  if (!targetAgentSessionId) {
    const { error } = await admin.from('refusion_agent_sessions').update({
      status: 'revoked',
      revoked_at: new Date().toISOString(),
      revoke_reason: text(args.reason, 'owner_revoke_all'),
    }).eq('owner_id', context.userId).eq('status', 'active');
    if (error) throw error;
    return ok('All active agents revoked.', { revokedAll: true });
  }

  const { error } = await admin.from('refusion_agent_sessions').update({
    status: 'revoked',
    revoked_at: new Date().toISOString(),
    revoke_reason: text(args.reason, 'owner_revoke_single'),
  }).eq('owner_id', context.userId).eq('id', targetAgentSessionId);
  if (error) throw error;
  return ok('Agent disconnected.', {
    agentSessionId: targetAgentSessionId,
    disconnected: true,
  });
}

async function insertLayer(context: RequestContext, args: JsonMap): Promise<ToolResult> {
  const operation = firstText(
    args.operation,
    args.command,
    args.action,
    readMap(args.payload).operation,
  ).toLowerCase();
  if (
    operation.includes('animate') ||
    operation.includes('keyframe') ||
    operation.includes('transform')
  ) {
    return fail(
      'INSERT_LAYER_CANNOT_BE_USED_FOR_ANIMATION',
      { hint: 'Use refusion.apply_motion_patch / refusion.keyframe_edit / refusion.set_element_transform.' },
    );
  }
  const boundProjectId = context.agentSession?.project_id ?? '';
  const boundCompositionId = context.agentSession?.composition_id ?? '';
  const activeContext = await getActiveContext(context, {});
  const project = readMap(activeContext.project);
  const composition = readMap(activeContext.composition);
  const projectId = boundProjectId || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = boundCompositionId || stringValue(args.compositionId) ||
    stringValue(composition.id);
  const currentRevision = await projectRevision(projectId);
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }

  const payload = canonicalLayerPayload(args);
  const layerKind = inferLayerKind(args, payload);
  const color = inferLayerColor(args, payload) ?? '#FFFFFF';
  const name = text(
    args.name ?? payload.name,
    layerKind === 'solid' ? 'Background' : layerKind === 'text' ? 'Text' : 'Layer',
  );
  const durationMs = numberValue(
    firstDefined(
      args.durationMs,
      args.duration,
      args.endMs != null && args.startMs != null
        ? numberValue(args.endMs, 0) - numberValue(args.startMs, 0)
        : undefined,
      payload.durationMs,
      payload.duration_ms,
    ),
    numberValue(composition.durationMs, 8000),
  );
  const startMs = numberValue(
    firstDefined(args.startMs, args.start, args.startTimeMs, payload.startMs, payload.start_ms),
    0,
  );
  const zIndex = numberValue(
    firstDefined(args.zIndex, args.z_index, payload.zIndex, payload.z_index),
    layerKind === 'solid' ? -1000 : 0,
  );

  const { data: layer, error } = await admin
    .from('refusion_layers')
    .insert({
      owner_id: context.userId,
      project_id: projectId,
      composition_id: compositionId,
      layer_kind: layerKind,
      name,
      start_ms: startMs,
      duration_ms: durationMs,
      z_index: zIndex,
      payload: {
        ...payload,
        ...(layerKind === 'solid' ? { color } : {}),
      },
      created_by: context.agentSession ? 'mcp-agent' : 'mcp',
    })
    .select()
    .single();
  if (error) throw error;

  const revisionAfter = currentRevision + 1;
  await updateRevision(projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    projectId,
    compositionId,
    'refusion.insert_layer',
    {
      layerId: layer.id,
      layerKind,
      name,
      startMs,
      durationMs,
      zIndex,
      payload: {
        ...payload,
        ...(layerKind === 'solid' ? { color } : {}),
      },
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );

  return ok('Layer inserted.', {
    projectId,
    compositionId,
    layerId: layer.id,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
  });
}

async function applySceneProgram(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const operation = firstText(args.operation, args.action, args.command).toLowerCase();
  if (
    operation.includes('animate') ||
    operation.includes('keyframe') ||
    operation.includes('transform')
  ) {
    return fail(
      'SCENE_PROGRAM_CANNOT_BE_USED_FOR_ANIMATION',
      { hint: 'Use refusion.apply_motion_patch, refusion.apply_keyframes, or refusion.set_element_transform.' },
    );
  }
  const source = text(args.source, '');
  const color = inferColor(source) ?? '#FFFFFF';
  return await insertLayer(context, {
    ...args,
    layerKind: 'solid',
    name: text(args.name, 'Scene Background'),
    color,
  });
}

async function applyMotionPatch(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const active = await getActiveContext(context, {});
  const project = readMap(active.project);
  const composition = readMap(active.composition);
  const projectId = context.agentSession?.project_id || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = context.agentSession?.composition_id || stringValue(args.compositionId) ||
    stringValue(composition.id);
  if (!projectId || !compositionId) {
    return fail('PROJECT_NOT_OPEN');
  }
  const currentRevision = await projectRevision(projectId);
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }

  const layerId = firstText(
    args.layerId,
    args.layer_id,
    args.targetLayerId,
    readMap(args.payload).layerId,
  );
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const { data: layer, error: layerError } = await admin
    .from('refusion_layers')
    .select('id')
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .eq('id', layerId)
    .maybeSingle();
  if (layerError) throw layerError;
  if (!layer) {
    return fail('LAYER_NOT_FOUND');
  }

  const writes = inferMotionWrites(args);
  if (writes.length === 0) {
    return fail('MOTION_CHANNELS_REQUIRED');
  }

  for (const write of writes) {
    const { error } = await admin
      .from('refusion_motion_channels')
      .upsert({
        owner_id: context.userId,
        project_id: projectId,
        composition_id: compositionId,
        layer_id: layerId,
        property_id: write.propertyId,
        motion_recipe: write.motionRecipe,
        keyframes: write.keyframes,
        created_by: context.agentSession ? 'mcp-agent' : 'mcp',
      }, {
        onConflict: 'owner_id,project_id,composition_id,layer_id,property_id',
      });
    if (error) throw error;
  }

  const revisionAfter = currentRevision + 1;
  await updateRevision(projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    projectId,
    compositionId,
    'refusion.apply_motion_patch',
    {
      layerId,
      writes,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Motion patch applied.', {
    projectId,
    compositionId,
    layerId,
    channels: writes.length,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
  });
}

async function applyKeyframes(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  return await applyMotionPatch(context, args);
}

async function keyframeEdit(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const active = await getActiveContext(context, {});
  const project = readMap(active.project);
  const composition = readMap(active.composition);
  const projectId = context.agentSession?.project_id || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = context.agentSession?.composition_id || stringValue(args.compositionId) ||
    stringValue(composition.id);
  if (!projectId || !compositionId) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layerId = firstText(args.layerId, args.layer_id, args.targetLayerId);
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const propertyId = canonicalMotionPropertyId(
    firstText(args.propertyId, args.property, args.targetProperty),
  );
  if (!propertyId) {
    return fail('PROPERTY_ID_REQUIRED');
  }
  const { data: existing, error: existingError } = await admin
    .from('refusion_motion_channels')
    .select('id, keyframes')
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .eq('layer_id', layerId)
    .eq('property_id', propertyId)
    .maybeSingle();
  if (existingError) throw existingError;
  if (!existing) {
    return fail('MOTION_CHANNEL_NOT_FOUND');
  }
  const action = firstText(args.action, 'set').toLowerCase();
  const currentKeyframes = parseKeyframes(existing.keyframes);
  const timeMs = numberValue(args.timeMs, -1);
  const keyframeId = firstText(args.keyframeId);
  const index = currentKeyframes.findIndex((entry) =>
    (keyframeId && stringValue(entry.id) === keyframeId) ||
    (timeMs >= 0 && numberValue(entry.timeMs, -1) === timeMs)
  );
  if (action === 'delete') {
    if (index < 0) {
      return fail('KEYFRAME_NOT_FOUND');
    }
    currentKeyframes.splice(index, 1);
  } else {
    const update = parseKeyframe(firstDefined(
      args.keyframe,
      readMap(args.payload).keyframe,
      {
        id: keyframeId,
        timeMs: timeMs >= 0 ? timeMs : optionalNumber(args.time),
        value: args.value,
        easing: args.easing,
      },
    ));
    if (!update) {
      return fail('KEYFRAME_INVALID');
    }
    if (index < 0) {
      currentKeyframes.push(update);
    } else {
      currentKeyframes[index] = update;
    }
  }
  currentKeyframes.sort((a, b) =>
    numberValue(a.timeMs, 0) - numberValue(b.timeMs, 0));
  const { error } = await admin
    .from('refusion_motion_channels')
    .update({
      keyframes: currentKeyframes,
      updated_at: new Date().toISOString(),
    })
    .eq('id', existing.id);
  if (error) throw error;
  const currentRevision = await projectRevision(projectId);
  const revisionAfter = currentRevision + 1;
  await updateRevision(projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    projectId,
    compositionId,
    'refusion.keyframe_edit',
    {
      layerId,
      propertyId,
      action,
      keyframeCount: currentKeyframes.length,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Keyframe edit applied.', {
    projectId,
    compositionId,
    layerId,
    propertyId,
    keyframeCount: currentKeyframes.length,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
  });
}

async function setElementTransform(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const layerId = firstText(args.layerId, args.layer_id, args.targetLayerId);
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const timeMs = numberValue(firstDefined(args.timeMs, args.time, 0), 0);
  const keyframes: JsonMap[] = [];
  const x = optionalNumber(firstDefined(args.x, args.positionX, args.translateX));
  const y = optionalNumber(firstDefined(args.y, args.positionY, args.translateY));
  const scaleX = numberOrNull(firstDefined(args.scaleX, args.scale));
  const scaleY = numberOrNull(firstDefined(args.scaleY, args.scale));
  const rotation = numberOrNull(firstDefined(args.rotation, args.rotationDegrees));
  const opacity = numberOrNull(args.opacity);
  if (x != null) {
    keyframes.push({
      propertyId: 'transform.position.x',
      keyframes: [makeScalarKeyframe(timeMs, x)],
    });
  }
  if (y != null) {
    keyframes.push({
      propertyId: 'transform.position.y',
      keyframes: [makeScalarKeyframe(timeMs, y)],
    });
  }
  if (scaleX != null) {
    keyframes.push({
      propertyId: 'transform.scale.x',
      keyframes: [makeScalarKeyframe(timeMs, scaleX)],
    });
  }
  if (scaleY != null) {
    keyframes.push({
      propertyId: 'transform.scale.y',
      keyframes: [makeScalarKeyframe(timeMs, scaleY)],
    });
  }
  if (rotation != null) {
    keyframes.push({
      propertyId: 'transform.rotation.degrees',
      keyframes: [makeScalarKeyframe(timeMs, rotation)],
    });
  }
  if (opacity != null) {
    keyframes.push({
      propertyId: 'visual.opacity',
      keyframes: [makeScalarKeyframe(timeMs, opacity)],
    });
  }
  if (keyframes.length === 0) {
    return fail('NO_TRANSFORM_VALUES');
  }
  const payload: JsonMap = {
    ...args,
    layerId,
    channels: keyframes,
  };
  return await applyMotionPatch(context, payload);
}

async function trimClip(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const rawLayerId = firstText(args.layerId, args.layer_id, args.clipId, args.clip_id);
  const layerId = rawLayerId.startsWith('clip:') ? rawLayerId.slice(5) : rawLayerId;
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const { data: layer, error: layerError } = await admin
    .from('refusion_layers')
    .select('*')
    .eq('owner_id', context.userId)
    .eq('project_id', resolved.projectId)
    .eq('composition_id', resolved.compositionId)
    .eq('id', layerId)
    .maybeSingle();
  if (layerError) throw layerError;
  if (!layer) {
    return fail('LAYER_NOT_FOUND');
  }
  const currentRevision = resolved.revision;
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }
  const startMs = Math.max(
    0,
    numberValue(firstDefined(args.timelineStartMs, args.startMs, layer.start_ms), numberValue(layer.start_ms, 0)),
  );
  const durationMs = Math.max(
    1,
    numberValue(
      firstDefined(args.timelineDurationMs, args.durationMs, layer.duration_ms),
      numberValue(layer.duration_ms, 1000),
    ),
  );
  const payload = readMap(layer.payload);
  const sourceStartMs = Math.max(
    0,
    numberValue(
      firstDefined(args.sourceStartMs, payload.sourceStartMs, payload.source_start_ms, 0),
      0,
    ),
  );
  const sourceDurationMs = Math.max(
    1,
    numberValue(
      firstDefined(args.sourceDurationMs, payload.sourceDurationMs, payload.source_duration_ms, durationMs),
      durationMs,
    ),
  );
  const nextPayload = {
    ...payload,
    sourceStartMs,
    sourceDurationMs,
  };
  const { error: updateError } = await admin
    .from('refusion_layers')
    .update({
      start_ms: startMs,
      duration_ms: durationMs,
      payload: nextPayload,
      updated_at: new Date().toISOString(),
    })
    .eq('id', layerId);
  if (updateError) throw updateError;
  const revisionAfter = currentRevision + 1;
  await updateRevision(resolved.projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    resolved.projectId,
    resolved.compositionId,
    'refusion.trim_clip',
    {
      layerId,
      timelineStartMs: startMs,
      timelineDurationMs: durationMs,
      sourceStartMs,
      sourceDurationMs,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Clip trimmed.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
    clip: {
      clipId: `clip:${layerId}`,
      timelineStartMs: startMs,
      timelineDurationMs: durationMs,
      sourceStartMs,
      sourceDurationMs,
    },
  });
}

async function splitClip(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const rawLayerId = firstText(args.layerId, args.layer_id, args.clipId, args.clip_id);
  const layerId = rawLayerId.startsWith('clip:') ? rawLayerId.slice(5) : rawLayerId;
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const { data: layer, error: layerError } = await admin
    .from('refusion_layers')
    .select('*')
    .eq('owner_id', context.userId)
    .eq('project_id', resolved.projectId)
    .eq('composition_id', resolved.compositionId)
    .eq('id', layerId)
    .maybeSingle();
  if (layerError) throw layerError;
  if (!layer) {
    return fail('LAYER_NOT_FOUND');
  }
  const currentRevision = resolved.revision;
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }
  const originalStartMs = numberValue(layer.start_ms, 0);
  const originalDurationMs = Math.max(1, numberValue(layer.duration_ms, 1));
  const splitTimeMs = numberValue(
    firstDefined(args.splitTimeMs, args.timeMs, args.atMs),
    originalStartMs + Math.floor(originalDurationMs / 2),
  );
  if (splitTimeMs <= originalStartMs || splitTimeMs >= originalStartMs + originalDurationMs) {
    return fail('SPLIT_OUT_OF_RANGE', {
      splitTimeMs,
      clipStartMs: originalStartMs,
      clipEndMs: originalStartMs + originalDurationMs,
    });
  }
  const leftDurationMs = splitTimeMs - originalStartMs;
  const rightDurationMs = originalDurationMs - leftDurationMs;
  const payload = readMap(layer.payload);
  const sourceStartMs = numberValue(
    firstDefined(payload.sourceStartMs, payload.source_start_ms, 0),
    0,
  );
  const sourceDurationMs = numberValue(
    firstDefined(payload.sourceDurationMs, payload.source_duration_ms, originalDurationMs),
    originalDurationMs,
  );
  const splitGroupId = firstText(
    payload.splitGroupId,
    payload.split_group_id,
    `split_${randomBase32(8).toLowerCase()}`,
  );
  const leftSourceDurationMs = Math.min(sourceDurationMs, leftDurationMs);
  const rightSourceStartMs = sourceStartMs + leftSourceDurationMs;
  const rightSourceDurationMs = Math.max(1, sourceDurationMs - leftSourceDurationMs);
  const leftPayload = {
    ...payload,
    splitGroupId,
    sourceStartMs,
    sourceDurationMs: leftSourceDurationMs,
  };
  const rightPayload = {
    ...payload,
    splitGroupId,
    sourceStartMs: rightSourceStartMs,
    sourceDurationMs: rightSourceDurationMs,
  };
  const { error: leftUpdateError } = await admin
    .from('refusion_layers')
    .update({
      duration_ms: leftDurationMs,
      payload: leftPayload,
      updated_at: new Date().toISOString(),
    })
    .eq('id', layerId);
  if (leftUpdateError) throw leftUpdateError;
  const { data: rightLayer, error: rightInsertError } = await admin
    .from('refusion_layers')
    .insert({
      owner_id: context.userId,
      project_id: resolved.projectId,
      composition_id: resolved.compositionId,
      layer_kind: text(layer.layer_kind, 'media'),
      name: text(layer.name, 'Layer'),
      start_ms: splitTimeMs,
      duration_ms: rightDurationMs,
      z_index: numberValue(layer.z_index, 0),
      payload: rightPayload,
      parent_layer_id: stringValue(layer.parent_layer_id) || null,
      created_by: context.agentSession ? 'mcp-agent' : 'mcp',
    })
    .select('id')
    .single();
  if (rightInsertError) throw rightInsertError;
  const revisionAfter = currentRevision + 1;
  await updateRevision(resolved.projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    resolved.projectId,
    resolved.compositionId,
    'refusion.split_clip',
    {
      layerId,
      newLayerId: stringValue(rightLayer?.id),
      splitTimeMs,
      splitGroupId,
      leftDurationMs,
      rightDurationMs,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Clip split.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
    split: {
      splitTimeMs,
      splitGroupId,
      left: {
        layerId,
        clipId: `clip:${layerId}`,
        timelineStartMs: originalStartMs,
        timelineDurationMs: leftDurationMs,
      },
      right: {
        layerId: stringValue(rightLayer?.id),
        clipId: `clip:${stringValue(rightLayer?.id)}`,
        timelineStartMs: splitTimeMs,
        timelineDurationMs: rightDurationMs,
      },
    },
  });
}

async function setLayerMask(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const maskType = firstText(
    args.maskType,
    args.type,
    args.shape,
    readMap(args.mask).type,
  ).toLowerCase();
  if (!maskType) {
    return fail('MASK_TYPE_REQUIRED');
  }
  const radius = numberOrNull(firstDefined(args.radius, args.cornerRadius, readMap(args.mask).radius));
  const feather = numberOrNull(firstDefined(args.feather, readMap(args.mask).feather)) ?? 0;
  return await applyLayerStyleMutation(
    context,
    args,
    'refusion.set_layer_mask',
    (payload) => {
      const style = readMap(payload.style);
      const nextMask = {
        ...readMap(payload.mask),
        type: maskType,
        radius,
        feather,
      };
      return {
        ...payload,
        maskType,
        mask: nextMask,
        style: {
          ...style,
          mask: nextMask,
        },
      };
    },
  );
}

async function setBorder(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const width = numberOrNull(firstDefined(args.borderWidth, args.strokeWidth, args.width));
  if (width == null) {
    return fail('BORDER_WIDTH_REQUIRED');
  }
  const color = firstText(args.borderColor, args.strokeColor, args.color, '#FFFFFF');
  return await applyLayerStyleMutation(
    context,
    args,
    'refusion.set_border',
    (payload) => {
      const style = readMap(payload.style);
      return {
        ...payload,
        borderWidth: width,
        borderColor: inferLayerColor({ color }, {}) ?? color,
        style: {
          ...style,
          borderWidth: width,
          borderColor: inferLayerColor({ color }, {}) ?? color,
        },
      };
    },
  );
}

async function setGlow(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const glowColor = firstText(
    args.color,
    args.glowColor,
    readMap(args.glow).color,
    '#FFFFFF',
  );
  const blur = Math.max(0, numberValue(firstDefined(args.blur, readMap(args.glow).blur, 12), 12));
  const opacity = Math.max(
    0,
    Math.min(1, (numberOrNull(firstDefined(args.opacity, readMap(args.glow).opacity)) ?? 0.35)),
  );
  return await applyLayerStyleMutation(
    context,
    args,
    'refusion.set_glow',
    (payload) => {
      const style = readMap(payload.style);
      const glow = {
        color: inferLayerColor({ color: glowColor }, {}) ?? glowColor,
        blur,
        opacity,
      };
      return {
        ...payload,
        glow,
        style: {
          ...style,
          glow,
        },
      };
    },
  );
}

async function setLayerStyle(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const patchStyle = readMap(firstDefined(args.style, args.payload));
  if (Object.keys(patchStyle).length === 0) {
    return fail('STYLE_PAYLOAD_REQUIRED');
  }
  return await applyLayerStyleMutation(
    context,
    args,
    'refusion.set_layer_style',
    (payload) => {
      const style = readMap(payload.style);
      return {
        ...payload,
        style: {
          ...style,
          ...patchStyle,
        },
      };
    },
  );
}

async function applyLayerStyleMutation(
  context: RequestContext,
  args: JsonMap,
  commandType: string,
  mutate: (payload: JsonMap) => JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const rawLayerId = firstText(args.layerId, args.layer_id, args.clipId, args.clip_id);
  const layerId = rawLayerId.startsWith('clip:') ? rawLayerId.slice(5) : rawLayerId;
  if (!layerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const { data: layer, error: layerError } = await admin
    .from('refusion_layers')
    .select('*')
    .eq('owner_id', context.userId)
    .eq('project_id', resolved.projectId)
    .eq('composition_id', resolved.compositionId)
    .eq('id', layerId)
    .maybeSingle();
  if (layerError) throw layerError;
  if (!layer) {
    return fail('LAYER_NOT_FOUND');
  }
  const currentRevision = resolved.revision;
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (expectedRevision != null && expectedRevision !== currentRevision) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
    });
  }
  const currentPayload = readMap(layer.payload);
  const nextPayload = mutate(currentPayload);
  const { error: updateError } = await admin
    .from('refusion_layers')
    .update({
      payload: nextPayload,
      updated_at: new Date().toISOString(),
    })
    .eq('id', layerId);
  if (updateError) throw updateError;
  const revisionAfter = currentRevision + 1;
  await updateRevision(resolved.projectId, revisionAfter);
  const commandRecord = await recordCommand(
    context,
    resolved.projectId,
    resolved.compositionId,
    commandType,
    {
      layerId,
      payload: nextPayload,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Layer style updated.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId,
    commandId: commandRecord.commandId,
    revisionBefore: currentRevision,
    revisionAfter,
  });
}

async function getLayers(context: RequestContext, args: JsonMap): Promise<ToolResult> {
  const boundProjectId = context.agentSession?.project_id ?? '';
  const boundCompositionId = context.agentSession?.composition_id ?? '';
  const active = await getActiveContext(context, {});
  const project = readMap(active.project);
  const composition = readMap(active.composition);
  const projectId = boundProjectId || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = boundCompositionId || stringValue(args.compositionId) ||
    stringValue(composition.id);
  if (!projectId || !compositionId) {
    return fail('PROJECT_NOT_OPEN');
  }
  const revision = await projectRevision(projectId);
  const { data, error } = await admin
    .from('refusion_layers')
    .select(
      'id, layer_kind, name, start_ms, duration_ms, z_index, payload, updated_at',
    )
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('z_index', { ascending: true })
    .order('start_ms', { ascending: true })
    .order('created_at', { ascending: true });
  if (error) throw error;
  return ok('Layers loaded.', {
    projectId,
    compositionId,
    revision,
    layers: data ?? [],
  });
}

async function getProjectSnapshot(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const channels = await loadMotionChannelsForScope(
    context,
    resolved.projectId,
    resolved.compositionId,
  );
  const timelineGraph = buildTimelineGraph(layers, resolved.compositionDurationMs);
  const sceneLayers = buildSceneLayers(layers);
  const mediaAssets = buildMediaAssets(layers);
  const capabilities = defaultCapabilityGraph();
  const playheadMs = numberValue(readMap(resolved.active.timeline).playheadMs, 0);
  const evaluated = evaluateFrameFromState(
    layers,
    channels,
    playheadMs,
    numberValue(args.includeBounds, 1) !== 0,
  );
  return ok('Project snapshot loaded.', {
    schemaVersion: 'refusion.compositionTruthGraph/v1',
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    generatedAt: new Date().toISOString(),
    composition: buildCompositionSpec(resolved.composition, resolved.compositionId),
    playhead: {
      timeMs: playheadMs,
      frame: Math.round(playheadMs / 1000 * resolved.fps),
    },
    selection: {
      selectedLayerIds: readList(args.selectedLayerIds),
      selectedElementIds: readList(args.selectedElementIds),
    },
    assets: mediaAssets,
    timeline: timelineGraph,
    scene: {
      layers: sceneLayers,
    },
    motion: {
      channels,
    },
    effects: {
      catalog: effectCatalog(),
    },
    capabilities,
    evaluatedFrame: evaluated,
    diagnostics: [],
  });
}

async function getCompositionSpec(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  return ok('Composition spec loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    composition: buildCompositionSpec(resolved.composition, resolved.compositionId),
  });
}

async function getTimelineGraph(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  return ok('Timeline graph loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    timeline: buildTimelineGraph(layers, resolved.compositionDurationMs),
  });
}

async function getMediaAssets(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  return ok('Media assets loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    assets: buildMediaAssets(layers),
  });
}

async function getSceneLayers(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  return ok('Scene layers loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    layers: buildSceneLayers(layers),
  });
}

async function getCanvasMetadata(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const width = Math.max(1, numberValue(spec.width, 1080));
  const height = Math.max(1, numberValue(spec.height, 1920));
  const halfW = width / 2;
  const halfH = height / 2;
  const actionMarginX = Math.max(16, Math.round(width * 0.03));
  const actionMarginY = Math.max(24, Math.round(height * 0.05));
  const titleMarginX = Math.max(24, Math.round(width * 0.06));
  const titleMarginY = Math.max(48, Math.round(height * 0.067));
  const thirdsX = Math.round(width / 3);
  const thirdsY = Math.round(height / 3);

  return ok('Canvas metadata loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    width,
    height,
    aspect: aspectString(width, height),
    fps: resolved.fps,
    durationMs: resolved.compositionDurationMs,
    origin: 'center',
    coordinateSystem: {
      canonical: 'centerOrigin',
      unit: 'px',
      xRange: [-halfW, halfW],
      yRange: [-halfH, halfH],
    },
    safeZones: {
      titleSafe: {
        left: titleMarginX,
        top: titleMarginY,
        right: width - titleMarginX,
        bottom: height - titleMarginY,
      },
      actionSafe: {
        left: actionMarginX,
        top: actionMarginY,
        right: width - actionMarginX,
        bottom: height - actionMarginY,
      },
    },
    anchors: {
      topLeft: { x: -halfW, y: -halfH },
      topCenter: { x: 0, y: -halfH },
      topRight: { x: halfW, y: -halfH },
      centerLeft: { x: -halfW, y: 0 },
      center: { x: 0, y: 0 },
      centerRight: { x: halfW, y: 0 },
      bottomLeft: { x: -halfW, y: halfH },
      bottomCenter: { x: 0, y: halfH },
      bottomRight: { x: halfW, y: halfH },
      goldenTop: { x: 0, y: -Math.round(height * 0.191) },
      goldenBottom: { x: 0, y: Math.round(height * 0.191) },
      ruleOfThirdsTopLeft: { x: -halfW + thirdsX / 2, y: -halfH + thirdsY / 2 },
      ruleOfThirdsTopRight: { x: halfW - thirdsX / 2, y: -halfH + thirdsY / 2 },
      ruleOfThirdsBottomLeft: { x: -halfW + thirdsX / 2, y: halfH - thirdsY / 2 },
      ruleOfThirdsBottomRight: { x: halfW - thirdsX / 2, y: halfH - thirdsY / 2 },
    },
    gridLines: {
      vertical: [-Math.round(width / 6), 0, Math.round(width / 6)],
      horizontal: [-Math.round(height / 6), 0, Math.round(height / 6)],
    },
  });
}

async function getElementGeometry(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetLayer = resolveTargetLayer(layers, args);
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND', {
      hint: 'Provide layerId, targetLayerId, or clipId.',
    });
  }

  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const width = Math.max(1, numberValue(spec.width, 1080));
  const height = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(width, height);
  const timeMs = optionalNumber(firstDefined(args.timeMs, args.time)) ??
    numberValue(readMap(resolved.active.timeline).playheadMs, 0);
  const geometry = computeLayerGeometry(targetLayer, width, height, safeZones);
  const startMs = numberValue(targetLayer.start_ms, 0);
  const durationMs = Math.max(1, numberValue(targetLayer.duration_ms, 1));
  const visibleAtTime = timeMs >= startMs && timeMs < (startMs + durationMs);
  const overlaps = computeOverlapsForLayer(targetLayer, layers, width, height, safeZones)
    .map((entry) => ({
      layerId: stringValue(entry.layer.id),
      name: text(entry.layer.name, 'Layer'),
      intersection: entry.intersection,
    }));

  return ok('Element geometry loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    timeMs,
    layerId: stringValue(targetLayer.id),
    kind: text(targetLayer.layer_kind, 'solid'),
    mediaKind: text(readMap(targetLayer.payload).mediaKind, ''),
    intrinsicSize: geometry.intrinsicSize,
    worldBounds: geometry.worldBounds,
    visibleBounds: geometry.visibleBounds,
    timelineRange: {
      startMs,
      durationMs,
    },
    sourceRange: {
      startMs: numberValue(firstDefined(
        readMap(targetLayer.payload).sourceStartMs,
        readMap(targetLayer.payload).source_start_ms,
        0,
      ), 0),
      durationMs: numberValue(firstDefined(
        readMap(targetLayer.payload).sourceDurationMs,
        readMap(targetLayer.payload).source_duration_ms,
        durationMs,
      ), durationMs),
    },
    visibleAtTime,
    safeAreaCompliance: {
      titleSafe: rectContainsRect(safeZones.titleSafe, geometry.visibleBoundsAbsolute),
      actionSafe: rectContainsRect(safeZones.actionSafe, geometry.visibleBoundsAbsolute),
    },
    overlaps,
  });
}

async function getVisualLayoutSummary(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const width = Math.max(1, numberValue(spec.width, 1080));
  const height = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(width, height);
  const playheadMs = optionalNumber(firstDefined(args.timeMs, args.time)) ??
    numberValue(readMap(resolved.active.timeline).playheadMs, 0);
  const visible = layers.filter((layer) => {
    const startMs = numberValue(layer.start_ms, 0);
    const durationMs = Math.max(1, numberValue(layer.duration_ms, 1));
    return playheadMs >= startMs && playheadMs < (startMs + durationMs);
  });

  const issues: JsonMap[] = [];
  for (let i = 0; i < visible.length; i += 1) {
    const base = visible[i];
    const geometry = computeLayerGeometry(base, width, height, safeZones);
    if (!rectContainsRect(safeZones.actionSafe, geometry.visibleBoundsAbsolute)) {
      issues.push({
        code: 'OUTSIDE_ACTION_SAFE',
        severity: 'warning',
        layerId: stringValue(base.id),
      });
    }
    for (let j = i + 1; j < visible.length; j += 1) {
      const candidate = visible[j];
      const candidateGeometry = computeLayerGeometry(candidate, width, height, safeZones);
      const intersection = rectIntersection(
        geometry.visibleBoundsAbsolute,
        candidateGeometry.visibleBoundsAbsolute,
      );
      if (intersection != null && intersection.area > 0) {
        issues.push({
          code: 'LAYER_OVERLAP',
          severity: 'info',
          layerIds: [stringValue(base.id), stringValue(candidate.id)],
          intersection,
        });
      }
    }
  }

  const sortedVisible = [...visible].sort((a, b) =>
    numberValue(a.z_index, 0) - numberValue(b.z_index, 0)
  );
  const primary = pickPrimaryFocusLayer(sortedVisible);
  const summary = composeLayoutSummary({
    width,
    height,
    visibleLayers: sortedVisible,
    primary,
    issueCount: issues.length,
  });

  return ok('Visual layout summary loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    playheadMs,
    summary,
    primaryFocusLayerId: primary ? stringValue(primary.id) : null,
    visibleLayerCount: sortedVisible.length,
    layers: sortedVisible.map((layer) => ({
      layerId: stringValue(layer.id),
      name: text(layer.name, 'Layer'),
      kind: text(layer.layer_kind, 'solid'),
      mediaKind: text(readMap(layer.payload).mediaKind, ''),
      zIndex: numberValue(layer.z_index, 0),
    })),
    issues,
    suggestions: suggestLayoutActions(issues),
  });
}

async function positionAtAnchor(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetLayer = resolveTargetLayer(layers, args);
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND', {
      hint: 'Provide layerId, targetLayerId, or clipId.',
    });
  }

  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const compositionWidth = Math.max(1, numberValue(spec.width, 1080));
  const compositionHeight = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(compositionWidth, compositionHeight);
  const geometry = computeLayerGeometry(targetLayer, compositionWidth, compositionHeight, safeZones);
  const anchor = normalizeAnchorName(firstText(args.anchor, args.targetAnchor, 'center'));
  const safeArea = normalizeSafeArea(firstText(args.safeArea, args.safe_zone, 'actionSafe'));
  const paddingPx = Math.max(0, numberValue(firstDefined(args.paddingPx, args.padding, 0), 0));
  const keepInCanvas = firstDefined(args.keepInCanvas, args.keep_in_canvas, true) !== false;
  const timeMs = numberValue(
    firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs, 0),
    0,
  );

  const targetAbs = anchorTargetCenter({
    anchor,
    safeArea,
    safeZones,
    width: compositionWidth,
    height: compositionHeight,
    elementWidth: geometry.worldBounds.width,
    elementHeight: geometry.worldBounds.height,
    paddingPx,
  });

  const clampedAbs = keepInCanvas
    ? clampCenterIntoCanvas(
      targetAbs,
      compositionWidth,
      compositionHeight,
      geometry.worldBounds.width,
      geometry.worldBounds.height,
    )
    : targetAbs;
  const canonicalX = clampedAbs.x - compositionWidth / 2;
  const canonicalY = clampedAbs.y - compositionHeight / 2;

  const transformResult = await setElementTransform(context, {
    ...args,
    layerId: stringValue(targetLayer.id),
    x: canonicalX,
    y: canonicalY,
    timeMs,
  });
  if (!transformResult.ok) {
    return transformResult;
  }

  return ok('Anchor positioning applied.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId: stringValue(targetLayer.id),
    anchor,
    safeArea,
    paddingPx,
    keepInCanvas,
    timeMs,
    resolvedCenterAbsolute: clampedAbs,
    resolvedCenterCanonical: {
      x: canonicalX,
      y: canonicalY,
    },
    result: transformResult.payload,
  });
}

async function evaluateFrame(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const channels = await loadMotionChannelsForScope(
    context,
    resolved.projectId,
    resolved.compositionId,
  );
  const requestedTimeMs = optionalNumber(firstDefined(args.timeMs, args.time));
  const playheadMs = numberValue(readMap(resolved.active.timeline).playheadMs, 0);
  const timeMs = requestedTimeMs ?? playheadMs;
  return ok('Frame evaluated.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    timeMs,
    frame: Math.round(timeMs / 1000 * resolved.fps),
    ...evaluateFrameFromState(
      layers,
      channels,
      timeMs,
      numberValue(args.includeBounds, 1) !== 0,
    ),
  });
}

async function explainCapabilities(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  return ok('Capability graph loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    revision: resolved.revision,
    capabilities: defaultCapabilityGraph(),
    effectsCatalog: effectCatalog(),
    notes: [
      'Use get_project_snapshot before complex edits.',
      'Use apply_motion_patch/apply_keyframes for animation.',
      'Use set_element_transform for transform keyframes.',
    ],
  });
}

async function getMotionChannels(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const active = await getActiveContext(context, {});
  const project = readMap(active.project);
  const composition = readMap(active.composition);
  const projectId = context.agentSession?.project_id || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = context.agentSession?.composition_id || stringValue(args.compositionId) ||
    stringValue(composition.id);
  if (!projectId || !compositionId) {
    return fail('PROJECT_NOT_OPEN');
  }
  const { data, error } = await admin
    .from('refusion_motion_channels')
    .select('id, layer_id, property_id, keyframes, motion_recipe, updated_at')
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('updated_at', { ascending: true });
  if (error) throw error;
  return ok('Motion channels loaded.', {
    projectId,
    compositionId,
    channels: data ?? [],
  });
}

async function getKeyframes(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const result = await getMotionChannels(context, args);
  if (!result.ok) {
    return result;
  }
  const payload = readMap(result.payload);
  const channels = readList(payload.channels);
  const keyframes: JsonMap[] = [];
  for (const channel of channels) {
    const channelMap = readMap(channel);
    const channelId = stringValue(channelMap.id);
    const layerId = stringValue(channelMap.layer_id);
    const propertyId = stringValue(channelMap.property_id);
    for (const keyframe of parseKeyframes(channelMap.keyframes)) {
      keyframes.push({
        ...keyframe,
        channelId,
        layerId,
        propertyId,
      });
    }
  }
  return ok('Keyframes loaded.', {
    projectId: payload.projectId,
    compositionId: payload.compositionId,
    keyframes,
  });
}

async function resolveProjectScope(
  context: RequestContext,
  args: JsonMap,
): Promise<{
  active: JsonMap;
  composition: JsonMap;
  projectId: string;
  compositionId: string;
  revision: number;
  fps: number;
  compositionDurationMs: number;
} | null> {
  const active = await getActiveContext(context, {});
  const project = readMap(active.project);
  const composition = readMap(active.composition);
  const projectId = context.agentSession?.project_id || stringValue(args.projectId) ||
    stringValue(project.id);
  const compositionId = context.agentSession?.composition_id || stringValue(args.compositionId) ||
    stringValue(composition.id);
  if (!projectId || !compositionId) {
    return null;
  }
  const compositionRow = await selectById('refusion_compositions', compositionId);
  const resolvedComposition = compositionRow ?? composition;
  const fps = numberValue(
    firstDefined(resolvedComposition.fps, composition.fps, 30),
    30,
  );
  const compositionDurationMs = numberValue(
    firstDefined(resolvedComposition.duration_ms, resolvedComposition.durationMs, 8000),
    8000,
  );
  return {
    active,
    composition: resolvedComposition,
    projectId,
    compositionId,
    revision: await projectRevision(projectId),
    fps: Math.max(fps, 1),
    compositionDurationMs: Math.max(compositionDurationMs, 1),
  };
}

async function loadLayersForScope(
  context: RequestContext,
  projectId: string,
  compositionId: string,
): Promise<JsonMap[]> {
  const { data, error } = await admin
    .from('refusion_layers')
    .select(
      'id, layer_kind, name, start_ms, duration_ms, z_index, payload, created_at, updated_at',
    )
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('z_index', { ascending: true })
    .order('start_ms', { ascending: true })
    .order('created_at', { ascending: true });
  if (error) throw error;
  return readList(data).map(readMap);
}

async function loadMotionChannelsForScope(
  context: RequestContext,
  projectId: string,
  compositionId: string,
): Promise<JsonMap[]> {
  const { data, error } = await admin
    .from('refusion_motion_channels')
    .select('id, layer_id, property_id, keyframes, motion_recipe, updated_at')
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('updated_at', { ascending: true });
  if (error) throw error;
  return readList(data).map(readMap);
}

function buildCompositionSpec(composition: JsonMap, fallbackId: string): JsonMap {
  return {
    id: stringValue(composition.id) || fallbackId,
    name: text(composition.name, 'Story'),
    aspect: text(composition.aspect, 'story'),
    width: numberValue(firstDefined(composition.width, 1080), 1080),
    height: numberValue(firstDefined(composition.height, 1920), 1920),
    fps: numberValue(firstDefined(composition.fps, 30), 30),
    durationMs: numberValue(
      firstDefined(composition.duration_ms, composition.durationMs, 8000),
      8000,
    ),
  };
}

function buildTimelineGraph(layers: JsonMap[], compositionDurationMs: number): JsonMap {
  const trackMap = new Map<string, JsonMap>();
  for (const layer of layers) {
    const payload = readMap(layer.payload);
    const layerKind = text(layer.layer_kind, 'solid');
    const mediaKind = text(payload.mediaKind, layerKind === 'media' ? 'video' : layerKind);
    const trackIndex = numberValue(
      firstDefined(payload.trackIndex, payload.track_index, layer.z_index, 0),
      0,
    );
    const trackKind = layerKind === 'media'
      ? (mediaKind === 'audio' ? 'audio' : 'video')
      : layerKind === 'text'
      ? 'text'
      : layerKind === 'shape'
      ? 'shape'
      : 'overlay';
    const trackId = `${trackKind}:${trackIndex}`;
    if (!trackMap.has(trackId)) {
      trackMap.set(trackId, {
        trackId,
        kind: trackKind,
        index: trackIndex,
        locked: false,
        muted: false,
        clips: [] as JsonMap[],
      });
    }
    const clips = readList(readMap(trackMap.get(trackId)).clips) as JsonMap[];
    const startMs = numberValue(layer.start_ms, 0);
    const durationMs = Math.max(1, numberValue(layer.duration_ms, compositionDurationMs));
    clips.push({
      clipId: `clip:${stringValue(layer.id)}`,
      layerId: stringValue(layer.id),
      assetId: firstText(payload.assetId, payload.asset_id, stringValue(layer.id)),
      timelineStartMs: startMs,
      timelineDurationMs: durationMs,
      sourceStartMs: numberValue(firstDefined(payload.sourceStartMs, payload.source_start_ms, 0), 0),
      sourceDurationMs: numberValue(
        firstDefined(payload.sourceDurationMs, payload.source_duration_ms, durationMs),
        durationMs,
      ),
      splitGroupId: firstText(payload.splitGroupId, payload.split_group_id),
      zIndex: numberValue(layer.z_index, 0),
      label: text(layer.name, 'Layer'),
    });
    readMap(trackMap.get(trackId)).clips = clips;
  }
  const tracks = [...trackMap.values()].sort((a, b) =>
    numberValue(readMap(a).index, 0) - numberValue(readMap(b).index, 0)
  );
  return {
    timelineId: 'main',
    durationMs: compositionDurationMs,
    tracks,
  };
}

function buildSceneLayers(layers: JsonMap[]): JsonMap[] {
  const sceneLayers: JsonMap[] = [];
  for (const layer of layers) {
    const payload = readMap(layer.payload);
    const style = readMap(payload.style);
    const layerKind = text(layer.layer_kind, 'solid');
    const mediaKind = text(payload.mediaKind, layerKind === 'media' ? 'video' : '');
    const elementKind = layerKind === 'media'
      ? mediaKind === 'image'
        ? 'image'
        : mediaKind === 'audio'
        ? 'audioClip'
        : 'videoClip'
      : layerKind === 'text'
      ? 'text'
      : layerKind === 'shape'
      ? 'shape'
      : 'shape';
    const elementId = `element:${stringValue(layer.id)}`;
    const startMs = numberValue(layer.start_ms, 0);
    const durationMs = Math.max(1, numberValue(layer.duration_ms, 1));
    sceneLayers.push({
      layerId: stringValue(layer.id),
      kind: layerKind,
      mediaKind: mediaKind || null,
      name: text(layer.name, 'Layer'),
      zIndex: numberValue(layer.z_index, 0),
      visibleRangeMs: {
        start: startMs,
        duration: durationMs,
      },
      elements: [
        {
          elementId,
          kind: elementKind,
          sourceBinding: {
            assetId: firstText(payload.assetId, payload.asset_id),
            sourceUri: firstText(payload.sourceUri, payload.source_uri),
          },
          transform: {
            x: numberOrNull(firstDefined(payload.x, payload.centerX, payload.cx)),
            y: numberOrNull(firstDefined(payload.y, payload.centerY, payload.cy)),
            scaleX: numberOrNull(firstDefined(payload.scaleX, payload.scale, 1)),
            scaleY: numberOrNull(firstDefined(payload.scaleY, payload.scale, 1)),
            rotationDeg: numberOrNull(firstDefined(payload.rotation, payload.rotationDeg, 0)),
            opacity: numberOrNull(firstDefined(payload.opacity, style.opacity, 1)),
          },
          crop: {
            rect: readMap(firstDefined(payload.cropRect, payload.crop, {})),
            fit: firstText(payload.fit, payload.objectFit, 'cover'),
          },
          mask: {
            type: firstText(
              payload.maskType,
              readMap(payload.mask).type,
              payload.shape,
              'none',
            ),
            radius: numberOrNull(
              firstDefined(payload.cornerRadius, readMap(payload.mask).radius),
            ),
            feather: numberOrNull(readMap(payload.mask).feather) ?? 0,
          },
          style: {
            borderWidth: numberOrNull(
              firstDefined(
                payload.borderWidth,
                payload.strokeWidth,
                style.borderWidth,
                style.strokeWidth,
              ),
            ) ?? 0,
            borderColor: firstText(
              payload.borderColor,
              payload.strokeColor,
              style.borderColor,
              style.strokeColor,
              '#FFFFFF',
            ),
            glow: readMap(firstDefined(payload.glow, style.glow)),
            shadow: readMap(firstDefined(payload.shadow, style.shadow)),
            fill: firstText(payload.color, payload.fill, style.fill),
          },
          text: {
            value: firstText(payload.text, payload.content),
            fontSize: numberOrNull(firstDefined(payload.fontSize, style.fontSize)),
            color: firstText(payload.textColor, style.textColor, style.color),
          },
        },
      ],
      updatedAt: stringValue(layer.updated_at),
    });
  }
  return sceneLayers;
}

function buildMediaAssets(layers: JsonMap[]): JsonMap[] {
  const byAssetId = new Map<string, JsonMap>();
  for (const layer of layers) {
    const payload = readMap(layer.payload);
    const layerKind = text(layer.layer_kind, 'solid');
    const mediaKind = text(payload.mediaKind, layerKind === 'media' ? 'video' : '');
    const inferredMedia = mediaKind || (layerKind === 'media' ? 'video' : '');
    if (!inferredMedia) {
      continue;
    }
    const assetId = firstText(payload.assetId, payload.asset_id, `asset:${stringValue(layer.id)}`);
    if (byAssetId.has(assetId)) {
      continue;
    }
    const durationMs = optionalNumber(
      firstDefined(payload.durationMs, payload.duration_ms, layer.duration_ms),
    );
    byAssetId.set(assetId, {
      assetId,
      kind: inferredMedia,
      label: firstText(payload.label, payload.name, layer.name, assetId),
      sourceUri: firstText(payload.sourceUri, payload.source_uri),
      durationMs: durationMs ?? 0,
      width: optionalNumber(firstDefined(payload.width, payload.w)),
      height: optionalNumber(firstDefined(payload.height, payload.h)),
      fps: optionalNumber(firstDefined(payload.fps)),
      hasAudio: inferredMedia === 'video'
        ? firstDefined(payload.hasAudio, true) === true
        : false,
      isUserImported: true,
      canUseInMcp: true,
    });
  }
  return [...byAssetId.values()];
}

function evaluateFrameFromState(
  layers: JsonMap[],
  channels: JsonMap[],
  timeMs: number,
  includeBounds: boolean,
): JsonMap {
  const visibleLayers: JsonMap[] = [];
  for (const layer of layers) {
    const startMs = numberValue(layer.start_ms, 0);
    const durationMs = Math.max(1, numberValue(layer.duration_ms, 1));
    if (timeMs < startMs || timeMs >= startMs + durationMs) {
      continue;
    }
    const payload = readMap(layer.payload);
    const bounds = includeBounds
      ? {
        x: numberOrNull(firstDefined(payload.x, payload.centerX, 0)) ?? 0,
        y: numberOrNull(firstDefined(payload.y, payload.centerY, 0)) ?? 0,
        width: numberOrNull(firstDefined(payload.width, payload.w)),
        height: numberOrNull(firstDefined(payload.height, payload.h)),
      }
      : null;
    visibleLayers.push({
      layerId: stringValue(layer.id),
      kind: text(layer.layer_kind, 'solid'),
      zIndex: numberValue(layer.z_index, 0),
      bounds,
    });
  }
  visibleLayers.sort((a, b) =>
    numberValue(readMap(a).zIndex, 0) - numberValue(readMap(b).zIndex, 0)
  );
  const keyedChannels = channels.map((channel) => ({
    channelId: stringValue(channel.id),
    layerId: stringValue(channel.layer_id),
    propertyId: stringValue(channel.property_id),
    keyframeCount: parseKeyframes(channel.keyframes).length,
  }));
  return {
    visibleLayers,
    channelSummary: keyedChannels,
    diagnostics: [],
  };
}

function defaultCapabilityGraph(): JsonMap {
  return {
    'media.video.trim': 'supported',
    'media.video.split': 'planned',
    'media.video.mask.circle': 'supported',
    'media.video.mask.roundedRect': 'supported',
    'media.video.border': 'supported',
    'media.video.glow': 'supported',
    'media.video.motion.transform': 'supported',
    'media.video.exportParity': 'previewOnly',
    'text.insert': 'supported',
    'shape.insert': 'supported',
    'background.set_solid': 'supported',
    'animation.apply_keyframes': 'supported',
  };
}

function effectCatalog(): JsonMap[] {
  return [
    { id: 'mask.circle', category: 'mask', status: 'supported' },
    { id: 'mask.roundedRect', category: 'mask', status: 'supported' },
    { id: 'style.border', category: 'style', status: 'supported' },
    { id: 'effect.glow', category: 'effect', status: 'supported' },
    { id: 'effect.shadow', category: 'effect', status: 'supported' },
    { id: 'transform.position', category: 'motion', status: 'supported' },
    { id: 'transform.scale', category: 'motion', status: 'supported' },
    { id: 'transform.rotation', category: 'motion', status: 'supported' },
    { id: 'visual.opacity', category: 'motion', status: 'supported' },
  ];
}

function aspectString(width: number, height: number): string {
  const divisor = gcd(width, height);
  return `${Math.round(width / divisor)}:${Math.round(height / divisor)}`;
}

function gcd(a: number, b: number): number {
  let x = Math.abs(Math.round(a));
  let y = Math.abs(Math.round(b));
  while (y !== 0) {
    const t = y;
    y = x % y;
    x = t;
  }
  return x <= 0 ? 1 : x;
}

function buildSafeZones(width: number, height: number): {
  titleSafe: Rect;
  actionSafe: Rect;
} {
  const actionMarginX = Math.max(16, Math.round(width * 0.03));
  const actionMarginY = Math.max(24, Math.round(height * 0.05));
  const titleMarginX = Math.max(24, Math.round(width * 0.06));
  const titleMarginY = Math.max(48, Math.round(height * 0.067));
  return {
    titleSafe: {
      left: titleMarginX,
      top: titleMarginY,
      right: width - titleMarginX,
      bottom: height - titleMarginY,
    },
    actionSafe: {
      left: actionMarginX,
      top: actionMarginY,
      right: width - actionMarginX,
      bottom: height - actionMarginY,
    },
  };
}

type Rect = {
  left: number;
  top: number;
  right: number;
  bottom: number;
};

type LayerGeometry = {
  intrinsicSize: {
    width: number;
    height: number;
  };
  worldBounds: {
    centerX: number;
    centerY: number;
    width: number;
    height: number;
    rotationDeg: number;
    scaleX: number;
    scaleY: number;
  };
  visibleBounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  visibleBoundsAbsolute: Rect;
};

function resolveTargetLayer(layers: JsonMap[], args: JsonMap): JsonMap | null {
  const rawLayerId = firstText(args.layerId, args.layer_id, args.targetLayerId, args.surfaceId);
  const clipId = firstText(args.clipId, args.clip_id);
  const layerId = rawLayerId
    ? rawLayerId.startsWith('clip:')
      ? rawLayerId.slice(5)
      : rawLayerId
    : clipId.startsWith('clip:')
    ? clipId.slice(5)
    : clipId;
  if (layerId) {
    for (const layer of layers) {
      if (stringValue(layer.id) === layerId) {
        return layer;
      }
    }
    return null;
  }
  if (layers.length == 0) {
    return null;
  }
  const sorted = [...layers].sort((a, b) =>
    numberValue(a.z_index, 0) - numberValue(b.z_index, 0)
  );
  return sorted[sorted.length - 1] ?? null;
}

function computeLayerGeometry(
  layer: JsonMap,
  compositionWidth: number,
  compositionHeight: number,
  safeZones: { titleSafe: Rect; actionSafe: Rect },
): LayerGeometry {
  const payload = readMap(layer.payload);
  const baseWidth = Math.max(1, numberValue(
    firstDefined(
      payload.width,
      payload.w,
      payload.intrinsicWidth,
      payload.sourceWidth,
      compositionWidth,
    ),
    compositionWidth,
  ));
  const baseHeight = Math.max(1, numberValue(
    firstDefined(
      payload.height,
      payload.h,
      payload.intrinsicHeight,
      payload.sourceHeight,
      compositionHeight,
    ),
    compositionHeight,
  ));
  const scaleX = numberOrNull(firstDefined(payload.scaleX, payload.scale, 1)) ?? 1;
  const scaleY = numberOrNull(firstDefined(payload.scaleY, payload.scale, 1)) ?? 1;
  const worldWidth = Math.max(1, baseWidth * Math.abs(scaleX));
  const worldHeight = Math.max(1, baseHeight * Math.abs(scaleY));
  const centerX = numberOrNull(firstDefined(payload.x, payload.centerX, payload.cx)) ?? 0;
  const centerY = numberOrNull(firstDefined(payload.y, payload.centerY, payload.cy)) ?? 0;
  const halfW = compositionWidth / 2;
  const halfH = compositionHeight / 2;
  const absCenterX = centerX + halfW;
  const absCenterY = centerY + halfH;
  const rect: Rect = {
    left: absCenterX - worldWidth / 2,
    top: absCenterY - worldHeight / 2,
    right: absCenterX + worldWidth / 2,
    bottom: absCenterY + worldHeight / 2,
  };
  const clamped: Rect = {
    left: Math.max(0, rect.left),
    top: Math.max(0, rect.top),
    right: Math.min(compositionWidth, rect.right),
    bottom: Math.min(compositionHeight, rect.bottom),
  };
  const clampedWidth = Math.max(0, clamped.right - clamped.left);
  const clampedHeight = Math.max(0, clamped.bottom - clamped.top);
  const visibleBounds = {
    x: clamped.left - halfW + clampedWidth / 2,
    y: clamped.top - halfH + clampedHeight / 2,
    width: clampedWidth,
    height: clampedHeight,
  };
  const _ignored = safeZones;
  return {
    intrinsicSize: {
      width: baseWidth,
      height: baseHeight,
    },
    worldBounds: {
      centerX,
      centerY,
      width: worldWidth,
      height: worldHeight,
      rotationDeg: numberOrNull(firstDefined(payload.rotation, payload.rotationDeg, 0)) ?? 0,
      scaleX,
      scaleY,
    },
    visibleBounds,
    visibleBoundsAbsolute: clamped,
  };
}

function rectContainsRect(container: Rect, inner: Rect): boolean {
  return (
    inner.left >= container.left &&
    inner.top >= container.top &&
    inner.right <= container.right &&
    inner.bottom <= container.bottom
  );
}

function rectIntersection(a: Rect, b: Rect): (Rect & { area: number }) | null {
  const left = Math.max(a.left, b.left);
  const top = Math.max(a.top, b.top);
  const right = Math.min(a.right, b.right);
  const bottom = Math.min(a.bottom, b.bottom);
  if (right <= left || bottom <= top) {
    return null;
  }
  const area = (right - left) * (bottom - top);
  return { left, top, right, bottom, area };
}

function computeOverlapsForLayer(
  target: JsonMap,
  layers: JsonMap[],
  compositionWidth: number,
  compositionHeight: number,
  safeZones: { titleSafe: Rect; actionSafe: Rect },
): Array<{ layer: JsonMap; intersection: Rect & { area: number } }> {
  const targetGeometry = computeLayerGeometry(
    target,
    compositionWidth,
    compositionHeight,
    safeZones,
  );
  const result: Array<{ layer: JsonMap; intersection: Rect & { area: number } }> = [];
  for (const layer of layers) {
    if (stringValue(layer.id) == stringValue(target.id)) {
      continue;
    }
    const geometry = computeLayerGeometry(layer, compositionWidth, compositionHeight, safeZones);
    const intersection = rectIntersection(
      targetGeometry.visibleBoundsAbsolute,
      geometry.visibleBoundsAbsolute,
    );
    if (intersection != null && intersection.area > 0) {
      result.push({ layer, intersection });
    }
  }
  return result;
}

function pickPrimaryFocusLayer(layers: JsonMap[]): JsonMap | null {
  for (let i = layers.length - 1; i >= 0; i -= 1) {
    const layer = layers[i];
    const kind = text(layer.layer_kind, 'solid');
    if (kind !== 'solid' || text(readMap(layer.payload).mediaKind, '') !== '') {
      return layer;
    }
  }
  return layers[layers.length - 1] ?? null;
}

function composeLayoutSummary(input: {
  width: number;
  height: number;
  visibleLayers: JsonMap[];
  primary: JsonMap | null;
  issueCount: number;
}): string {
  const { width, height, visibleLayers, primary, issueCount } = input;
  const primaryName = primary ? text(primary.name, 'Layer') : 'none';
  return `Canvas ${width}x${height} with ${visibleLayers.length} visible layers. Primary focus: ${primaryName}. Diagnostics: ${issueCount}.`;
}

function suggestLayoutActions(issues: JsonMap[]): JsonMap[] {
  if (issues.length === 0) {
    return [];
  }
  return [
    {
      operation: 'surface.fit_in_zone',
      zone: 'actionSafe',
      reason: 'keep elements inside action-safe area',
    },
    {
      operation: 'surface.position.at_anchor',
      anchor: 'goldenTop',
      reason: 'reduce overlap and improve hierarchy',
    },
  ];
}

function normalizeAnchorName(value: string): string {
  const normalized = value.trim().toLowerCase();
  const map: Record<string, string> = {
    topleft: 'topLeft',
    topcenter: 'topCenter',
    topright: 'topRight',
    centerleft: 'centerLeft',
    center: 'center',
    centerright: 'centerRight',
    bottomleft: 'bottomLeft',
    bottomcenter: 'bottomCenter',
    bottomright: 'bottomRight',
    goldentop: 'goldenTop',
    goldenbottom: 'goldenBottom',
    ruleofthirdstopleft: 'ruleOfThirdsTopLeft',
    ruleofthirdstopright: 'ruleOfThirdsTopRight',
    ruleofthirdsbottomleft: 'ruleOfThirdsBottomLeft',
    ruleofthirdsbottomright: 'ruleOfThirdsBottomRight',
  };
  return map[normalized] ?? 'center';
}

function normalizeSafeArea(value: string): 'none' | 'titleSafe' | 'actionSafe' {
  const normalized = value.trim().toLowerCase();
  if (normalized === 'none' || normalized === 'off') {
    return 'none';
  }
  if (normalized === 'title' || normalized === 'titlesafe') {
    return 'titleSafe';
  }
  return 'actionSafe';
}

function anchorTargetCenter(input: {
  anchor: string;
  safeArea: 'none' | 'titleSafe' | 'actionSafe';
  safeZones: { titleSafe: Rect; actionSafe: Rect };
  width: number;
  height: number;
  elementWidth: number;
  elementHeight: number;
  paddingPx: number;
}): { x: number; y: number } {
  const zone = input.safeArea === 'none'
    ? { left: 0, top: 0, right: input.width, bottom: input.height }
    : input.safeArea === 'titleSafe'
    ? input.safeZones.titleSafe
    : input.safeZones.actionSafe;
  const zoneCenterX = (zone.left + zone.right) / 2;
  const zoneCenterY = (zone.top + zone.bottom) / 2;
  const zoneWidth = zone.right - zone.left;
  const zoneHeight = zone.bottom - zone.top;
  const halfW = input.elementWidth / 2;
  const halfH = input.elementHeight / 2;
  const padding = input.paddingPx;
  const map: Record<string, { x: number; y: number }> = {
    topLeft: { x: zone.left + padding + halfW, y: zone.top + padding + halfH },
    topCenter: { x: zoneCenterX, y: zone.top + padding + halfH },
    topRight: { x: zone.right - padding - halfW, y: zone.top + padding + halfH },
    centerLeft: { x: zone.left + padding + halfW, y: zoneCenterY },
    center: { x: zoneCenterX, y: zoneCenterY },
    centerRight: { x: zone.right - padding - halfW, y: zoneCenterY },
    bottomLeft: { x: zone.left + padding + halfW, y: zone.bottom - padding - halfH },
    bottomCenter: { x: zoneCenterX, y: zone.bottom - padding - halfH },
    bottomRight: { x: zone.right - padding - halfW, y: zone.bottom - padding - halfH },
    goldenTop: { x: zoneCenterX, y: zone.top + zoneHeight * 0.309 },
    goldenBottom: { x: zoneCenterX, y: zone.bottom - zoneHeight * 0.309 },
    ruleOfThirdsTopLeft: {
      x: zone.left + zoneWidth / 3,
      y: zone.top + zoneHeight / 3,
    },
    ruleOfThirdsTopRight: {
      x: zone.right - zoneWidth / 3,
      y: zone.top + zoneHeight / 3,
    },
    ruleOfThirdsBottomLeft: {
      x: zone.left + zoneWidth / 3,
      y: zone.bottom - zoneHeight / 3,
    },
    ruleOfThirdsBottomRight: {
      x: zone.right - zoneWidth / 3,
      y: zone.bottom - zoneHeight / 3,
    },
  };
  return map[input.anchor] ?? map.center;
}

function clampCenterIntoCanvas(
  centerAbs: { x: number; y: number },
  compositionWidth: number,
  compositionHeight: number,
  elementWidth: number,
  elementHeight: number,
): { x: number; y: number } {
  const halfW = elementWidth / 2;
  const halfH = elementHeight / 2;
  return {
    x: Math.min(
      compositionWidth - halfW,
      Math.max(halfW, centerAbs.x),
    ),
    y: Math.min(
      compositionHeight - halfH,
      Math.max(halfH, centerAbs.y),
    ),
  };
}

async function getCommandStatus(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const commandId = stringValue(args.commandId);
  if (!commandId) return fail('COMMAND_ID_REQUIRED');
  const { data, error } = await admin
    .from('refusion_agent_commands')
    .select('*')
    .eq('owner_id', context.userId)
    .eq('id', commandId)
    .single();
  if (error) throw error;
  const normalized = await normalizeCommandApplyState(context, readMap(data));
  return ok('Command status loaded.', normalized);
}

async function waitForApply(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const commandId = stringValue(args.commandId);
  if (!commandId) return fail('COMMAND_ID_REQUIRED');
  const timeoutMs = numberValue(args.timeoutMs, 5000);
  const deadline = Date.now() + Math.max(250, Math.min(timeoutMs, 120000));
  while (Date.now() < deadline) {
    const status = await getCommandStatus(context, { commandId });
    if (!status.ok) {
      return status;
    }
    const payload = readMap(status.payload);
    const state = text(payload.status, 'pending');
    const result = readMap(payload.result);
    const appApplied = result.appApplied === true;
    if (
      state === 'succeeded' ||
      state === 'failed' ||
      state === 'cancelled'
    ) {
      return ok('Apply status resolved.', {
        commandId,
        status: state,
        appApplied: state === 'succeeded' ? appApplied : false,
        payload,
      });
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  return ok('Apply status timeout.', {
    commandId,
    status: 'pending',
    appApplied: false,
  });
}

async function normalizeCommandApplyState(
  context: RequestContext,
  commandRow: JsonMap,
): Promise<JsonMap> {
  const state = text(commandRow.status, 'pending');
  if (state === 'failed' || state === 'cancelled' || state === 'succeeded') {
    return commandRow;
  }
  const revisionAfter = optionalNumber(commandRow.revision_after);
  if (revisionAfter == null) {
    return commandRow;
  }
  const appliedRevision = await readAppliedTimelineRevisionForCommand(
    context.userId,
    commandRow,
  );
  if (appliedRevision == null || appliedRevision < revisionAfter) {
    return commandRow;
  }
  const existingResult = readMap(commandRow.result);
  const nextResult: JsonMap = {
    ...existingResult,
    appApplied: true,
    appliedTimelineRevision: appliedRevision,
    appliedAt: new Date().toISOString(),
  };
  const { data: updated, error } = await admin
    .from('refusion_agent_commands')
    .update({
      status: 'succeeded',
      result: nextResult,
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('owner_id', context.userId)
    .eq('id', stringValue(commandRow.id))
    .select('*')
    .single();
  if (error) {
    throw error;
  }
  return readMap(updated);
}

async function readAppliedTimelineRevisionForCommand(
  ownerId: string,
  commandRow: JsonMap,
): Promise<number | null> {
  const editorSessionId = stringValue(commandRow.editor_session_id);
  if (editorSessionId) {
    const { data, error } = await admin
      .from('refusion_editor_sessions')
      .select('timeline_revision')
      .eq('owner_id', ownerId)
      .eq('id', editorSessionId)
      .maybeSingle();
    if (error) throw error;
    const revision = optionalNumber(data?.timeline_revision);
    if (revision != null) {
      return revision;
    }
  }

  const agentSessionId = stringValue(commandRow.agent_session_id);
  if (agentSessionId) {
    const { data: agentSession, error: agentError } = await admin
      .from('refusion_agent_sessions')
      .select('active_context_id')
      .eq('owner_id', ownerId)
      .eq('id', agentSessionId)
      .maybeSingle();
    if (agentError) throw agentError;
    const activeContextId = stringValue(agentSession?.active_context_id);
    if (activeContextId) {
      const { data: activeContext, error: activeContextError } = await admin
        .from('refusion_active_contexts')
        .select('timeline_revision')
        .eq('owner_id', ownerId)
        .eq('id', activeContextId)
        .maybeSingle();
      if (activeContextError) throw activeContextError;
      const revision = optionalNumber(activeContext?.timeline_revision);
      if (revision != null) {
        return revision;
      }
    }
  }

  const projectId = stringValue(commandRow.project_id);
  const compositionId = stringValue(commandRow.composition_id);
  if (!projectId || !compositionId) {
    return null;
  }
  const { data: fallbackContext, error: fallbackError } = await admin
    .from('refusion_active_contexts')
    .select('timeline_revision')
    .eq('owner_id', ownerId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .eq('status', 'active')
    .order('updated_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (fallbackError) throw fallbackError;
  return optionalNumber(fallbackContext?.timeline_revision);
}

async function ensurePairingContext(
  userId: string,
  input: {
    deviceId: string;
    projectId: string;
    compositionId: string;
    timelineId: string;
    playheadMs: number;
    timelineRevision: number;
    platform?: string;
    appVersion?: string;
    status?: string;
  },
): Promise<PairingContext> {
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const activeProjectId = stringValue(readMap(active.project).id);
  const activeCompositionId = stringValue(readMap(active.composition).id);
  const activeTimeline = readMap(active.timeline);
  const liveEditor = readMap(active.liveEditor);

  const deviceId = input.deviceId.trim().length > 0
    ? input.deviceId.trim()
    : text(liveEditor.deviceId, 'flutter-device');
  const projectId = input.projectId || activeProjectId;
  const compositionId = input.compositionId || activeCompositionId;
  const timelineId = input.timelineId || text(activeTimeline.id, 'main');
  const playheadMs = input.playheadMs;
  const timelineRevision = input.timelineRevision > 0
    ? input.timelineRevision
    : await projectRevision(projectId);

  const { data: deviceRow, error: deviceError } = await admin
    .from('refusion_devices')
    .upsert({
      owner_id: userId,
      device_id: deviceId,
      device_name: deviceId,
      platform: text(input.platform, 'flutter'),
      app_version: text(input.appVersion, 'refusion-app'),
      status: 'active',
      last_seen_at: new Date().toISOString(),
    }, { onConflict: 'owner_id,device_id' })
    .select()
    .single();
  if (deviceError) throw deviceError;

  const { data: appSessionRow, error: appSessionError } = await admin
    .from('refusion_app_sessions')
    .upsert({
      owner_id: userId,
      device_ref: deviceRow.id,
      status: mapEditorStatus(text(input.status, 'online')),
      last_heartbeat_at: new Date().toISOString(),
      started_at: new Date().toISOString(),
    }, { onConflict: 'owner_id,device_ref' })
    .select()
    .single();
  if (appSessionError) throw appSessionError;

  const { data: activeContextRow, error: activeContextError } = await admin
    .from('refusion_active_contexts')
    .upsert({
      owner_id: userId,
      device_ref: deviceRow.id,
      app_session_id: appSessionRow.id,
      project_id: projectId,
      composition_id: compositionId,
      timeline_id: timelineId,
      playhead_ms: playheadMs,
      timeline_revision: timelineRevision,
      status: 'active',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'owner_id,device_ref' })
    .select()
    .single();
  if (activeContextError) throw activeContextError;

  return {
    userId,
    deviceId,
    deviceRefId: deviceRow.id as string,
    appSessionId: appSessionRow.id as string,
    activeContextId: activeContextRow.id as string,
    projectId,
    compositionId,
    timelineRevision,
    timelineId,
    playheadMs,
  };
}

async function recordCommand(
  context: RequestContext,
  projectId: string,
  compositionId: string,
  commandType: string,
  payload: JsonMap,
  revisionBefore: number,
  revisionAfter: number,
  idempotencyKey: string,
) {
  const nowIso = new Date().toISOString();
  const insertPayload: JsonMap = {
    owner_id: context.userId,
    project_id: projectId,
    composition_id: compositionId,
    command_type: commandType,
    payload,
    revision_before: revisionBefore,
    revision_after: revisionAfter,
    status: 'running',
    claimed_at: nowIso,
    result: {
      ...payload,
      appApplied: false,
      revisionAfter,
      acceptedAt: nowIso,
    },
  };
  if (idempotencyKey) {
    insertPayload.idempotency_key = idempotencyKey;
  }
  if (context.agentSession) {
    insertPayload.agent_session_id = context.agentSession.id;
  }

  const { data, error } = await admin
    .from('refusion_agent_commands')
    .insert(insertPayload)
    .select('id')
    .single();
  if (error) throw error;
  return {
    commandId: stringValue(data?.id),
  };
}

async function recordAuditEvent(
  ownerId: string,
  projectId: string,
  compositionId: string,
  data: { actor: string; eventType: string; payload: JsonMap },
) {
  await admin.from('refusion_audit_events').insert({
    owner_id: ownerId,
    project_id: projectId || null,
    composition_id: compositionId || null,
    actor: data.actor,
    event_type: data.eventType,
    payload: data.payload,
  });
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

async function validateAgentSessionToken(
  token: string,
): Promise<AgentSessionRow | null> {
  const tokenHash = await digestToken(token);
  const { data, error } = await admin
    .from('refusion_agent_sessions')
    .select('*')
    .eq('token_hash', tokenHash)
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    return null;
  }
  if (text(data.status, 'active') !== 'active') {
    return null;
  }
  const expiresAt = Date.parse(String(data.expires_at ?? ''));
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    await admin.from('refusion_agent_sessions').update({
      status: 'expired',
    }).eq('id', data.id);
    return null;
  }
  await admin.from('refusion_agent_sessions').update({
    last_used_at: new Date().toISOString(),
  }).eq('id', data.id);
  return data as AgentSessionRow;
}

async function digestToken(token: string): Promise<string> {
  const source = `${token}:${agentSessionSalt}`;
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(source),
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

function readAgentSessionToken(request: Request, args: JsonMap): string | null {
  const fromArgs = stringValue(args.agentSessionToken);
  if (fromArgs) {
    return fromArgs;
  }
  const fromHeader = request.headers.get('x-refusion-agent-session') ?? '';
  if (fromHeader.trim()) {
    return fromHeader.trim();
  }
  return null;
}

async function generateUniquePairingCode(): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const code = `REF-${randomDigits(6)}`;
    const { data } = await admin.from('refusion_pairing_codes').select('id').eq(
      'code',
      code,
    ).maybeSingle();
    if (!data) {
      return code;
    }
  }
  return `REF-${randomDigits(6)}`;
}

function normalizePairingCode(value: string): string {
  const normalized = value.trim().toUpperCase();
  if (!/^REF-[0-9A-HJKMNP-TV-Z]{4,6}$/.test(normalized)) {
    return '';
  }
  return normalized;
}

function isSafePairingCode(value: string): boolean {
  return /^REF-[0-9]{6}$/.test(value.trim().toUpperCase());
}

function randomBase32(length: number): string {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let output = '';
  for (let index = 0; index < bytes.length; index += 1) {
    output += alphabet[bytes[index] % alphabet.length];
  }
  return output;
}

function randomDigits(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let output = '';
  for (let index = 0; index < bytes.length; index += 1) {
    output += String(bytes[index] % 10);
  }
  return output;
}

function randomAlphaNumeric(length: number): string {
  const alphabet =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let output = '';
  for (let index = 0; index < bytes.length; index += 1) {
    output += alphabet[bytes[index] % alphabet.length];
  }
  return output;
}

function safeTtlMinutes(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return 60;
  }
  return Math.min(Math.max(Math.floor(value), 10), 240);
}

function safeTtlHours(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    return 4;
  }
  return Math.min(Math.max(Math.floor(value), 1), 24);
}

function mapEditorStatus(status: string): string {
  if (status === 'background' || status === 'backgrounded') {
    return 'backgrounded';
  }
  if (status === 'offline' || status === 'closed') {
    return 'closed';
  }
  return 'active';
}

function tools() {
  return [
    tool(
      'refusion.get_active_context',
      'Get Active Context',
      'Return active project, composition, playhead, revision, and live editor status.',
    ),
    tool(
      'refusion.get_project_state',
      'Get Project State',
      'Alias for active context.',
    ),
    tool(
      'refusion.create_project',
      'Create Project',
      'Create a project and default composition.',
      true,
    ),
    tool(
      'refusion.set_active_context',
      'Set Active Context',
      'Set active project/composition and bind editor session.',
      true,
    ),
    tool(
      'refusion.touch_editor_session',
      'Touch Editor Session',
      'Refresh active editor session heartbeat.',
      true,
    ),
    tool(
      'refusion.sync_editor_layers',
      'Sync Editor Layers',
      'Publish the open app timeline media layers so MCP agents can inspect locally inserted video, image, and audio clips.',
      true,
    ),
    tool(
      'refusion.generate_pairing_code',
      'Generate Pairing Code',
      'Generate one-time pairing code for current active context.',
      true,
    ),
    tool(
      'refusion.get_pairing_code_status',
      'Get Pairing Code Status',
      'Fetch pairing-code lifecycle state. If status is pending, the app is already waiting for the agent; immediately call refusion.attach_pairing_code with that code. Do not wait for status claimed.',
    ),
    tool(
      'refusion.attach_pairing_code',
      'Attach Pairing Code',
      'Claim a pending ReFusion pairing code and issue an agent session token. Call this when the code status is pending; this tool changes it to claimed. No extra app approval is required.',
      true,
    ),
    tool(
      'refusion.claim_pairing_code',
      'Claim Pairing Code',
      'Alias of attach_pairing_code with clearer intent: claim the pending app code now and return an agent session token.',
      true,
    ),
    tool(
      'refusion.insert_layer',
      'Insert Layer',
      'Insert a layer into the active composition.',
      true,
    ),
    tool(
      'refusion.insert_text',
      'Insert Text',
      'Insert a text layer into the active composition.',
      true,
    ),
    tool(
      'refusion.set_background',
      'Set Background',
      'Set or insert a solid background layer for the active composition.',
      true,
    ),
    tool(
      'refusion.apply_scene_program',
      'Apply Scene Program',
      'Apply a minimal SceneProgram as a layer mutation.',
      true,
    ),
    tool(
      'refusion.apply_motion_patch',
      'Apply Motion Patch',
      'Apply or upsert motion channels (keyframes/recipes) on an existing layer.',
      true,
    ),
    tool(
      'refusion.apply_animation_recipe',
      'Apply Animation Recipe',
      'Alias of apply_motion_patch for recipe-based animations.',
      true,
    ),
    tool(
      'refusion.apply_keyframes',
      'Apply Keyframes',
      'Upsert explicit keyframes on one or more motion properties.',
      true,
    ),
    tool(
      'refusion.keyframe_edit',
      'Keyframe Edit',
      'Edit existing motion channel keyframes (add/set/delete).',
      true,
    ),
    tool(
      'refusion.set_element_transform',
      'Set Element Transform',
      'Set element transform values at a timeline time as keyframed motion channels.',
      true,
    ),
    tool(
      'refusion.trim_clip',
      'Trim Clip',
      'Trim clip timeline/source ranges for a target layer.',
      true,
    ),
    tool(
      'refusion.split_clip',
      'Split Clip',
      'Split a clip into two layers at a timeline time.',
      true,
    ),
    tool(
      'refusion.set_layer_mask',
      'Set Layer Mask',
      'Apply circle/rounded/rect mask metadata on a target layer.',
      true,
    ),
    tool(
      'refusion.set_border',
      'Set Border',
      'Apply border style metadata on a target layer.',
      true,
    ),
    tool(
      'refusion.set_glow',
      'Set Glow',
      'Apply glow style metadata on a target layer.',
      true,
    ),
    tool(
      'refusion.set_layer_style',
      'Set Layer Style',
      'Apply style patch metadata on a target layer.',
      true,
    ),
    tool(
      'refusion.position_at_anchor',
      'Position At Anchor',
      'Place target layer at semantic anchors (topLeft/topRight/goldenTop/thirds) with optional safe-area and padding.',
      true,
    ),
    tool(
      'refusion.get_layers',
      'Get Layers',
      'Return composition layers ordered by z-index and start.',
    ),
    tool(
      'refusion.get_project_snapshot',
      'Get Project Snapshot',
      'Return a composition truth graph snapshot for the active project.',
    ),
    tool(
      'refusion.get_composition_spec',
      'Get Composition Spec',
      'Return composition dimensions, fps, duration, and metadata.',
    ),
    tool(
      'refusion.get_timeline_graph',
      'Get Timeline Graph',
      'Return timeline tracks, clips, ranges, and ordering for active composition.',
    ),
    tool(
      'refusion.get_media_assets',
      'Get Media Assets',
      'Return media asset inventory detected for active composition.',
    ),
    tool(
      'refusion.get_scene_layers',
      'Get Scene Layers',
      'Return scene layer graph with element, transform, mask, and style metadata.',
    ),
    tool(
      'refusion.get_canvas_metadata',
      'Get Canvas Metadata',
      'Return canvas dimensions, origin, coordinate ranges, safe zones, and anchors.',
    ),
    tool(
      'refusion.get_element_geometry',
      'Get Element Geometry',
      'Return evaluated bounds, world geometry, and safe-area compliance for a target layer.',
    ),
    tool(
      'refusion.get_visual_layout_summary',
      'Get Visual Layout Summary',
      'Return layout summary with overlap diagnostics and smart suggestions.',
    ),
    tool(
      'refusion.evaluate_frame',
      'Evaluate Frame',
      'Return visible layer/layout summary for a timeline time.',
    ),
    tool(
      'refusion.explain_capabilities',
      'Explain Capabilities',
      'Return supported/blocked capabilities for timeline, media, style, and motion operations.',
    ),
    tool(
      'refusion.get_motion_channels',
      'Get Motion Channels',
      'Return motion channels for the active composition.',
    ),
    tool(
      'refusion.get_keyframes',
      'Get Keyframes',
      'Return flattened keyframes for motion channels in the active composition.',
    ),
    tool(
      'refusion.get_command_status',
      'Get Command Status',
      'Return a command status by id.',
    ),
    tool(
      'refusion.wait_for_apply',
      'Wait For Apply',
      'Poll command status until it reaches a terminal state or timeout.',
    ),
    tool(
      'refusion.disconnect_agent',
      'Disconnect Agent',
      'Revoke current or target agent session.',
      true,
    ),
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
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

function readList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
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

function firstDefined(...values: unknown[]): unknown {
  for (const value of values) {
    if (value !== undefined && value !== null) {
      return value;
    }
  }
  return undefined;
}

function firstText(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function canonicalLayerPayload(args: JsonMap): JsonMap {
  const payload = sanitizeLayerPayload(readMap(args.payload));
  const layer = sanitizeLayerPayload(firstDefined(args.layer, payload.layer));
  const updates = sanitizeLayerPayload(firstDefined(args.updates, payload.updates));
  const style = sanitizeLayerPayload(firstDefined(args.style, payload.style, layer.style));
  const out: JsonMap = {
    ...payload,
    ...layer,
  };
  if (Object.keys(style).length > 0) {
    out.style = style;
  }
  if (Object.keys(updates).length > 0) {
    out.updates = updates;
  }

  const textValue = firstText(
    args.text,
    args.content,
    args.title,
    out.text,
    out.content,
    out.value,
  );
  if (textValue) {
    out.text = textValue;
    if (!out.content) out.content = textValue;
  }
  const assetId = firstText(
    args.assetId,
    args.asset_id,
    out.assetId,
    out.asset_id,
  );
  if (assetId) {
    out.assetId = assetId;
  }
  const sourceUri = firstText(
    args.sourceUri,
    args.source_uri,
    out.sourceUri,
    out.source_uri,
  );
  if (sourceUri) {
    out.sourceUri = sourceUri;
  }
  const mediaKind = firstText(
    args.mediaKind,
    args.media_kind,
    args.kind,
    args.type,
    out.mediaKind,
    out.media_kind,
  ).toLowerCase();
  if (mediaKind === 'video' || mediaKind === 'image' || mediaKind === 'audio') {
    out.mediaKind = mediaKind;
  }

  const fontSize = firstDefined(args.fontSize, args.font_size, out.fontSize, out.font_size);
  if (fontSize !== undefined) out.fontSize = fontSize;
  const x = firstDefined(args.x, args.centerX, out.x, out.centerX);
  const y = firstDefined(args.y, args.centerY, out.y, out.centerY);
  if (x !== undefined) out.x = x;
  if (y !== undefined) out.y = y;

  const color = inferLayerColor(args, out);
  if (color) {
    out.color = color;
  }
  return out;
}

function inferLayerKind(args: JsonMap, payload: JsonMap): string {
  const style = readMap(payload.style);
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  const operation = firstText(
    args.operation,
    args.command,
    args.action,
    payload.operation,
    updates.operation,
    updatePayload.operation,
  ).toLowerCase();
  if (
    operation.includes('animate') ||
    operation.includes('keyframe') ||
    operation.includes('transform')
  ) {
    return 'text';
  }
  const rawKind = firstText(
    args.layerKind,
    args.layer_kind,
    args.layerType,
    args.kind,
    args.type,
    payload.layerKind,
    payload.layer_kind,
    payload.kind,
    payload.type,
    updates.layerKind,
    updates.kind,
    updates.type,
  ).toLowerCase().replace(/[^a-z0-9]+/g, '_');
  if (rawKind.includes('text')) return 'text';
  if (rawKind.includes('shape')) return 'shape';
  if (rawKind.includes('video')) return 'media';
  if (rawKind.includes('image')) return 'media';
  if (rawKind.includes('audio')) return 'media';
  if (rawKind.includes('media')) return 'media';
  if (
    rawKind.includes('solid') ||
    rawKind.includes('background') ||
    rawKind.includes('bg')
  ) {
    return 'solid';
  }
  const textValue = firstText(
    args.text,
    args.content,
    args.title,
    payload.text,
    payload.content,
    payload.value,
    updatePayload.text,
    updatePayload.content,
  );
  if (textValue) return 'text';
  if (inferLayerColor(args, payload) || firstText(style.fill, style.color)) {
    return 'solid';
  }
  return 'solid';
}

function inferLayerColor(args: JsonMap, payload: JsonMap): string | null {
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  const style = readMap(payload.style);
  const updateStyle = readMap(updates.style);
  const raw = firstText(
    args.color,
    args.fill,
    args.backgroundColor,
    payload.color,
    payload.fill,
    style.fill,
    style.color,
    updates.color,
    updates.fill,
    updatePayload.color,
    updatePayload.fill,
    updateStyle.fill,
    updateStyle.color,
  );
  if (!raw) return null;
  const directHex = inferColor(raw);
  if (directHex) return directHex;
  const normalized = raw.trim().replace(/^#/, '');
  if (/^[0-9a-fA-F]{6}$/.test(normalized)) {
    return `#${normalized.toUpperCase()}`;
  }
  if (/^[0-9a-fA-F]{8}$/.test(normalized)) {
    return `#${normalized.slice(2).toUpperCase()}`;
  }
  return null;
}

type MotionChannelWrite = {
  propertyId: string;
  keyframes: JsonMap[];
  motionRecipe?: string | null;
};

function inferMotionWrites(args: JsonMap): MotionChannelWrite[] {
  const payload = readMap(args.payload);
  const channels = readList(firstDefined(args.channels, payload.channels));
  const writes: MotionChannelWrite[] = [];
  if (channels.length > 0) {
    for (const channel of channels) {
      const map = readMap(channel);
      const propertyId = canonicalMotionPropertyId(
        firstText(map.propertyId, map.property, map.targetProperty),
      );
      if (!propertyId) continue;
      const keyframes = parseKeyframes(map.keyframes);
      if (keyframes.length === 0) continue;
      writes.push({
        propertyId,
        keyframes,
        motionRecipe: text(map.motionRecipe, '') || null,
      });
    }
  }
  if (writes.length > 0) {
    return writes;
  }

  const propertyId = canonicalMotionPropertyId(
    firstText(args.propertyId, args.property, payload.propertyId, payload.property),
  );
  const directKeyframes = parseKeyframes(firstDefined(args.keyframes, payload.keyframes));
  if (propertyId && directKeyframes.length > 0) {
    return [{
      propertyId,
      keyframes: directKeyframes,
      motionRecipe: text(args.motionRecipe, '') || null,
    }];
  }

  const motionRecipe = firstText(
    args.motionRecipe,
    args.animationRecipe,
    args.recipe,
    payload.motionRecipe,
    payload.animationRecipe,
    payload.recipe,
  );
  if (motionRecipe) {
    return expandMotionRecipe(motionRecipe, numberValue(args.durationMs, 650));
  }

  return [];
}

function canonicalMotionPropertyId(value: string): string {
  const normalized = value.trim().toLowerCase();
  const aliases: Record<string, string> = {
    'positionx': 'transform.position.x',
    'position.x': 'transform.position.x',
    'positiony': 'transform.position.y',
    'position.y': 'transform.position.y',
    'scale.x': 'transform.scale.x',
    'scale.y': 'transform.scale.y',
    'scale': 'transform.scale.x',
    'rotation': 'transform.rotation.degrees',
    'rotation.degrees': 'transform.rotation.degrees',
    'opacity': 'visual.opacity',
  };
  if (!normalized) return '';
  return aliases[normalized] ?? normalized;
}

function expandMotionRecipe(recipe: string, durationMsRaw: number): MotionChannelWrite[] {
  const normalized = recipe.trim().toLowerCase();
  const durationMs = Math.max(240, Math.min(durationMsRaw, 5000));
  if (normalized === '$motion.scaleinbounce' || normalized === 'scaleinbounce') {
    const keyframes: JsonMap[] = [
      makeScalarKeyframe(0, 0.15, 'easeOut'),
      makeScalarKeyframe(Math.round(durationMs * 0.28), 1.18, 'easeOut'),
      makeScalarKeyframe(Math.round(durationMs * 0.51), 0.94, 'easeInOut'),
      makeScalarKeyframe(Math.round(durationMs * 0.77), 1.04, 'easeOut'),
      makeScalarKeyframe(durationMs, 1.0, 'easeInOut'),
    ];
    return [
      {
        propertyId: 'transform.scale.x',
        keyframes,
        motionRecipe: '$motion.scaleInBounce',
      },
      {
        propertyId: 'transform.scale.y',
        keyframes,
        motionRecipe: '$motion.scaleInBounce',
      },
      {
        propertyId: 'visual.opacity',
        keyframes: [
          makeScalarKeyframe(0, 0.0, 'linear'),
          makeScalarKeyframe(Math.round(durationMs * 0.24), 1.0, 'easeOut'),
          makeScalarKeyframe(durationMs, 1.0, 'linear'),
        ],
        motionRecipe: '$motion.scaleInBounce',
      },
    ];
  }
  throw new Error(`UNKNOWN_MOTION_RECIPE: ${recipe}`);
}

function makeScalarKeyframe(timeMs: number, value: number, easing = 'linear'): JsonMap {
  return {
    id: `kf_${randomBase32(8).toLowerCase()}`,
    timeMs: Math.max(0, Math.round(timeMs)),
    value,
    easing,
  };
}

function parseKeyframes(value: unknown): JsonMap[] {
  const list = readList(value);
  const parsed: JsonMap[] = [];
  for (const entry of list) {
    const map = parseKeyframe(entry);
    if (map) parsed.push(map);
  }
  parsed.sort((a, b) => numberValue(a.timeMs, 0) - numberValue(b.timeMs, 0));
  return parsed;
}

function parseKeyframe(value: unknown): JsonMap | null {
  const map = readMap(value);
  const timeMs = optionalNumber(firstDefined(map.timeMs, map.time, map.t));
  if (timeMs == null || timeMs < 0) {
    return null;
  }
  const rawValue = firstDefined(map.value, map.v);
  const numericValue = numberOrNull(rawValue);
  const keyframeValue = numericValue ?? rawValue;
  if (keyframeValue === undefined || keyframeValue === null) {
    return null;
  }
  return {
    id: firstText(map.id) || `kf_${randomBase32(8).toLowerCase()}`,
    timeMs,
    value: keyframeValue,
    easing: firstText(map.easing, map.interpolation, 'linear'),
  };
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value.trim());
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function sanitizeLayerPayload(value: unknown): JsonMap {
  const blocked = new Set([
    'agentsessiontoken',
    'sessiontoken',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'password',
    'secret',
    'apikey',
    'token',
  ]);
  const visit = (input: unknown): unknown => {
    if (Array.isArray(input)) {
      return input.map(visit);
    }
    if (input && typeof input === 'object') {
      const out: JsonMap = {};
      for (const [rawKey, rawValue] of Object.entries(input as JsonMap)) {
        const normalized = rawKey.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
        if (blocked.has(normalized)) continue;
        out[rawKey] = visit(rawValue);
      }
      return out;
    }
    return input;
  };
  return readMap(visit(value));
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
