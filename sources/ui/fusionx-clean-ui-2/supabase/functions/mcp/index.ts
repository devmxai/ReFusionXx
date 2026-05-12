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
]);

const userOnlyTools = new Set<string>([
  'refusion.create_project',
  'refusion.set_active_context',
  'refusion.touch_editor_session',
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
    case 'refusion.get_layers':
      return await getLayers(context, args);
    case 'refusion.get_command_status':
      return await getCommandStatus(context, args);
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
  if (value.startsWith('refusion.')) {
    return value;
  }
  const aliases: Record<string, string> = {
    get_active_context: 'refusion.get_active_context',
    get_project_state: 'refusion.get_project_state',
    create_project: 'refusion.create_project',
    set_active_context: 'refusion.set_active_context',
    touch_editor_session: 'refusion.touch_editor_session',
    generate_pairing_code: 'refusion.generate_pairing_code',
    get_pairing_code_status: 'refusion.get_pairing_code_status',
    attach_pairing_code: 'refusion.attach_pairing_code',
    insert_layer: 'refusion.insert_layer',
    apply_scene_program: 'refusion.apply_scene_program',
    get_layers: 'refusion.get_layers',
    get_command_status: 'refusion.get_command_status',
    disconnect_agent: 'refusion.disconnect_agent',
  };
  return aliases[value] ?? value;
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

  await ensurePairingContext(userId, {
    deviceId,
    projectId,
    compositionId,
    timelineId,
    playheadMs,
    timelineRevision: await projectRevision(projectId),
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
    timeline_revision: await projectRevision(projectId),
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

  const layerKind = text(args.layerKind ?? args.kind, 'solid');
  const payload = sanitizeLayerPayload(readMap(args.payload));
  const color = text(args.color ?? payload.color, '#FFFFFF');
  const name = text(args.name, layerKind === 'solid' ? 'Background' : 'Layer');
  const durationMs = numberValue(
    args.durationMs,
    numberValue(composition.durationMs, 8000),
  );

  const { data: layer, error } = await admin
    .from('refusion_layers')
    .insert({
      owner_id: context.userId,
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
      color,
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
  const source = text(args.source, '');
  const color = inferColor(source) ?? '#FFFFFF';
  return await insertLayer(context, {
    ...args,
    layerKind: 'solid',
    name: text(args.name, 'Scene Background'),
    color,
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
  return ok('Command status loaded.', data);
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
  const insertPayload: JsonMap = {
    owner_id: context.userId,
    project_id: projectId,
    composition_id: compositionId,
    command_type: commandType,
    payload,
    revision_before: revisionBefore,
    revision_after: revisionAfter,
    status: 'succeeded',
    result: payload,
    completed_at: new Date().toISOString(),
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
    const code = `REF-${randomBase32(4)}`;
    const { data } = await admin.from('refusion_pairing_codes').select('id').eq(
      'code',
      code,
    ).maybeSingle();
    if (!data) {
      return code;
    }
  }
  return `REF-${randomBase32(6)}`;
}

function normalizePairingCode(value: string): string {
  const normalized = value.trim().toUpperCase();
  if (!/^REF-[0-9A-HJKMNP-TV-Z]{4,6}$/.test(normalized)) {
    return '';
  }
  return normalized;
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
      'refusion.generate_pairing_code',
      'Generate Pairing Code',
      'Generate one-time pairing code for current active context.',
      true,
    ),
    tool(
      'refusion.get_pairing_code_status',
      'Get Pairing Code Status',
      'Fetch pairing-code lifecycle state (pending, claimed, expired, revoked).',
    ),
    tool(
      'refusion.attach_pairing_code',
      'Attach Pairing Code',
      'Claim pairing code and issue agent session token.',
      true,
    ),
    tool(
      'refusion.insert_layer',
      'Insert Layer',
      'Insert a layer into the active composition.',
      true,
    ),
    tool(
      'refusion.apply_scene_program',
      'Apply Scene Program',
      'Apply a minimal SceneProgram as a layer mutation.',
      true,
    ),
    tool(
      'refusion.get_layers',
      'Get Layers',
      'Return composition layers ordered by z-index and start.',
    ),
    tool(
      'refusion.get_command_status',
      'Get Command Status',
      'Return a command status by id.',
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
