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
  'refusion.update_layer',
  'refusion.apply_scene_program',
  'refusion.apply_motion_patch',
  'refusion.apply_animation_recipe',
  'refusion.apply_keyframes',
  'refusion.keyframe_edit',
  'refusion.set_element_transform',
  'refusion.set_text_style',
  'refusion.trim_clip',
  'refusion.split_clip',
  'refusion.set_layer_mask',
  'refusion.set_border',
  'refusion.set_glow',
  'refusion.set_layer_style',
  'refusion.apply_video_pip_recipe',
  'refusion.position_at_anchor',
  'refusion.align_to',
  'refusion.fit_in_zone',
  'refusion.scale_to',
  'refusion.center_in',
]);

const userOnlyTools = new Set<string>([
  'refusion.create_project',
  'refusion.set_active_context',
  'refusion.touch_editor_session',
  'refusion.sync_editor_layers',
  'refusion.get_pending_commands',
  'refusion.ack_command_applied',
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
      normalizedErrorMessage(error),
    );
  }
});

function normalizedErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (error && typeof error === 'object') {
    const map = error as Record<string, unknown>;
    const message = typeof map.message === 'string' ? map.message : '';
    const details = typeof map.details === 'string' ? map.details : '';
    const hint = typeof map.hint === 'string' ? map.hint : '';
    const code = typeof map.code === 'string' ? map.code : '';
    const parts = [message, details, hint].filter((v) => v.trim().length > 0);
    if (parts.length > 0) {
      return code ? `${code}: ${parts.join(' | ')}` : parts.join(' | ');
    }
  }
  return String(error);
}

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
    case 'refusion.get_pending_commands':
      ensureUserTool(canonicalToolName, context);
      return await getPendingCommands(context.userId, args);
    case 'refusion.ack_command_applied':
      ensureUserTool(canonicalToolName, context);
      return await ackCommandApplied(context.userId, args);
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
    case 'refusion.update_layer':
      ensureAgentWrite(canonicalToolName, context);
      return await updateLayer(context, args);
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
    case 'refusion.set_text_style':
      ensureAgentWrite(canonicalToolName, context);
      return await setTextStyle(context, args);
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
    case 'refusion.apply_video_pip_recipe':
      ensureAgentWrite(canonicalToolName, context);
      return await applyVideoPipRecipe(context, args);
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
    case 'refusion.align_to':
      ensureAgentWrite(canonicalToolName, context);
      return await alignTo(context, args);
    case 'refusion.fit_in_zone':
      ensureAgentWrite(canonicalToolName, context);
      return await fitInZone(context, args);
    case 'refusion.scale_to':
      ensureAgentWrite(canonicalToolName, context);
      return await scaleTo(context, args);
    case 'refusion.center_in':
      ensureAgentWrite(canonicalToolName, context);
      return await centerIn(context, args);
    case 'refusion.layout.preview_change':
      return await previewLayoutChange(context, args);
    case 'refusion.layout.validate_intent':
      return await validateLayoutIntent(context, args);
    case 'refusion.layout.detect_overlaps':
      return await detectLayoutOverlaps(context, args);
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
    get_pending_commands: 'refusion.get_pending_commands',
    pending_commands: 'refusion.get_pending_commands',
    ack_command_applied: 'refusion.ack_command_applied',
    ack_applied: 'refusion.ack_command_applied',
    generate_pairing_code: 'refusion.generate_pairing_code',
    get_pairing_code_status: 'refusion.get_pairing_code_status',
    attach_pairing_code: 'refusion.attach_pairing_code',
    claim_pairing_code: 'refusion.attach_pairing_code',
    connect_pairing_code: 'refusion.attach_pairing_code',
    insert_layer: 'refusion.insert_layer',
    update_layer: 'refusion.update_layer',
    insert_text: 'refusion.insert_layer',
    add_text: 'refusion.insert_layer',
    create_text: 'refusion.insert_layer',
    update_text: 'refusion.update_layer',
    edit_text: 'refusion.update_layer',
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
    set_text_style: 'refusion.set_text_style',
    trim_clip: 'refusion.trim_clip',
    split_clip: 'refusion.split_clip',
    set_layer_mask: 'refusion.set_layer_mask',
    set_border: 'refusion.set_border',
    set_glow: 'refusion.set_glow',
    set_layer_style: 'refusion.set_layer_style',
    apply_video_pip_recipe: 'refusion.apply_video_pip_recipe',
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
    align_to: 'refusion.align_to',
    fit_in_zone: 'refusion.fit_in_zone',
    scale_to: 'refusion.scale_to',
    center_in: 'refusion.center_in',
    preview_change: 'refusion.layout.preview_change',
    validate_intent: 'refusion.layout.validate_intent',
    detect_overlaps: 'refusion.layout.detect_overlaps',
    evaluate_frame: 'refusion.evaluate_frame',
    explain_capabilities: 'refusion.explain_capabilities',
    get_motion_channels: 'refusion.get_motion_channels',
    get_keyframes: 'refusion.get_keyframes',
    get_command_status: 'refusion.get_command_status',
    wait_for_apply: 'refusion.wait_for_apply',
    disconnect_agent: 'refusion.disconnect_agent',
    'refusion.insert_text': 'refusion.insert_layer',
    'refusion.update_text': 'refusion.update_layer',
    'refusion.update_layer': 'refusion.update_layer',
    'refusion.update': 'refusion.update_layer',
    'refusion.edit_layer': 'refusion.update_layer',
    'refusion.set_text_style': 'refusion.set_text_style',
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
    'refusion.video.pip': 'refusion.apply_video_pip_recipe',
    'refusion.apply_video_pip': 'refusion.apply_video_pip_recipe',
    'refusion.surface.position.at_anchor': 'refusion.position_at_anchor',
    'refusion.surface.align_to': 'refusion.align_to',
    'refusion.surface.fit_in_zone': 'refusion.fit_in_zone',
    'refusion.surface.scale_to': 'refusion.scale_to',
    'refusion.surface.center_in': 'refusion.center_in',
    'refusion.layout.preview_change': 'refusion.layout.preview_change',
    'refusion.layout.validate_intent': 'refusion.layout.validate_intent',
    'refusion.layout.detect_overlaps': 'refusion.layout.detect_overlaps',
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

  if (session?.id && (!projectId || !compositionId)) {
    return {
      hasProject: false,
      project: null,
      composition: null,
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

  const resolved = await resolveOwnedProjectAndComposition(
    context.userId,
    projectId,
    compositionId,
  );
  projectId = resolved.projectId;
  compositionId = resolved.compositionId;

  if (session?.id && (
    stringValue(session.project_id) !== projectId ||
      stringValue(session.composition_id) !== compositionId
  )) {
    await admin.from('refusion_editor_sessions').update({
      project_id: projectId,
      composition_id: compositionId,
      timeline_revision: await projectRevision(projectId),
      updated_at: new Date().toISOString(),
    }).eq('id', stringValue(session.id));
  }

  const project = await selectById('refusion_projects', projectId);
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
  const { data: editorSessionRows, error: editorSessionError } = await admin
    .from('refusion_editor_sessions')
    .select('*')
    .eq('owner_id', agentSession.owner_id)
    .eq('project_id', agentSession.project_id)
    .eq('composition_id', agentSession.composition_id)
    .in('status', ['online', 'background'])
    .order('foreground', { ascending: false })
    .order('last_seen_at', { ascending: false })
    .limit(1);
  if (editorSessionError) throw editorSessionError;
  const editorSession = (editorSessionRows ?? [])[0] as JsonMap | null;
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
      sessionId: editorSession?.id ?? null,
      editorSessionId: editorSession?.id ?? null,
      appSessionId: agentSession.app_session_id,
      deviceId: editorSession?.device_id ?? null,
      foreground: editorSession?.foreground ?? true,
      lastSeenAt: editorSession?.last_seen_at ?? null,
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
  if (args.hasActiveComposition === false) {
    await touchEditorSession(userId, {
      ...args,
      projectId: '',
      compositionId: '',
      hasActiveComposition: false,
    });
    return await getActiveContext(
      { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
      {},
    );
  }
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const currentProjectId = stringValue(readMap(active.project).id);
  const currentCompositionId = stringValue(readMap(active.composition).id);
  const projectId = asUuidOrEmpty(stringValue(args.projectId)) || currentProjectId;
  const compositionId = asUuidOrEmpty(stringValue(args.compositionId)) || currentCompositionId;
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
  const hasActiveComposition = args.hasActiveComposition !== false;
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const inputProjectId = hasActiveComposition
    ? asUuidOrEmpty(stringValue(args.projectId)) ||
      stringValue(readMap(active.project).id)
    : '';
  const inputCompositionId = hasActiveComposition
    ? asUuidOrEmpty(stringValue(args.compositionId)) ||
      stringValue(readMap(active.composition).id)
    : '';
  const resolved = hasActiveComposition
    ? await resolveOwnedProjectAndComposition(
      userId,
      inputProjectId,
      inputCompositionId,
    )
    : { projectId: '', compositionId: '' };
  const projectId = resolved.projectId;
  const compositionId = resolved.compositionId;
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
    project_id: projectId || null,
    composition_id: compositionId || null,
    timeline_id: timelineId,
    playhead_ms: playheadMs,
    timeline_revision: timelineRevision ??
      (projectId ? await projectRevision(projectId) : 1),
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

  if (projectId && compositionId) {
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
  }

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
      layer_kind: layerKind,
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

async function getPendingCommands(
  userId: string,
  args: JsonMap,
): Promise<ToolResult> {
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const activeProjectId = stringValue(readMap(active.project).id);
  const activeCompositionId = stringValue(readMap(active.composition).id);
  const projectId = stringValue(args.projectId) || activeProjectId;
  const compositionId = stringValue(args.compositionId) || activeCompositionId;
  if (!projectId || !compositionId) {
    return fail('ACTIVE_CONTEXT_REQUIRED');
  }

  const requestedLimit = Math.max(
    1,
    Math.min(100, numberValue(args.limit, 30)),
  );
  const queryLimit = Math.max(requestedLimit, 80);
  const editorSessionId = firstText(
    args.editorSessionId,
    args.editor_session_id,
    args.appSessionId,
    args.sessionId,
  );
  const query = admin
    .from('refusion_agent_commands')
    .select('*')
    .eq('owner_id', userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .in('status', ['pending', 'running'])
    .order('created_at', { ascending: false })
    .limit(queryLimit);
  const { data: rows, error } = await query;
  if (error) throw error;

  const markReceived = args.markReceived !== false;
  const nowIso = new Date().toISOString();
  const nowMs = Date.parse(nowIso);
  const commands: JsonMap[] = [];
  for (const row of rows ?? []) {
    const rowMap = readMap(row);
    const rowSessionId = stringValue(rowMap.editor_session_id);
    const commandId = stringValue(rowMap.id);
    const status = text(rowMap.status, 'pending');
    const claimedAt = stringValue(rowMap.claimed_at);
    const claimedAgeMs = claimedAt ? nowMs - Date.parse(claimedAt) : Number.POSITIVE_INFINITY;
    const staleRunning =
      status === 'running' &&
      (!Number.isFinite(claimedAgeMs) || claimedAgeMs >= 10_000);
    const sessionMatches =
      !editorSessionId || !rowSessionId || rowSessionId === editorSessionId;
    if (status === 'running' && !sessionMatches && !staleRunning) {
      continue;
    }
    const result = readMap(rowMap.result);
    const shouldClaimForEditorSession = !!editorSessionId &&
      (!rowSessionId || rowSessionId !== editorSessionId || staleRunning);
    const shouldMarkReceived = status === 'pending' || shouldClaimForEditorSession;
    const nextLifecycle = {
      ...readMap(result.lifecycle),
      stage: shouldMarkReceived ? 'appReceived' : text(
        readMap(result.lifecycle).stage,
        'cloudCommitted',
      ),
      editorSessionId: editorSessionId || rowSessionId,
      appReceivedAt: shouldMarkReceived ? nowIso : firstText(
        readMap(result.lifecycle).appReceivedAt,
        nowIso,
      ),
    };
    if (markReceived && shouldMarkReceived && commandId) {
      const { error: receiveError } = await admin
        .from('refusion_agent_commands')
        .update({
          status: 'running',
          claimed_at: nowIso,
          editor_session_id: editorSessionId || rowSessionId,
          result: {
            ...result,
            lifecycle: nextLifecycle,
          },
        })
        .eq('owner_id', userId)
        .eq('id', commandId);
      if (receiveError) throw receiveError;
      rowMap.status = 'running';
      rowMap.result = {
        ...result,
        lifecycle: nextLifecycle,
      };
    }
    commands.push(rowMap);
    if (commands.length >= requestedLimit) {
      break;
    }
  }
  commands.sort((a, b) =>
    text(a.created_at, '').localeCompare(text(b.created_at, ''))
  );

  return ok('Pending commands loaded.', {
    schemaVersion: 'refusion.commandBus/v1',
    projectId,
    compositionId,
    appSessionId: editorSessionId,
    editorSessionId,
    count: commands.length,
    commands,
  });
}

async function ackCommandApplied(
  userId: string,
  args: JsonMap,
): Promise<ToolResult> {
  const active = await getActiveContext(
    { userId, authSource: 'bearer', agentSession: null, agentSessionToken: null },
    {},
  );
  const activeProjectId = stringValue(readMap(active.project).id);
  const activeCompositionId = stringValue(readMap(active.composition).id);
  const projectId = stringValue(args.projectId) || activeProjectId;
  const compositionId = stringValue(args.compositionId) || activeCompositionId;
  const revision = optionalNumber(
    firstDefined(args.revision, args.revisionAfter, args.timelineRevision),
  );
  if (!projectId || !compositionId) {
    return fail('ACK_CONTEXT_REQUIRED');
  }

  const explicitCommandId = stringValue(args.commandId);
  const explicitCommandIds = readList(args.commandIds)
    .map((value) => stringValue(value))
    .filter((value) => value.length > 0);
  const targetCommandIds = [
    ...new Set<string>([
      ...explicitCommandIds,
      ...(explicitCommandId ? [explicitCommandId] : []),
    ]),
  ];

  let query = admin
    .from('refusion_agent_commands')
    .select('*')
    .eq('owner_id', userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .in('status', ['pending', 'running']);
  if (targetCommandIds.length > 0) {
    query = query.in('id', targetCommandIds);
  } else if (revision != null) {
    query = query.lte('revision_after', revision);
  } else {
    return fail('ACK_COMMAND_ID_REQUIRED');
  }
  const { data: commands, error } = await query.order('created_at', {
    ascending: true,
  });
  if (error) throw error;
  const editorSessionId = firstText(
    args.editorSessionId,
    args.editor_session_id,
    args.appSessionId,
    args.sessionId,
  );
  const appSessionId = firstText(
    args.appSessionId,
    args.app_session_id,
  );
  const deviceId = firstText(args.deviceId, args.device_id);
  const proofInput = readMap(args.proof);
  const diagnosticsInput = readMap(args.diagnostics);
  const blockers = readList(firstDefined(args.blockers, diagnosticsInput.blockers))
    .map(readMap);
  const warnings = readList(firstDefined(args.warnings, diagnosticsInput.warnings))
    .map(readMap);
  const requestedAppliedSuccessfully = firstDefined(
    args.appliedSuccessfully,
    args.applied,
    proofInput.appliedSuccessfully,
    blockers.length == 0,
  ) !== false;

  const nowIso = new Date().toISOString();
  let acknowledged = 0;
  const acknowledgedCommandIds: string[] = [];
  const failedCommandIds: string[] = [];
  for (const command of commands ?? []) {
    const commandMap = readMap(command);
    const commandId = stringValue(commandMap.id);
    const commandRevision = optionalNumber(commandMap.revision_after);
    if (revision != null &&
        (commandRevision == null || commandRevision > revision)) {
      continue;
    }
    const existingResult = readMap(commandMap.result);
    const lifecycle = readMap(existingResult.lifecycle);
    const commandPayload = readMap(commandMap.payload);
    const nextProof: JsonMap = {
      dataApplied: firstDefined(
        args.dataApplied,
        proofInput.dataApplied,
        requestedAppliedSuccessfully,
      ) === true,
      localGraphApplied: firstDefined(
        args.localGraphApplied,
        proofInput.localGraphApplied,
        requestedAppliedSuccessfully,
      ) === true,
      timelineVisible: firstDefined(
        args.timelineVisible,
        proofInput.timelineVisible,
        requestedAppliedSuccessfully,
      ) === true,
      playerInvalidated: firstDefined(
        args.playerInvalidated,
        proofInput.playerInvalidated,
        requestedAppliedSuccessfully,
      ) === true,
      frameEvaluated: firstDefined(
        args.frameEvaluated,
        proofInput.frameEvaluated,
        requestedAppliedSuccessfully,
      ) === true,
      visualProgramEmitted: firstDefined(
        args.visualProgramEmitted,
        proofInput.visualProgramEmitted,
        requestedAppliedSuccessfully,
      ) === true,
      rendererApplied: firstDefined(
        args.rendererApplied,
        proofInput.rendererApplied,
        requestedAppliedSuccessfully,
      ) === true,
      visualBoundsVerified: firstDefined(
        args.visualBoundsVerified,
        proofInput.visualBoundsVerified,
        requestedAppliedSuccessfully,
      ) === true,
      pixelVerified: firstDefined(
        args.pixelVerified,
        proofInput.pixelVerified,
        false,
      ) === true,
      proofFrameTimeMs: optionalNumber(firstDefined(
        args.proofFrameTimeMs,
        proofInput.proofFrameTimeMs,
      )),
      proofFrameIndex: optionalNumber(firstDefined(
        args.proofFrameIndex,
        proofInput.proofFrameIndex,
      )),
      proofBounds: readMap(firstDefined(args.proofBounds, proofInput.proofBounds)),
      screenshotUrl: firstText(args.screenshotUrl, proofInput.screenshotUrl),
      screenshotHash: firstText(args.screenshotHash, proofInput.screenshotHash),
      targetLayerId: firstText(
        args.targetLayerId,
        proofInput.targetLayerId,
        stringValue(commandPayload.layerId),
      ),
      operationApplied: firstText(
        args.operationApplied,
        proofInput.operationApplied,
        text(existingResult.operationApplied, ''),
      ),
      createdLayerCount: numberValue(
        firstDefined(
          args.createdLayerCount,
          proofInput.createdLayerCount,
          existingResult.createdLayerCount,
          0,
        ),
        0,
      ),
      updatedLayerCount: numberValue(
        firstDefined(
          args.updatedLayerCount,
          proofInput.updatedLayerCount,
          existingResult.updatedLayerCount,
          0,
        ),
        0,
      ),
    };
    const appliedSuccessfully = requestedAppliedSuccessfully &&
      nextProof.dataApplied === true &&
      nextProof.localGraphApplied === true &&
      nextProof.timelineVisible === true &&
      nextProof.frameEvaluated === true &&
      nextProof.visualProgramEmitted === true &&
      nextProof.rendererApplied === true &&
      nextProof.visualBoundsVerified === true;
    const nextStatus = appliedSuccessfully ? 'succeeded' : 'failed';
    const nextResult: JsonMap = {
      ...existingResult,
      appApplied: appliedSuccessfully,
      appliedTimelineRevision: revision ?? commandRevision,
      appliedAt: nowIso,
      appliedBy: 'open-app',
      schemaVersion: 'refusion.commandReceipt/v1',
      proof: nextProof,
      diagnostics: {
        warnings,
        blockers,
      },
      lifecycle: {
        ...lifecycle,
        stage: appliedSuccessfully ? 'rendererApplied' : 'blocked',
        appSessionId: appSessionId || firstText(lifecycle.appSessionId),
        editorSessionId: editorSessionId || firstText(lifecycle.editorSessionId),
        deviceId: deviceId || firstText(lifecycle.deviceId),
        ackAt: nowIso,
      },
    };
    const { error: updateError } = await admin
      .from('refusion_agent_commands')
      .update({
        status: nextStatus,
        editor_session_id: editorSessionId || commandMap.editor_session_id,
        result: nextResult,
        error_message: appliedSuccessfully
          ? null
          : firstText(
            args.errorMessage,
            diagnosticsInput.errorMessage,
            blockers
              .map((entry) => text(entry.code, ''))
              .filter((entry) => entry.length > 0)
              .join(','),
            'APP_APPLY_FAILED',
          ),
        completed_at: nowIso,
        updated_at: nowIso,
      })
      .eq('owner_id', userId)
      .eq('id', commandId);
    if (updateError) throw updateError;
    acknowledged += 1;
    if (appliedSuccessfully) {
      acknowledgedCommandIds.push(commandId);
    } else {
      failedCommandIds.push(commandId);
    }
  }

  return ok('Commands acknowledged.', {
    projectId,
    compositionId,
    revision,
    acknowledged,
    commandIds: acknowledgedCommandIds,
    failedCommandIds,
    appSessionId,
    editorSessionId,
    appliedSuccessfully: acknowledged > 0 && failedCommandIds.length === 0,
  });
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
  const projectId = stringValue(args.projectId);
  const compositionId = stringValue(args.compositionId);
  if (args.hasActiveComposition === false || !projectId || !compositionId) {
    return fail('ACTIVE_COMPOSITION_REQUIRED');
  }
  const context = await ensurePairingContext(userId, {
    deviceId: text(args.deviceId, ''),
    projectId,
    compositionId,
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

function hasMotionIntentInput(args: JsonMap, payload: JsonMap): boolean {
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  return (
    readList(firstDefined(args.channels, payload.channels)).length > 0 ||
    readList(firstDefined(args.keyframes, payload.keyframes)).length > 0 ||
    Object.keys(
      readMap(firstDefined(args.motion, payload.motion, updates.motion, updatePayload.motion)),
    ).length > 0 ||
    Object.keys(
      readMap(firstDefined(args.animation, payload.animation, updates.animation, updatePayload.animation)),
    ).length > 0 ||
    firstText(
      args.motionRecipe,
      args.animationRecipe,
      args.recipe,
      payload.motionRecipe,
      payload.animationRecipe,
      payload.recipe,
    ).trim().length > 0
  );
}

function detectInsertUpdateIntent(
  args: JsonMap,
  payload: JsonMap,
  layerKind: string,
): { isUpdate: boolean; reason: string } {
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
  const explicitTargetRef = hasExplicitTargetReference(args) ||
    firstText(
      payload.layerId,
      payload.layer_id,
      payload.targetLayerId,
      payload.target_layer_id,
      updates.layerId,
      updates.layer_id,
      updates.targetLayerId,
      updates.target_layer_id,
      updatePayload.layerId,
      updatePayload.layer_id,
      updatePayload.targetLayerId,
      updatePayload.target_layer_id,
    ).trim().length > 0;
  if (explicitTargetRef) {
    return { isUpdate: true, reason: 'explicit_target' };
  }
  if (Object.keys(updates).length > 0) {
    return { isUpdate: true, reason: 'updates_payload' };
  }
  if (hasMotionIntentInput(args, payload)) {
    return { isUpdate: true, reason: 'motion_payload' };
  }
  if (
    operation.includes('update') ||
    operation.includes('edit') ||
    operation.includes('animate') ||
    operation.includes('keyframe') ||
    operation.includes('transform') ||
    operation.includes('style')
  ) {
    return { isUpdate: true, reason: 'operation_update_intent' };
  }
  const sourceHint = firstText(
    args.source,
    args.prompt,
    args.userPrompt,
    args.instruction,
  ).toLowerCase();
  const referencesExisting = /(\bsame\b|\bexisting\b|\bcurrent\b|نفس|الموجود|الحالي)/.test(sourceHint);
  const includesStylePatch = firstDefined(
    args.fontSize,
    args.font_size,
    args.color,
    args.opacity,
    args.x,
    args.y,
    args.scale,
    args.scaleX,
    args.scaleY,
    payload.fontSize,
    payload.font_size,
    payload.color,
    payload.opacity,
    payload.x,
    payload.y,
    payload.scale,
    payload.scaleX,
    payload.scaleY,
  ) != null;
  if (layerKind === 'text' && referencesExisting && includesStylePatch) {
    return { isUpdate: true, reason: 'implicit_same_text_update' };
  }
  return { isUpdate: false, reason: '' };
}

function hasExplicitDuplicateIntent(args: JsonMap, payload: JsonMap): boolean {
  if (
    firstDefined(
      args.allowDuplicate,
      args.allow_duplicate,
      payload.allowDuplicate,
      payload.allow_duplicate,
    ) === true
  ) {
    return true;
  }
  const sourceHint = firstText(
    args.source,
    args.prompt,
    args.userPrompt,
    args.instruction,
  ).toLowerCase();
  return /(\bnew\b|\bduplicate\b|\bcopy\b|جديد|انسخ|نسخة)/.test(sourceHint);
}

function hasTextStylePatchInput(args: JsonMap, payload: JsonMap): boolean {
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  const style = readMap(payload.style);
  const updateStyle = readMap(updates.style);
  return firstDefined(
    args.fontSize,
    args.font_size,
    args.color,
    args.fill,
    args.opacity,
    args.x,
    args.y,
    args.scale,
    args.scaleX,
    args.scaleY,
    payload.fontSize,
    payload.font_size,
    payload.color,
    payload.fill,
    payload.opacity,
    payload.x,
    payload.y,
    payload.scale,
    payload.scaleX,
    payload.scaleY,
    updatePayload.fontSize,
    updatePayload.font_size,
    updatePayload.color,
    updatePayload.fill,
    updatePayload.opacity,
    updatePayload.x,
    updatePayload.y,
    updatePayload.scale,
    updatePayload.scaleX,
    updatePayload.scaleY,
  ) != null ||
    Object.keys(style).length > 0 ||
    Object.keys(updateStyle).length > 0;
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
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
    });
  }

  const payload = canonicalLayerPayload(args);
  const layerKind = inferLayerKind(args, payload);
  const updateIntent = detectInsertUpdateIntent(args, payload, layerKind);
  if (updateIntent.isUpdate) {
    const layers = await loadLayersForScope(context, projectId, compositionId);
    const preferredKinds = layerKind.trim().length > 0 ? [layerKind] : [];
    const targetResolution = resolveTargetForEdit(layers, args, {
      preferredKinds,
      playheadMs: optionalNumber(readMap(activeContext.timeline).playheadMs),
    });
    if (targetResolution.kind === 'ambiguous') {
      return fail('AMBIGUOUS_TARGET', {
        hint: 'Multiple candidate layers match this update intent. Provide layerId/targetLayerId.',
        candidates: targetCandidatesPayload(targetResolution.candidates),
      });
    }
    const targetLayer = targetResolution.layer;
    if (targetLayer == null) {
      return fail('TARGET_NOT_FOUND', {
        hint: 'Insert was interpreted as update intent but no target layer was resolved.',
        reason: updateIntent.reason,
        code: 'INSERT_USED_FOR_UPDATE',
      });
    }
    return await updateLayer(context, {
      ...args,
      projectId,
      compositionId,
      layerId: stringValue(targetLayer.id),
      expectedRevision: currentRevision,
      operation: firstText(args.operation, 'update_layer'),
    });
  }
  if (
    layerKind === 'text' &&
    !hasExplicitDuplicateIntent(args, payload) &&
    hasTextStylePatchInput(args, payload)
  ) {
    const textValue = firstText(args.text, args.content, payload.text, payload.content);
    if (textValue.trim().length > 0) {
      const layers = await loadLayersForScope(context, projectId, compositionId);
      const targetResolution = resolveTargetForEdit(layers, args, {
        preferredKinds: ['text'],
        playheadMs: optionalNumber(readMap(activeContext.timeline).playheadMs),
        targetText: textValue,
      });
      if (targetResolution.kind === 'ambiguous') {
        return fail('AMBIGUOUS_TARGET', {
          hint: 'Multiple existing text layers have the same content. Provide layerId/targetLayerId or set allowDuplicate=true to create another text layer.',
          candidates: targetCandidatesPayload(targetResolution.candidates),
        });
      }
      if (targetResolution.layer != null) {
        return await updateLayer(context, {
          ...args,
          projectId,
          compositionId,
          layerId: stringValue(targetResolution.layer.id),
          expectedRevision: currentRevision,
          operation: 'update_layer',
        });
      }
    }
  }
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
    operationApplied: 'insert',
    createdLayerCount: 1,
    updatedLayerCount: 0,
    targetLayerId: layer.id,
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
  const payload = canonicalLayerPayload(args);
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  const incomingStyle = readMap(firstDefined(args.style, payload.style, updates.style, updatePayload.style));
  const incomingMask = readMap(
    firstDefined(args.mask, payload.mask, updates.mask, updatePayload.mask, incomingStyle.mask),
  );
  const incomingBorder = readMap(firstDefined(args.border, payload.border, updates.border, updatePayload.border));
  const incomingGlow = readMap(firstDefined(args.glow, payload.glow, updates.glow, updatePayload.glow));
  const hasStyleMutationIntent =
    Object.keys(incomingStyle).length > 0 ||
    Object.keys(incomingMask).length > 0 ||
    Object.keys(incomingBorder).length > 0 ||
    Object.keys(incomingGlow).length > 0 ||
    !!firstText(
      args.maskType,
      args.clipPath,
      args.renderMask?.toString(),
      args.borderColor,
      args.glowColor,
      stringValue(args.cornerRadius),
      stringValue(args.borderWidth),
      payload.maskType,
      payload.clipPath,
      payload.renderMask?.toString(),
      payload.borderColor,
      stringValue(payload.cornerRadius),
      stringValue(payload.borderWidth),
    );

  if (hasStyleMutationIntent) {
    const resolved = await resolveProjectScope(context, args);
    if (!resolved) {
      return fail('PROJECT_NOT_OPEN');
    }
    const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
    const explicitLayerRef = firstText(
      args.layerId,
      args.layer_id,
      args.targetLayerId,
      args.clipId,
      args.clip_id,
      payload.layerId,
      payload.layer_id,
      payload.targetLayerId,
      payload.target_layer_id,
      updates.layerId,
      updates.layer_id,
      updates.targetLayerId,
      updates.target_layer_id,
      updatePayload.layerId,
      updatePayload.layer_id,
      updatePayload.targetLayerId,
      updatePayload.target_layer_id,
    );

    let targetLayer: JsonMap | null = null;
    if (explicitLayerRef) {
      targetLayer = resolveTargetLayer(layers, { ...args, layerId: explicitLayerRef });
      if (!targetLayer) {
        const resolvedId = await resolveLayerIdForMutation(
          context,
          resolved.projectId,
          resolved.compositionId,
          explicitLayerRef,
        );
        if (resolvedId) {
          targetLayer = resolveTargetLayer(layers, { ...args, layerId: resolvedId });
        }
      }
    }
    if (!targetLayer && !explicitLayerRef) {
      const autoResolution = resolveTargetForEdit(layers, args, {
        preferredKinds: ['media'],
      });
      if (autoResolution.kind === 'ambiguous') {
        return fail('AMBIGUOUS_TARGET', {
          hint:
            'Multiple media layers found. Provide layerId/targetLayerId/clipId explicitly.',
          candidates: targetCandidatesPayload(autoResolution.candidates),
        });
      }
      targetLayer = autoResolution.layer;
    }
    if (!targetLayer) {
      return fail('LAYER_NOT_FOUND', {
        hint: 'Provide layerId/clipId for video styling, or keep exactly one media layer active.',
      });
    }

    const rawMaskType = firstText(
      args.maskType,
      args.shape,
      args.type,
      payload.maskType,
      payload.shape,
      incomingMask.type,
      incomingMask.shape,
    ).toLowerCase();
    const borderWidth = numberOrNull(
      firstDefined(
        args.borderWidth,
        args.strokeWidth,
        payload.borderWidth,
        payload.strokeWidth,
        incomingBorder.width,
        incomingBorder.strokeWidth,
      ),
    );
    const borderColor = firstText(
      args.borderColor,
      args.strokeColor,
      payload.borderColor,
      payload.strokeColor,
      incomingBorder.color,
      incomingBorder.strokeColor,
    );
    const glowBlur = numberOrNull(
      firstDefined(
        args.blur,
        payload.glowBlur,
        readMap(payload.glow).blur,
        incomingGlow.blur,
        incomingGlow.radius,
      ),
    );
    const glowOpacity = numberOrNull(
      firstDefined(
        args.opacity,
        payload.glowOpacity,
        readMap(payload.glow).opacity,
        incomingGlow.opacity,
        incomingGlow.alpha,
      ),
    );
    const glowColor = firstText(
      args.glowColor,
      args.color,
      payload.glowColor,
      readMap(payload.glow).color,
      incomingGlow.color,
    );
    const cornerRadius = numberOrNull(
      firstDefined(
        args.cornerRadius,
        args.borderRadius,
        payload.cornerRadius,
        payload.borderRadius,
        incomingMask.radius,
      ),
    );
    const clipPath = firstText(args.clipPath, payload.clipPath, readMap(payload.style).clipPath);
    const renderMask = firstDefined(
      args.renderMask,
      payload.renderMask,
      readMap(payload.style).renderMask,
    );

    const styleResult = await applyLayerStyleMutation(
      context,
      {
        ...args,
        layerId: stringValue(targetLayer.id),
      },
      'refusion.apply_scene_program.layer_style_redirect',
      (currentPayload) => {
        const currentStyle = readMap(currentPayload.style);
        const nextMask = {
          ...readMap(currentPayload.mask),
          ...incomingMask,
        };
        if (rawMaskType) {
          nextMask.type = rawMaskType;
        }
        if (cornerRadius != null) {
          nextMask.radius = cornerRadius;
        }
        const nextGlow = {
          ...readMap(currentPayload.glow),
          ...incomingGlow,
        };
        if (glowBlur != null) nextGlow.blur = glowBlur;
        if (glowOpacity != null) nextGlow.opacity = Math.max(0, Math.min(1, glowOpacity));
        if (glowColor) {
          nextGlow.color = inferLayerColor({ color: glowColor }, {}) ?? glowColor;
        }
        const nextBorder = {
          ...readMap(currentPayload.border),
          ...incomingBorder,
        };
        if (borderWidth != null) nextBorder.width = Math.max(0, borderWidth);
        if (borderColor) {
          nextBorder.color = inferLayerColor({ color: borderColor }, {}) ?? borderColor;
        }
        return {
          ...currentPayload,
          ...payload,
          ...(rawMaskType ? { maskType: rawMaskType } : {}),
          ...(cornerRadius != null ? { cornerRadius } : {}),
          ...(clipPath ? { clipPath } : {}),
          ...(renderMask != null ? { renderMask: renderMask === true } : {}),
          ...(borderWidth != null ? { borderWidth: Math.max(0, borderWidth) } : {}),
          ...(borderColor
            ? { borderColor: inferLayerColor({ color: borderColor }, {}) ?? borderColor }
            : {}),
          ...(Object.keys(nextGlow).length > 0 ? { glow: nextGlow } : {}),
          ...(Object.keys(nextBorder).length > 0 ? { border: nextBorder } : {}),
          ...(Object.keys(nextMask).length > 0 ? { mask: nextMask } : {}),
          style: {
            ...currentStyle,
            ...incomingStyle,
            ...(rawMaskType ? { maskType: rawMaskType } : {}),
            ...(cornerRadius != null ? { cornerRadius } : {}),
            ...(clipPath ? { clipPath } : {}),
            ...(renderMask != null ? { renderMask: renderMask === true } : {}),
            ...(borderWidth != null ? { borderWidth: Math.max(0, borderWidth) } : {}),
            ...(borderColor
              ? { borderColor: inferLayerColor({ color: borderColor }, {}) ?? borderColor }
              : {}),
            ...(Object.keys(nextGlow).length > 0 ? { glow: nextGlow } : {}),
            ...(Object.keys(nextBorder).length > 0 ? { border: nextBorder } : {}),
            ...(Object.keys(nextMask).length > 0 ? { mask: nextMask } : {}),
          },
        };
      },
    );
    if (!styleResult.ok) {
      return styleResult;
    }

    const legacyAnimation = readMap(
      firstDefined(
        updates.animation,
        payload.animation,
        updatePayload.animation,
      ),
    );
    const legacyKeyframes = readList(legacyAnimation.keyframes);
    if (legacyKeyframes.length == 0) {
      return styleResult;
    }

    const compositionSpec = buildCompositionSpec(resolved.composition, resolved.compositionId);
    const canvasWidth = Math.max(1, numberValue(compositionSpec.width, 1080));
    const canvasHeight = Math.max(1, numberValue(compositionSpec.height, 1920));
    const motionChannels = legacyAnimationChannelsToMotionWrites(
      legacyKeyframes,
      {
        canvasWidth,
        canvasHeight,
      },
    );
    if (motionChannels.length == 0) {
      return styleResult;
    }

    return await applyMotionPatch(context, {
      ...args,
      layerId: stringValue(targetLayer.id),
      channels: motionChannels,
      operation: 'animate_layer',
    });
  }

  const source = text(args.source, '');
  const color = inferColor(source) ?? inferLayerColor(args, payload) ?? '#FFFFFF';
  const layerKind = inferLayerKind(args, payload);
  const explicitBackgroundIntent =
    layerKind === 'solid' ||
    operation.includes('background') ||
    operation.includes('solid') ||
    firstText(args.layerKind, args.layer_kind, payload.layerKind, payload.layer_kind)
      .toLowerCase()
      .includes('solid');
  if (!explicitBackgroundIntent) {
    return fail('SCENE_PROGRAM_INSERT_BLOCKED_FOR_NON_BACKGROUND', {
      hint: 'For layer edits use refusion.set_layer_mask / set_border / set_glow / set_layer_style / set_element_transform.',
    });
  }
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
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const projectId = resolved.projectId;
  const compositionId = resolved.compositionId;
  const currentRevision = resolved.revision;
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
    });
  }

  const requestedLayerId = firstText(
    args.layerId,
    args.layer_id,
    args.targetLayerId,
    readMap(args.payload).layerId,
  );
  if (!requestedLayerId) {
    return fail('LAYER_ID_REQUIRED');
  }
  const layerId = await resolveLayerIdForMutation(
    context,
    projectId,
    compositionId,
    requestedLayerId,
  );
  if (!layerId) {
    return fail('LAYER_NOT_FOUND');
  }

  const writes = inferMotionWrites(args);
  if (writes.length === 0) {
    const payload = readMap(args.payload);
    const updates = readMap(payload.updates);
    const updatePayload = readMap(updates.payload);
    const requestedRecipe = firstText(
      args.motionRecipe,
      args.animationRecipe,
      args.recipe,
      payload.motionRecipe,
      payload.animationRecipe,
      updates.motionRecipe,
      updates.animationRecipe,
      updatePayload.motionRecipe,
      updatePayload.animationRecipe,
      readMap(payload.motion).preset,
      readMap(payload.animation).preset,
      readMap(updates.motion).preset,
      readMap(updates.animation).preset,
      readMap(updatePayload.motion).preset,
      readMap(updatePayload.animation).preset,
      readMap(readMap(payload.motion).in).preset,
      readMap(readMap(payload.animation).in).preset,
      readMap(readMap(updates.motion).in).preset,
      readMap(readMap(updates.animation).in).preset,
      readMap(readMap(updatePayload.motion).in).preset,
      readMap(readMap(updatePayload.animation).in).preset,
    );
    if (requestedRecipe.trim().length > 0) {
      return fail('UNKNOWN_MOTION_RECIPE', {
        motionRecipe: requestedRecipe,
        hint: 'Use a supported recipe such as $motion.scaleInBounce / $motion.slideInFromLeft.',
      });
    }
    return fail('MOTION_CHANNELS_REQUIRED');
  }
  const motionBaseTimeMs = resolveMotionBaseTimeMs(resolved.active, args);
  const normalizedWrites =
    motionBaseTimeMs > 0 && !hasExplicitMotionTime(args)
      ? shiftMotionWritesBy(writes, motionBaseTimeMs)
      : writes;

  for (const write of normalizedWrites) {
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
    if (error) {
      const message = text((error as JsonMap).message, '');
      if (message.includes('refusion_motion_channels')) {
        return fail('MOTION_CHANNEL_STORAGE_MISSING', {
          hint: 'Create and migrate table refusion_motion_channels before applying motion.',
        });
      }
      throw error;
    }
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
      writes: normalizedWrites,
      motionBaseTimeMs,
      requestedLayerId,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );
  return ok('Motion patch applied.', {
    projectId,
    compositionId,
    layerId,
    requestedLayerId,
    channels: normalizedWrites.length,
    motionBaseTimeMs,
    commandId: commandRecord.commandId,
    operationApplied: 'motion',
    createdLayerCount: 0,
    updatedLayerCount: 1,
    targetLayerId: layerId,
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

async function setTextStyle(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  return await updateLayer(context, {
    ...args,
    operation: firstText(args.operation, 'set_text_style'),
  });
}

async function updateLayer(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const currentRevision = resolved.revision;
  const expectedRevision = optionalNumber(args.expectedRevision);
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
    });
  }

  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const payload = canonicalLayerPayload(args);
  const inferredKind = inferLayerKind(args, payload);
  const operation = firstText(args.operation, args.command, args.action).toLowerCase();
  const preferredKinds = operation.includes('text')
    ? ['text']
    : inferredKind.trim().length > 0
    ? [inferredKind]
    : [];
  const targetResolution = resolveTargetForEdit(layers, args, {
    preferredKinds,
    playheadMs: optionalNumber(firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs)),
  });
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Multiple candidate layers match this update request. Provide layerId/targetLayerId.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
  if (!targetLayer) {
    return fail('TARGET_NOT_FOUND', {
      hint: 'No layer resolved for update.',
    });
  }

  const layerId = stringValue(targetLayer.id);
  const currentPayload = readMap(targetLayer.payload);
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
  const mergedStyle = {
    ...readMap(currentPayload.style),
    ...readMap(payload.style),
    ...readMap(updates.style),
    ...readMap(updatePayload.style),
  };
  const nextPayload: JsonMap = {
    ...currentPayload,
    ...payload,
    ...updatePayload,
  };
  delete nextPayload.updates;
  if (Object.keys(mergedStyle).length > 0) {
    nextPayload.style = mergedStyle;
  }
  const textValue = firstText(
    args.text,
    args.content,
    payload.text,
    payload.content,
    updatePayload.text,
    updatePayload.content,
  );
  if (textValue.trim().length > 0) {
    nextPayload.text = textValue;
    nextPayload.content = textValue;
  }

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
    'refusion.update_layer',
    {
      layerId,
      payload: nextPayload,
    },
    currentRevision,
    revisionAfter,
    stringValue(args.idempotencyKey),
  );

  if (hasMotionIntentInput(args, payload)) {
    const motionResult = await applyMotionPatch(context, {
      ...args,
      projectId: resolved.projectId,
      compositionId: resolved.compositionId,
      layerId,
      allowRebase: true,
      autoRebase: true,
      expectedRevision: revisionAfter,
    });
    if (!motionResult.ok) {
      return motionResult;
    }
    const motionPayload = readMap(motionResult.payload);
    return ok('Layer updated and motion applied.', {
      projectId: resolved.projectId,
      compositionId: resolved.compositionId,
      layerId,
      commandId: commandRecord.commandId,
      motionCommandId: stringValue(motionPayload.commandId),
      operationApplied: 'motion',
      createdLayerCount: 0,
      updatedLayerCount: 1,
      targetLayerId: layerId,
      revisionBefore: currentRevision,
      revisionAfter: firstDefined(motionPayload.revisionAfter, revisionAfter),
    });
  }

  return ok('Layer updated.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId,
    commandId: commandRecord.commandId,
    operationApplied: 'update',
    createdLayerCount: 0,
    updatedLayerCount: 1,
    targetLayerId: layerId,
    revisionBefore: currentRevision,
    revisionAfter,
  });
}

async function applyVideoPipRecipe(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(
    context,
    resolved.projectId,
    resolved.compositionId,
  );
  const explicitLayerRef = firstText(
    args.layerId,
    args.layer_id,
    args.targetLayerId,
    args.clipId,
    args.clip_id,
  );
  let targetLayer: JsonMap | null = null;
  if (explicitLayerRef) {
    targetLayer = resolveTargetLayer(layers, { ...args, layerId: explicitLayerRef });
    if (!targetLayer) {
      const resolvedId = await resolveLayerIdForMutation(
        context,
        resolved.projectId,
        resolved.compositionId,
        explicitLayerRef,
      );
      if (resolvedId) {
        targetLayer = resolveTargetLayer(layers, { ...args, layerId: resolvedId });
      }
    }
  }
  if (!targetLayer && !explicitLayerRef) {
    const autoResolution = resolveTargetForEdit(layers, args, {
      preferredKinds: ['media'],
    });
    if (autoResolution.kind === 'ambiguous') {
      return fail('AMBIGUOUS_TARGET', {
        hint:
          'Multiple media layers found. Provide layerId/targetLayerId/clipId explicitly.',
        candidates: targetCandidatesPayload(autoResolution.candidates),
      });
    }
    targetLayer = autoResolution.layer;
  }
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND', {
      hint: 'No media layer found. Insert/select a video layer first.',
    });
  }

  const compositionSpec = buildCompositionSpec(
    resolved.composition,
    resolved.compositionId,
  );
  const width = Math.max(1, numberValue(compositionSpec.width, 1080));
  const height = Math.max(1, numberValue(compositionSpec.height, 1920));
  const minSide = Math.min(width, height);

  const radius = Math.max(
    8,
    numberValue(
      firstDefined(
        args.radius,
        args.circleRadius,
        args.maskRadius,
        Math.round(minSide * 0.22),
      ),
      Math.round(minSide * 0.22),
    ),
  );
  const padding = Math.max(0, numberValue(args.padding, Math.round(minSide * 0.028)));
  const durationMs = Math.max(120, numberValue(args.durationMs, 900));
  const delayMs = Math.max(0, numberValue(args.delayMs, 0));
  const popMs = Math.max(80, numberValue(args.popMs, Math.min(260, Math.round(durationMs * 0.25))));
  const settleMs = Math.min(
    durationMs,
    Math.max(popMs + 80, numberValue(args.settleMs, Math.round(durationMs * 0.68))),
  );
  const targetScale = Math.max(
    0.03,
    numberValue(firstDefined(args.targetScale, args.scale, 0.42), 0.42),
  );
  const corner = text(args.corner, 'topRight').toLowerCase();
  const startHidden = args.startHidden !== false;
  const borderWidth = Math.max(0, numberValue(args.borderWidth, 6));
  const borderColor = inferLayerColor(
    { color: firstText(args.borderColor, '#FFFFFF') },
    {},
  ) ?? '#FFFFFF';
  const glowBlur = Math.max(0, numberValue(args.glowBlur, 24));
  const glowOpacity = Math.max(
    0,
    Math.min(1, numberValue(args.glowOpacity, 0.22)),
  );
  const glowColor = inferLayerColor(
    { color: firstText(args.glowColor, borderColor) },
    {},
  ) ?? borderColor;

  let destinationAbsX = width - padding - radius;
  let destinationAbsY = padding + radius;
  if (corner === 'topleft' || corner === 'top_left' || corner === 'lefttop') {
    destinationAbsX = padding + radius;
    destinationAbsY = padding + radius;
  } else if (
    corner === 'bottomright' ||
    corner === 'bottom_right' ||
    corner === 'rightbottom'
  ) {
    destinationAbsX = width - padding - radius;
    destinationAbsY = height - padding - radius;
  } else if (
    corner === 'bottomleft' ||
    corner === 'bottom_left' ||
    corner === 'leftbottom'
  ) {
    destinationAbsX = padding + radius;
    destinationAbsY = height - padding - radius;
  }
  destinationAbsX = Math.min(width - radius, Math.max(radius, destinationAbsX));
  destinationAbsY = Math.min(height - radius, Math.max(radius, destinationAbsY));
  const destinationRelX = destinationAbsX - width / 2;
  const destinationRelY = destinationAbsY - height / 2;

  const layerId = stringValue(targetLayer.id);

  const styleResult = await applyLayerStyleMutation(
    context,
    {
      ...args,
      layerId,
      autoRebase: true,
      allowRebase: true,
    },
    'refusion.apply_video_pip_recipe.style',
    (payload) => {
      const style = readMap(payload.style);
      const nextGlow = {
        ...readMap(payload.glow),
        color: glowColor,
        blur: glowBlur,
        opacity: glowOpacity,
      };
      const nextBorder = {
        ...readMap(payload.border),
        color: borderColor,
        width: borderWidth,
      };
      const nextMask = {
        ...readMap(payload.mask),
        type: 'circle',
        radius,
        feather: Math.max(0, numberValue(args.feather, 10)),
      };
      return {
        ...payload,
        maskType: 'circle',
        cornerRadius: radius,
        clipPath: 'circle',
        renderMask: true,
        borderWidth,
        borderColor,
        glow: nextGlow,
        border: nextBorder,
        mask: nextMask,
        style: {
          ...style,
          maskType: 'circle',
          cornerRadius: radius,
          clipPath: 'circle',
          renderMask: true,
          borderWidth,
          borderColor,
          glow: nextGlow,
          border: nextBorder,
          mask: nextMask,
        },
      };
    },
  );
  if (!styleResult.ok) {
    return styleResult;
  }

  const t0 = delayMs;
  const tPop = delayMs + popMs;
  const tSettle = delayMs + settleMs;
  const tEnd = delayMs + durationMs;
  const popScale = Math.max(targetScale * 1.12, targetScale + 0.08);

  const channels: JsonMap[] = [
    {
      propertyId: 'transform.position.x',
      keyframes: [
        makeScalarKeyframe(t0, 0),
        makeScalarKeyframe(tPop, 0, 'easeOut'),
        makeScalarKeyframe(tSettle, destinationRelX * 0.92, 'easeInOut'),
        makeScalarKeyframe(tEnd, destinationRelX, 'easeInOut'),
      ],
    },
    {
      propertyId: 'transform.position.y',
      keyframes: [
        makeScalarKeyframe(t0, 0),
        makeScalarKeyframe(tPop, 0, 'easeOut'),
        makeScalarKeyframe(tSettle, destinationRelY * 0.92, 'easeInOut'),
        makeScalarKeyframe(tEnd, destinationRelY, 'easeInOut'),
      ],
    },
    {
      propertyId: 'transform.scale.x',
      keyframes: [
        makeScalarKeyframe(t0, startHidden ? 0.02 : 1.0),
        makeScalarKeyframe(tPop, popScale, 'spring'),
        makeScalarKeyframe(tSettle, targetScale * 0.96, 'easeInOut'),
        makeScalarKeyframe(tEnd, targetScale, 'easeInOut'),
      ],
    },
    {
      propertyId: 'transform.scale.y',
      keyframes: [
        makeScalarKeyframe(t0, startHidden ? 0.02 : 1.0),
        makeScalarKeyframe(tPop, popScale, 'spring'),
        makeScalarKeyframe(tSettle, targetScale * 0.96, 'easeInOut'),
        makeScalarKeyframe(tEnd, targetScale, 'easeInOut'),
      ],
    },
    {
      propertyId: 'visual.opacity',
      keyframes: [
        makeScalarKeyframe(t0, startHidden ? 0 : 1),
        makeScalarKeyframe(delayMs + Math.max(80, Math.round(popMs * 0.6)), 1, 'easeOut'),
        makeScalarKeyframe(tEnd, 1, 'linear'),
      ],
    },
  ];

  const motionResult = await applyMotionPatch(context, {
    ...args,
    layerId,
    channels,
    operation: 'apply_video_pip_recipe',
    autoRebase: true,
    allowRebase: true,
  });
  if (!motionResult.ok) {
    return motionResult;
  }

  const stylePayload = readMap(styleResult.payload);
  const motionPayload = readMap(motionResult.payload);
  return ok('Video PIP recipe applied.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId,
    styleCommandId: stringValue(stylePayload.commandId),
    motionCommandId: stringValue(motionPayload.commandId),
    revisionBefore: firstDefined(
      stylePayload.revisionBefore,
      motionPayload.revisionBefore,
      resolved.revision,
    ),
    revisionAfter: firstDefined(
      motionPayload.revisionAfter,
      stylePayload.revisionAfter,
      resolved.revision,
    ),
    recipe: {
      corner,
      radius,
      padding,
      durationMs,
      delayMs,
      destinationAbsolute: {
        x: destinationAbsX,
        y: destinationAbsY,
      },
      destinationRelative: {
        x: destinationRelX,
        y: destinationRelY,
      },
      targetScale,
      border: {
        width: borderWidth,
        color: borderColor,
      },
      glow: {
        blur: glowBlur,
        opacity: glowOpacity,
        color: glowColor,
      },
    },
  });
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
  let layerId = rawLayerId.startsWith('clip:') ? rawLayerId.slice(5) : rawLayerId;
  if (!layerId) {
    const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
    const inferredKind = inferLayerKind(args, canonicalLayerPayload(args));
    const targetResolution = resolveTargetForEdit(layers, args, {
      preferredKinds: inferredKind.trim().length > 0 ? [inferredKind] : [],
      playheadMs: optionalNumber(firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs)),
    });
    if (targetResolution.kind === 'ambiguous') {
      return fail('AMBIGUOUS_TARGET', {
        hint: 'Multiple candidate layers match this trim request. Provide layerId/targetLayerId.',
        candidates: targetCandidatesPayload(targetResolution.candidates),
      });
    }
    if (!targetResolution.layer) {
      return fail('TARGET_NOT_FOUND', {
        hint: 'No layer resolved for trim request.',
      });
    }
    layerId = stringValue(targetResolution.layer.id);
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
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
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
  let layerId = rawLayerId.startsWith('clip:') ? rawLayerId.slice(5) : rawLayerId;
  if (!layerId) {
    const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
    const inferredKind = inferLayerKind(args, canonicalLayerPayload(args));
    const targetResolution = resolveTargetForEdit(layers, args, {
      preferredKinds: inferredKind.trim().length > 0 ? [inferredKind] : [],
      playheadMs: optionalNumber(firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs)),
    });
    if (targetResolution.kind === 'ambiguous') {
      return fail('AMBIGUOUS_TARGET', {
        hint: 'Multiple candidate layers match this style update. Provide layerId/targetLayerId.',
        candidates: targetCandidatesPayload(targetResolution.candidates),
      });
    }
    if (!targetResolution.layer) {
      return fail('TARGET_NOT_FOUND', {
        hint: 'No layer resolved for style update.',
      });
    }
    layerId = stringValue(targetResolution.layer.id);
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
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
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
  if (
    expectedRevision != null &&
    expectedRevision !== currentRevision &&
    !allowRevisionRebase(args)
  ) {
    return fail('REVISION_CONFLICT', {
      expectedRevision,
      actualRevision: currentRevision,
      rebaseAllowed: true,
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
    operationApplied: 'update',
    createdLayerCount: 0,
    updatedLayerCount: 1,
    targetLayerId: layerId,
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
  const requestedLayerIds = readStringList(
    firstDefined(args.layerIds, args.layer_ids, args.targetLayerIds, args.target_layer_ids),
  );
  let query = admin
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
  if (requestedLayerIds.length > 0) {
    query = query.in('id', requestedLayerIds);
  }
  const { data, error } = await query;
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
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide layerId, targetLayerId, or clipId. Multiple candidates match.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
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
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide explicit layerId/targetLayerId. Multiple candidate layers exist.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
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

async function alignTo(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide explicit layerId/targetLayerId. Multiple candidate layers exist.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
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
  const targetRect = resolveAlignmentTargetRect({
    args,
    layers,
    compositionWidth,
    compositionHeight,
    safeZones,
  });
  if (!targetRect) {
    return fail('ALIGN_TARGET_NOT_FOUND');
  }

  const alignTokens = parseAlignmentTokens(args);
  const nextCenterAbs = {
    x: (targetRect.left + targetRect.right) / 2,
    y: (targetRect.top + targetRect.bottom) / 2,
  };
  let nextWidth = geometry.worldBounds.width;
  let nextHeight = geometry.worldBounds.height;
  let scaleX = geometry.worldBounds.scaleX;
  let scaleY = geometry.worldBounds.scaleY;
  const keepAspect = firstDefined(args.keepAspect, args.keep_aspect, true) !== false;
  const baseWidth = Math.max(1, geometry.intrinsicSize.width);
  const baseHeight = Math.max(1, geometry.intrinsicSize.height);
  const targetWidth = Math.max(1, targetRect.right - targetRect.left);
  const targetHeight = Math.max(1, targetRect.bottom - targetRect.top);

  if (alignTokens.includes('matchSize')) {
    scaleX = targetWidth / baseWidth;
    scaleY = targetHeight / baseHeight;
    nextWidth = targetWidth;
    nextHeight = targetHeight;
  } else if (alignTokens.includes('matchAspect')) {
    const axisScale = keepAspect
      ? Math.min(targetWidth / baseWidth, targetHeight / baseHeight)
      : targetWidth / baseWidth;
    scaleX = axisScale;
    scaleY = keepAspect ? axisScale : targetHeight / baseHeight;
    nextWidth = baseWidth * Math.abs(scaleX);
    nextHeight = baseHeight * Math.abs(scaleY);
  }

  if (alignTokens.includes('horizontalLeft')) {
    nextCenterAbs.x = targetRect.left + nextWidth / 2;
  } else if (alignTokens.includes('horizontalRight')) {
    nextCenterAbs.x = targetRect.right - nextWidth / 2;
  } else if (alignTokens.includes('horizontalCenter')) {
    nextCenterAbs.x = (targetRect.left + targetRect.right) / 2;
  }

  if (alignTokens.includes('verticalTop')) {
    nextCenterAbs.y = targetRect.top + nextHeight / 2;
  } else if (alignTokens.includes('verticalBottom')) {
    nextCenterAbs.y = targetRect.bottom - nextHeight / 2;
  } else if (alignTokens.includes('verticalCenter')) {
    nextCenterAbs.y = (targetRect.top + targetRect.bottom) / 2;
  }

  const keepInCanvas = firstDefined(args.keepInCanvas, args.keep_in_canvas, true) !== false;
  const clampedAbs = keepInCanvas
    ? clampCenterIntoCanvas(
      nextCenterAbs,
      compositionWidth,
      compositionHeight,
      nextWidth,
      nextHeight,
    )
    : nextCenterAbs;
  const canonicalX = clampedAbs.x - compositionWidth / 2;
  const canonicalY = clampedAbs.y - compositionHeight / 2;
  const timeMs = numberValue(
    firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs, 0),
    0,
  );
  const transformResult = await setElementTransform(context, {
    ...args,
    layerId: stringValue(targetLayer.id),
    x: canonicalX,
    y: canonicalY,
    scaleX,
    scaleY,
    timeMs,
  });
  if (!transformResult.ok) {
    return transformResult;
  }

  return ok('Alignment applied.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId: stringValue(targetLayer.id),
    alignments: alignTokens,
    targetRect,
    keepInCanvas,
    timeMs,
    resolvedCenterAbsolute: clampedAbs,
    resolvedCenterCanonical: {
      x: canonicalX,
      y: canonicalY,
    },
    appliedScale: {
      scaleX,
      scaleY,
    },
    result: transformResult.payload,
  });
}

async function fitInZone(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide explicit layerId/targetLayerId. Multiple candidate layers exist.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND');
  }
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const compositionWidth = Math.max(1, numberValue(spec.width, 1080));
  const compositionHeight = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(compositionWidth, compositionHeight);
  const geometry = computeLayerGeometry(targetLayer, compositionWidth, compositionHeight, safeZones);
  const zoneRect = resolveZoneRectFromArgs({
    args,
    compositionWidth,
    compositionHeight,
    safeZones,
  });
  if (!zoneRect) {
    return fail('ZONE_NOT_FOUND');
  }
  const mode = normalizeFitMode(firstText(args.mode, args.fitMode, args.fit, 'fit'));
  const baseWidth = Math.max(1, geometry.intrinsicSize.width);
  const baseHeight = Math.max(1, geometry.intrinsicSize.height);
  const zoneWidth = Math.max(1, zoneRect.right - zoneRect.left);
  const zoneHeight = Math.max(1, zoneRect.bottom - zoneRect.top);
  let scaleX = geometry.worldBounds.scaleX;
  let scaleY = geometry.worldBounds.scaleY;

  if (mode === 'fit' || mode === 'contain') {
    const axisScale = Math.min(zoneWidth / baseWidth, zoneHeight / baseHeight);
    scaleX = axisScale;
    scaleY = axisScale;
  } else if (mode === 'fill' || mode === 'cover') {
    const axisScale = Math.max(zoneWidth / baseWidth, zoneHeight / baseHeight);
    scaleX = axisScale;
    scaleY = axisScale;
  } else if (mode === 'stretch') {
    scaleX = zoneWidth / baseWidth;
    scaleY = zoneHeight / baseHeight;
  }

  const nextWidth = Math.max(1, baseWidth * Math.abs(scaleX));
  const nextHeight = Math.max(1, baseHeight * Math.abs(scaleY));
  const centerAbs = {
    x: (zoneRect.left + zoneRect.right) / 2,
    y: (zoneRect.top + zoneRect.bottom) / 2,
  };
  const keepInCanvas = firstDefined(args.keepInCanvas, args.keep_in_canvas, true) !== false;
  const clampedAbs = keepInCanvas
    ? clampCenterIntoCanvas(
      centerAbs,
      compositionWidth,
      compositionHeight,
      nextWidth,
      nextHeight,
    )
    : centerAbs;
  const canonicalX = clampedAbs.x - compositionWidth / 2;
  const canonicalY = clampedAbs.y - compositionHeight / 2;
  const timeMs = numberValue(
    firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs, 0),
    0,
  );
  const transformResult = await setElementTransform(context, {
    ...args,
    layerId: stringValue(targetLayer.id),
    x: canonicalX,
    y: canonicalY,
    scaleX,
    scaleY,
    timeMs,
  });
  if (!transformResult.ok) {
    return transformResult;
  }

  return ok('Fit in zone applied.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId: stringValue(targetLayer.id),
    mode,
    zoneRect,
    timeMs,
    resolvedCenterCanonical: { x: canonicalX, y: canonicalY },
    appliedScale: { scaleX, scaleY },
    result: transformResult.payload,
  });
}

async function scaleTo(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide explicit layerId/targetLayerId. Multiple candidate layers exist.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND');
  }
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const compositionWidth = Math.max(1, numberValue(spec.width, 1080));
  const compositionHeight = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(compositionWidth, compositionHeight);
  const geometry = computeLayerGeometry(targetLayer, compositionWidth, compositionHeight, safeZones);
  const baseWidth = Math.max(1, geometry.intrinsicSize.width);
  const baseHeight = Math.max(1, geometry.intrinsicSize.height);
  const mode = firstText(args.mode, args.scaleMode, args.scale_mode, 'exact').toLowerCase();

  let scaleX = geometry.worldBounds.scaleX;
  let scaleY = geometry.worldBounds.scaleY;
  if (mode === 'exact') {
    const exact = numberValue(firstDefined(args.value, args.scale, args.scaleX, 1), 1);
    scaleX = exact;
    scaleY = numberOrNull(firstDefined(args.scaleY, args.valueY, exact)) ?? exact;
  } else if (mode === 'percent') {
    const percent = numberValue(firstDefined(args.value, args.percent, 100), 100) / 100;
    scaleX = percent;
    scaleY = percent;
  } else {
    const zoneRect = resolveZoneRectFromArgs({
      args,
      compositionWidth,
      compositionHeight,
      safeZones,
    }) ?? { left: 0, top: 0, right: compositionWidth, bottom: compositionHeight };
    const zoneWidth = Math.max(1, zoneRect.right - zoneRect.left);
    const zoneHeight = Math.max(1, zoneRect.bottom - zoneRect.top);
    if (mode === 'fitwidth') {
      const axis = zoneWidth / baseWidth;
      scaleX = axis;
      scaleY = axis;
    } else if (mode === 'fitheight') {
      const axis = zoneHeight / baseHeight;
      scaleX = axis;
      scaleY = axis;
    } else if (mode === 'contain') {
      const axis = Math.min(zoneWidth / baseWidth, zoneHeight / baseHeight);
      scaleX = axis;
      scaleY = axis;
    } else if (mode === 'cover' || mode === 'fill') {
      const axis = Math.max(zoneWidth / baseWidth, zoneHeight / baseHeight);
      scaleX = axis;
      scaleY = axis;
    } else if (mode === 'stretch') {
      scaleX = zoneWidth / baseWidth;
      scaleY = zoneHeight / baseHeight;
    }
  }

  const timeMs = numberValue(
    firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs, 0),
    0,
  );
  const transformResult = await setElementTransform(context, {
    ...args,
    layerId: stringValue(targetLayer.id),
    scaleX,
    scaleY,
    timeMs,
  });
  if (!transformResult.ok) {
    return transformResult;
  }
  return ok('Scale applied.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId: stringValue(targetLayer.id),
    mode,
    scaleX,
    scaleY,
    timeMs,
    result: transformResult.payload,
  });
}

async function centerIn(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  return await alignTo(context, {
    ...args,
    alignment: ['horizontalCenter', 'verticalCenter'],
  });
}

async function previewLayoutChange(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const targetResolution = resolveTargetForEdit(layers, args);
  if (targetResolution.kind === 'ambiguous') {
    return fail('AMBIGUOUS_TARGET', {
      hint: 'Provide explicit layerId/targetLayerId. Multiple candidate layers exist.',
      candidates: targetCandidatesPayload(targetResolution.candidates),
    });
  }
  const targetLayer = targetResolution.layer;
  if (!targetLayer) {
    return fail('LAYER_NOT_FOUND');
  }
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const compositionWidth = Math.max(1, numberValue(spec.width, 1080));
  const compositionHeight = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(compositionWidth, compositionHeight);
  const before = computeLayerGeometry(targetLayer, compositionWidth, compositionHeight, safeZones);
  const payload = readMap(targetLayer.payload);
  const patchedLayer: JsonMap = {
    ...targetLayer,
    payload: {
      ...payload,
      ...readMap(firstDefined(args.proposed, args.patch, args.transformPatch, {})),
      ...(optionalNumber(args.x) != null ? { x: optionalNumber(args.x) } : {}),
      ...(optionalNumber(args.y) != null ? { y: optionalNumber(args.y) } : {}),
      ...(numberOrNull(firstDefined(args.scaleX, args.scale)) != null
        ? { scaleX: numberOrNull(firstDefined(args.scaleX, args.scale)) }
        : {}),
      ...(numberOrNull(firstDefined(args.scaleY, args.scale)) != null
        ? { scaleY: numberOrNull(firstDefined(args.scaleY, args.scale)) }
        : {}),
    },
  };
  const after = computeLayerGeometry(patchedLayer, compositionWidth, compositionHeight, safeZones);
  const overlaps = computeOverlapsForLayer(
    patchedLayer,
    layers.filter((entry) => stringValue(entry.id) !== stringValue(targetLayer.id)),
    compositionWidth,
    compositionHeight,
    safeZones,
  );
  return ok('Layout preview generated.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    layerId: stringValue(targetLayer.id),
    before: {
      worldBounds: before.worldBounds,
      visibleBounds: before.visibleBounds,
    },
    after: {
      worldBounds: after.worldBounds,
      visibleBounds: after.visibleBounds,
    },
    overlapCount: overlaps.length,
    safeAreaCompliance: {
      before: {
        titleSafe: rectContainsRect(safeZones.titleSafe, before.visibleBoundsAbsolute),
        actionSafe: rectContainsRect(safeZones.actionSafe, before.visibleBoundsAbsolute),
      },
      after: {
        titleSafe: rectContainsRect(safeZones.titleSafe, after.visibleBoundsAbsolute),
        actionSafe: rectContainsRect(safeZones.actionSafe, after.visibleBoundsAbsolute),
      },
    },
  });
}

async function validateLayoutIntent(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const summary = await getVisualLayoutSummary(context, args);
  if (!summary.ok) {
    return summary;
  }
  const payload = readMap(summary.payload);
  const issues = readList(payload.issues).map(readMap);
  const warnings = issues.filter((entry) => text(entry.severity, 'info') !== 'info');
  return ok('Layout intent validated.', {
    projectId: payload.projectId,
    compositionId: payload.compositionId,
    valid: warnings.length === 0,
    issueCount: issues.length,
    blockers: warnings,
    suggestions: payload.suggestions,
    summary: payload.summary,
  });
}

async function detectLayoutOverlaps(
  context: RequestContext,
  args: JsonMap,
): Promise<ToolResult> {
  const resolved = await resolveProjectScope(context, args);
  if (!resolved) {
    return fail('PROJECT_NOT_OPEN');
  }
  const layers = await loadLayersForScope(context, resolved.projectId, resolved.compositionId);
  const spec = buildCompositionSpec(resolved.composition, resolved.compositionId);
  const compositionWidth = Math.max(1, numberValue(spec.width, 1080));
  const compositionHeight = Math.max(1, numberValue(spec.height, 1920));
  const safeZones = buildSafeZones(compositionWidth, compositionHeight);
  const timeMs = numberValue(
    firstDefined(args.timeMs, args.time, readMap(resolved.active.timeline).playheadMs, 0),
    0,
  );
  const visible = layers.filter((layer) => {
    const startMs = numberValue(layer.start_ms, 0);
    const durationMs = Math.max(1, numberValue(layer.duration_ms, 1));
    return timeMs >= startMs && timeMs < (startMs + durationMs);
  });
  const overlaps: JsonMap[] = [];
  for (let i = 0; i < visible.length; i += 1) {
    const a = visible[i];
    const ga = computeLayerGeometry(a, compositionWidth, compositionHeight, safeZones);
    for (let j = i + 1; j < visible.length; j += 1) {
      const b = visible[j];
      const gb = computeLayerGeometry(b, compositionWidth, compositionHeight, safeZones);
      const intersection = rectIntersection(ga.visibleBoundsAbsolute, gb.visibleBoundsAbsolute);
      if (intersection && intersection.area > 0) {
        overlaps.push({
          layerA: stringValue(a.id),
          layerB: stringValue(b.id),
          intersection,
        });
      }
    }
  }
  return ok('Overlap diagnostics loaded.', {
    projectId: resolved.projectId,
    compositionId: resolved.compositionId,
    timeMs,
    overlapCount: overlaps.length,
    overlaps,
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
  const requestedLayerIds = readStringList(
    firstDefined(args.layerIds, args.layer_ids, args.targetLayerIds, args.target_layer_ids),
  );
  let query = admin
    .from('refusion_motion_channels')
    .select('id, layer_id, property_id, keyframes, motion_recipe, updated_at')
    .eq('owner_id', context.userId)
    .eq('project_id', projectId)
    .eq('composition_id', compositionId)
    .order('updated_at', { ascending: true });
  if (requestedLayerIds.length > 0) {
    query = query.in('layer_id', requestedLayerIds);
  }
  const { data, error } = await query;
  if (error) {
    const message = text((error as JsonMap).message, '');
    if (message.includes('refusion_motion_channels')) {
      return ok('Motion channels table is not ready.', {
        projectId,
        compositionId,
        channels: [],
        warning: 'MOTION_CHANNEL_STORAGE_MISSING',
      });
    }
    throw error;
  }
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

async function resolveLayerIdForMutation(
  context: RequestContext,
  projectId: string,
  compositionId: string,
  requestedLayerId: string,
): Promise<string | null> {
  const trimmed = requestedLayerId.trim();
  if (!trimmed) {
    return null;
  }
  const candidateIds = new Set<string>([
    trimmed,
    trimmed.startsWith('clip:') ? trimmed.slice(5) : trimmed,
  ]);
  for (const candidate of candidateIds) {
    if (!candidate) continue;
    const { data: directLayer, error: directError } = await admin
      .from('refusion_layers')
      .select('id')
      .eq('owner_id', context.userId)
      .eq('project_id', projectId)
      .eq('composition_id', compositionId)
      .eq('id', candidate)
      .maybeSingle();
    if (directError) throw directError;
    if (directLayer?.id) {
      return stringValue(directLayer.id);
    }
  }

  const rows = await loadLayersForScope(context, projectId, compositionId);
  for (const row of rows) {
    const rowId = stringValue(row.id);
    if (!rowId) continue;
    const payload = readMap(row.payload);
    const localLayerId = firstText(payload.localLayerId, payload.local_layer_id);
    const clipId = firstText(payload.clipId, payload.clip_id);
    for (const candidate of candidateIds) {
      if (!candidate) continue;
      if (localLayerId && (localLayerId === candidate || `clip:${localLayerId}` === candidate)) {
        return rowId;
      }
      if (clipId && (clipId === candidate || `clip:${clipId}` === candidate)) {
        return rowId;
      }
    }
  }
  return null;
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

type TargetResolution = {
  kind: 'ok' | 'not_found' | 'ambiguous';
  layer: JsonMap | null;
  candidates: JsonMap[];
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

function hasExplicitTargetReference(args: JsonMap): boolean {
  const reference = firstText(
    args.layerId,
    args.layer_id,
    args.targetLayerId,
    args.surfaceId,
    args.clipId,
    args.clip_id,
  ).trim();
  return reference.length > 0;
}

function extractLayerText(layer: JsonMap): string {
  const payload = readMap(layer.payload);
  return firstText(
    layer.text,
    layer.content,
    payload.text,
    payload.content,
    payload.value,
  ).trim();
}

function isLayerVisibleAtPlayhead(layer: JsonMap, playheadMs: number): boolean {
  const startMs = numberValue(layer.start_ms, 0);
  const durationMs = Math.max(1, numberValue(layer.duration_ms, 1));
  return playheadMs >= startMs && playheadMs < (startMs + durationMs);
}

function targetCandidatesPayload(candidates: JsonMap[]): JsonMap[] {
  return candidates.map((layer) => {
    const payload = readMap(layer.payload);
    return {
      layerId: stringValue(layer.id),
      name: text(layer.name, 'Layer'),
      kind: text(layer.layer_kind, 'solid'),
      mediaKind: text(payload.mediaKind, ''),
      text: extractLayerText(layer),
      zIndex: numberValue(layer.z_index, 0),
      startMs: numberValue(layer.start_ms, 0),
      durationMs: Math.max(1, numberValue(layer.duration_ms, 1)),
    };
  });
}

function resolveTargetForEdit(
  layers: JsonMap[],
  args: JsonMap,
  options: {
    preferredKinds?: string[];
    playheadMs?: number | null;
    selectedLayerIds?: string[];
    targetText?: string;
    latestLayerId?: string | null;
  } = {},
): TargetResolution {
  const explicit = hasExplicitTargetReference(args);
  if (explicit) {
    const layer = resolveTargetLayer(layers, args);
    return {
      kind: layer ? 'ok' : 'not_found',
      layer,
      candidates: [],
    };
  }
  if (layers.length === 0) {
    return {
      kind: 'not_found',
      layer: null,
      candidates: [],
    };
  }
  const preferredKinds = (options.preferredKinds ?? [])
    .map((entry) => entry.trim().toLowerCase())
    .filter((entry) => entry.length > 0);
  let candidates = [...layers];
  if (preferredKinds.length > 0) {
    const filtered = candidates.filter((layer) =>
      preferredKinds.includes(text(layer.layer_kind, '').toLowerCase())
    );
    if (filtered.length > 0) {
      candidates = filtered;
    }
  }
  const selectedLayerIds = [
    ...new Set(
      [
        ...(options.selectedLayerIds ?? []),
        ...readStringList(firstDefined(args.selectedLayerIds, args.selected_layer_ids)),
      ]
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0),
    ),
  ];
  if (selectedLayerIds.length > 0) {
    const selected = candidates.filter((layer) =>
      selectedLayerIds.includes(stringValue(layer.id))
    );
    if (selected.length > 0) {
      candidates = selected;
    }
  }
  const targetText = (options.targetText ?? firstText(
    args.targetText,
    args.target_text,
    args.matchText,
    args.match_text,
    args.text,
    args.content,
  )).trim();
  if (targetText.length > 0) {
    const textMatches = candidates.filter((layer) =>
      extractLayerText(layer).trim().toLowerCase() === targetText.toLowerCase()
    );
    if (textMatches.length > 0) {
      candidates = textMatches;
    }
  }
  const playheadMs = options.playheadMs ??
    optionalNumber(firstDefined(args.timeMs, args.time, args.playheadMs, args.timelinePlayheadMs));
  if (playheadMs != null) {
    const visible = candidates.filter((layer) => isLayerVisibleAtPlayhead(layer, playheadMs));
    if (visible.length > 0) {
      candidates = visible;
    }
  }
  const latestLayerId = (options.latestLayerId ?? firstText(
    args.latestLayerId,
    args.latest_layer_id,
    args.lastLayerId,
    args.last_layer_id,
  )).trim();
  if (latestLayerId.length > 0) {
    const latest = candidates.filter((layer) => stringValue(layer.id) === latestLayerId);
    if (latest.length == 1) {
      return {
        kind: 'ok',
        layer: latest[0],
        candidates: latest,
      };
    }
  }
  const ordered = [...candidates].sort((a, b) =>
    numberValue(b.z_index, 0) - numberValue(a.z_index, 0)
  );
  if (ordered.length === 1) {
    return {
      kind: 'ok',
      layer: ordered[0],
      candidates: ordered,
    };
  }
  return {
    kind: 'ambiguous',
    layer: null,
    candidates: ordered,
  };
}

function resolvePreferredMediaLayer(layers: JsonMap[]): JsonMap | null {
  if (layers.length === 0) {
    return null;
  }
  const mediaLayers = layers.filter((layer) => text(layer.layer_kind, '') === 'media');
  if (mediaLayers.length === 0) {
    return null;
  }
  const sorted = [...mediaLayers].sort((a, b) =>
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

type AlignToken =
  | 'horizontalLeft'
  | 'horizontalCenter'
  | 'horizontalRight'
  | 'verticalTop'
  | 'verticalCenter'
  | 'verticalBottom'
  | 'matchSize'
  | 'matchAspect';

function parseAlignmentTokens(args: JsonMap): AlignToken[] {
  const raw = firstDefined(args.alignment, args.alignments, args.align);
  const tokens = new Set<AlignToken>();
  const pushToken = (value: string) => {
    const normalized = value.trim().toLowerCase();
    const map: Record<string, AlignToken> = {
      left: 'horizontalLeft',
      horizontalleft: 'horizontalLeft',
      hleft: 'horizontalLeft',
      centerx: 'horizontalCenter',
      horizontalcenter: 'horizontalCenter',
      hcenter: 'horizontalCenter',
      right: 'horizontalRight',
      horizontalright: 'horizontalRight',
      hright: 'horizontalRight',
      top: 'verticalTop',
      verticaltop: 'verticalTop',
      vtop: 'verticalTop',
      centery: 'verticalCenter',
      verticalcenter: 'verticalCenter',
      vcenter: 'verticalCenter',
      bottom: 'verticalBottom',
      verticalbottom: 'verticalBottom',
      vbottom: 'verticalBottom',
      matchsize: 'matchSize',
      matchaspect: 'matchAspect',
    };
    const token = map[normalized];
    if (token) {
      tokens.add(token);
    }
  };
  if (Array.isArray(raw)) {
    for (const item of raw) {
      if (typeof item === 'string') {
        pushToken(item);
      }
    }
  } else if (typeof raw === 'string') {
    for (const part of raw.split(/[,\s]+/)) {
      if (part.trim() !== '') {
        pushToken(part);
      }
    }
  }
  if (tokens.size === 0) {
    tokens.add('horizontalCenter');
    tokens.add('verticalCenter');
  }
  return [...tokens];
}

function resolveAlignmentTargetRect(input: {
  args: JsonMap;
  layers: JsonMap[];
  compositionWidth: number;
  compositionHeight: number;
  safeZones: { titleSafe: Rect; actionSafe: Rect };
}): Rect | null {
  const target = firstText(input.args.target, input.args.alignTo, 'canvas').trim();
  const lower = target.toLowerCase();
  if (
    lower === 'canvas' ||
    lower === 'composition' ||
    lower === 'fullcanvas' ||
    lower === 'full'
  ) {
    return {
      left: 0,
      top: 0,
      right: input.compositionWidth,
      bottom: input.compositionHeight,
    };
  }
  if (lower === 'titlesafe' || lower === 'title') {
    return input.safeZones.titleSafe;
  }
  if (lower === 'actionsafe' || lower === 'action') {
    return input.safeZones.actionSafe;
  }
  if (lower.startsWith('anchor:')) {
    const anchor = normalizeAnchorName(target.split(':').slice(1).join(':'));
    const point = anchorTargetCenter({
      anchor,
      safeArea: 'none',
      safeZones: input.safeZones,
      width: input.compositionWidth,
      height: input.compositionHeight,
      elementWidth: 0,
      elementHeight: 0,
      paddingPx: 0,
    });
    return { left: point.x, top: point.y, right: point.x, bottom: point.y };
  }
  const layerId = lower.startsWith('layer:') ? target.split(':').slice(1).join(':') : target;
  const matched = input.layers.find((entry) => stringValue(entry.id) === layerId);
  if (!matched) {
    return null;
  }
  const geometry = computeLayerGeometry(
    matched,
    input.compositionWidth,
    input.compositionHeight,
    input.safeZones,
  );
  return geometry.visibleBoundsAbsolute;
}

function normalizeZoneName(value: string): string {
  const normalized = value.trim().toLowerCase();
  const map: Record<string, string> = {
    full: 'fullCanvas',
    fullcanvas: 'fullCanvas',
    canvas: 'fullCanvas',
    titlesafe: 'titleSafe',
    title: 'titleSafe',
    actionsafe: 'actionSafe',
    action: 'actionSafe',
    upperthird: 'upperThird',
    middlethird: 'middleThird',
    lowerthird: 'lowerThird',
    lefthalf: 'leftHalf',
    righthalf: 'rightHalf',
  };
  return map[normalized] ?? 'actionSafe';
}

function resolveZoneRectFromArgs(input: {
  args: JsonMap;
  compositionWidth: number;
  compositionHeight: number;
  safeZones: { titleSafe: Rect; actionSafe: Rect };
}): Rect | null {
  const zoneName = normalizeZoneName(firstText(input.args.zone, input.args.targetZone, 'actionSafe'));
  const full: Rect = {
    left: 0,
    top: 0,
    right: input.compositionWidth,
    bottom: input.compositionHeight,
  };
  if (zoneName === 'fullCanvas') {
    return full;
  }
  if (zoneName === 'titleSafe') {
    return input.safeZones.titleSafe;
  }
  if (zoneName === 'actionSafe') {
    return input.safeZones.actionSafe;
  }
  if (zoneName === 'upperThird') {
    return {
      left: 0,
      top: 0,
      right: input.compositionWidth,
      bottom: input.compositionHeight / 3,
    };
  }
  if (zoneName === 'middleThird') {
    return {
      left: 0,
      top: input.compositionHeight / 3,
      right: input.compositionWidth,
      bottom: (input.compositionHeight * 2) / 3,
    };
  }
  if (zoneName === 'lowerThird') {
    return {
      left: 0,
      top: (input.compositionHeight * 2) / 3,
      right: input.compositionWidth,
      bottom: input.compositionHeight,
    };
  }
  if (zoneName === 'leftHalf') {
    return {
      left: 0,
      top: 0,
      right: input.compositionWidth / 2,
      bottom: input.compositionHeight,
    };
  }
  if (zoneName === 'rightHalf') {
    return {
      left: input.compositionWidth / 2,
      top: 0,
      right: input.compositionWidth,
      bottom: input.compositionHeight,
    };
  }

  const rect = readMap(firstDefined(input.args.rect, input.args.zoneRect, {}));
  if (Object.keys(rect).length > 0) {
    const x = numberValue(firstDefined(rect.x, rect.left, 0), 0);
    const y = numberValue(firstDefined(rect.y, rect.top, 0), 0);
    const w = Math.max(1, numberValue(firstDefined(rect.w, rect.width, 1), 1));
    const h = Math.max(1, numberValue(firstDefined(rect.h, rect.height, 1), 1));
    return {
      left: x,
      top: y,
      right: x + w,
      bottom: y + h,
    };
  }
  return null;
}

function normalizeFitMode(value: string): 'fit' | 'contain' | 'fill' | 'cover' | 'stretch' {
  const normalized = value.trim().toLowerCase();
  if (normalized === 'contain') return 'contain';
  if (normalized === 'fill') return 'fill';
  if (normalized === 'cover') return 'cover';
  if (normalized === 'stretch') return 'stretch';
  return 'fit';
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
  const strictProof = firstDefined(
    args.strictProof,
    args.requireProof,
    args.strict,
    true,
  ) !== false;
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
    const proof = readMap(result.proof);
    const proofSatisfied = isWaitForApplyProofSatisfied(result, proof);
    if (
      state === 'succeeded' ||
      state === 'failed' ||
      state === 'cancelled'
    ) {
      if (state === 'succeeded' && strictProof && (!appApplied || !proofSatisfied)) {
        return fail('APPLY_PROOF_INCOMPLETE', {
          commandId,
          status: state,
          appApplied: false,
          strictProof: true,
          payload,
          proof,
        });
      }
      return ok('Apply status resolved.', {
        commandId,
        status: state,
        appApplied: state === 'succeeded'
          ? (strictProof ? appApplied && proofSatisfied : appApplied)
          : false,
        strictProof,
        proofSatisfied,
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

function isWaitForApplyProofSatisfied(
  result: JsonMap,
  proof: JsonMap,
): boolean {
  const dataApplied = firstDefined(proof.dataApplied, result.dataApplied, false) === true;
  const localGraphApplied = firstDefined(
    proof.localGraphApplied,
    result.localGraphApplied,
    false,
  ) === true;
  const timelineVisible = firstDefined(
    proof.timelineVisible,
    result.timelineVisible,
    false,
  ) === true;
  const frameEvaluated = firstDefined(
    proof.frameEvaluated,
    result.frameEvaluated,
    false,
  ) === true;
  const visualProgramEmitted = firstDefined(
    proof.visualProgramEmitted,
    result.visualProgramEmitted,
    false,
  ) === true;
  const rendererApplied = firstDefined(
    proof.rendererApplied,
    result.rendererApplied,
    false,
  ) === true;
  const visualBoundsVerified = firstDefined(
    proof.visualBoundsVerified,
    result.visualBoundsVerified,
    false,
  ) === true;
  return (
    dataApplied &&
    localGraphApplied &&
    timelineVisible &&
    frameEvaluated &&
    visualProgramEmitted &&
    rendererApplied &&
    visualBoundsVerified
  );
}

async function normalizeCommandApplyState(
  _context: RequestContext,
  commandRow: JsonMap,
): Promise<JsonMap> {
  // Canonical apply contract: only explicit app ACK can mark command applied.
  // Never auto-promote from revision drift.
  return commandRow;
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
  const resolvedIds = await resolveOwnedProjectAndComposition(
    userId,
    asUuidOrEmpty(input.projectId) || activeProjectId,
    asUuidOrEmpty(input.compositionId) || activeCompositionId,
  );
  const projectId = resolvedIds.projectId;
  const compositionId = resolvedIds.compositionId;
  const timelineId = input.timelineId || text(activeTimeline.id, 'main');
  const playheadMs = input.playheadMs;
  const timelineRevision = input.timelineRevision > 0
    ? input.timelineRevision
    : await projectRevision(projectId);

  const nowIso = new Date().toISOString();
  const devicePayload = {
    owner_id: userId,
    device_id: deviceId,
    device_name: deviceId,
    platform: text(input.platform, 'flutter'),
    app_version: text(input.appVersion, 'refusion-app'),
    status: 'active',
    last_seen_at: nowIso,
  };
  const deviceRow = await upsertOrSelectAndUpdateSingle({
    table: 'refusion_devices',
    payload: devicePayload,
    conflictColumns: 'owner_id,device_id',
    match: {
      owner_id: userId,
      device_id: deviceId,
    },
    orderBy: 'last_seen_at',
  });

  const appSessionPayload = {
    owner_id: userId,
    device_ref: deviceRow.id,
    status: mapEditorStatus(text(input.status, 'online')),
    last_heartbeat_at: nowIso,
    started_at: nowIso,
  };
  const appSessionRow = await upsertOrSelectAndUpdateSingle({
    table: 'refusion_app_sessions',
    payload: appSessionPayload,
    conflictColumns: 'owner_id,device_ref',
    match: {
      owner_id: userId,
      device_ref: deviceRow.id as string,
    },
    orderBy: 'last_heartbeat_at',
  });

  const activeContextPayload = {
    owner_id: userId,
    device_ref: deviceRow.id,
    app_session_id: appSessionRow.id,
    project_id: projectId,
    composition_id: compositionId,
    timeline_id: timelineId,
    playhead_ms: playheadMs,
    timeline_revision: timelineRevision,
    status: 'active',
    updated_at: nowIso,
  };
  const activeContextRow = await upsertOrSelectAndUpdateSingle({
    table: 'refusion_active_contexts',
    payload: activeContextPayload,
    conflictColumns: 'owner_id,device_ref',
    match: {
      owner_id: userId,
      device_ref: deviceRow.id as string,
    },
    orderBy: 'updated_at',
  });

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

function asUuidOrEmpty(value: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    return '';
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(normalized)) {
    return '';
  }
  return normalized;
}

function isOnConflictConstraintMissing(error: unknown): boolean {
  if (!error || typeof error !== 'object') {
    return false;
  }
  const map = error as Record<string, unknown>;
  const code = typeof map.code === 'string' ? map.code : '';
  const message = typeof map.message === 'string' ? map.message : '';
  return code === '42P10' || message.includes('ON CONFLICT specification');
}

async function upsertOrSelectAndUpdateSingle(input: {
  table: string;
  payload: JsonMap;
  conflictColumns: string;
  match: Record<string, string>;
  orderBy: string;
}): Promise<JsonMap> {
  const { table, payload, conflictColumns, match, orderBy } = input;
  const attempt = await admin
    .from(table)
    .upsert(payload, { onConflict: conflictColumns })
    .select()
    .single();
  if (!attempt.error) {
    return readMap(attempt.data);
  }
  if (!isOnConflictConstraintMissing(attempt.error)) {
    throw attempt.error;
  }

  let query = admin.from(table).select('*');
  for (const [key, value] of Object.entries(match)) {
    query = query.eq(key, value);
  }
  const existing = await query
    .order(orderBy, { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existing.error) {
    throw existing.error;
  }
  if (existing.data) {
    const existingId = stringValue(readMap(existing.data).id);
    if (!existingId) {
      throw new Error(`Missing id in existing ${table} row.`);
    }
    const updated = await admin
      .from(table)
      .update(payload)
      .eq('id', existingId)
      .select()
      .single();
    if (updated.error) {
      throw updated.error;
    }
    return readMap(updated.data);
  }

  const inserted = await admin
    .from(table)
    .insert(payload)
    .select()
    .single();
  if (inserted.error) {
    throw inserted.error;
  }
  return readMap(inserted.data);
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
    status: 'pending',
    result: {
      ...payload,
      appApplied: false,
      revisionAfter,
      acceptedAt: nowIso,
      lifecycle: {
        stage: 'cloudCommitted',
        cloudCommittedAt: nowIso,
      },
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
    .maybeSingle();
  if (error) throw error;
  if (!data) {
    const project = await selectById('refusion_projects', projectId);
    const ownerId = stringValue(project?.owner_id);
    if (!ownerId) {
      throw new Error(`PROJECT_OWNER_NOT_FOUND_FOR_REVISION:${projectId}`);
    }
    const { data: inserted, error: insertError } = await admin
      .from('refusion_project_revisions')
      .insert({ project_id: projectId, owner_id: ownerId, revision: 1 })
      .select('revision')
      .single();
    if (insertError) throw insertError;
    return numberValue(inserted?.revision, 1);
  }
  return numberValue(data?.revision, 1);
}

async function resolveOwnedProjectAndComposition(
  userId: string,
  inputProjectId: string,
  inputCompositionId: string,
): Promise<{ projectId: string; compositionId: string }> {
  const requestedProjectId = asUuidOrEmpty(inputProjectId);
  const requestedCompositionId = asUuidOrEmpty(inputCompositionId);
  let projectId = requestedProjectId;
  let compositionId = requestedCompositionId;

  if (projectId) {
    const { data, error } = await admin
      .from('refusion_projects')
      .select('id, owner_id')
      .eq('id', projectId)
      .maybeSingle();
    if (error) throw error;
    if (data) {
      const projectOwnerId = stringValue(data.owner_id);
      if (projectOwnerId != userId) {
        projectId = '';
      }
    } else {
      const { error: insertProjectError } = await admin
        .from('refusion_projects')
        .insert({
          id: projectId,
          owner_id: userId,
          name: 'MCP Project',
          status: 'active',
        });
      if (insertProjectError) throw insertProjectError;
      await ensureOwnedProjectRevisionEntry(userId, projectId);
    }
  }

  if (!projectId) {
    const latestProject = await selectSingle(
      'refusion_projects',
      { owner_id: userId, status: 'active' },
      'updated_at',
      false,
    );
    projectId = stringValue(latestProject?.id);
  }

  if (!projectId) {
    const created = await createProject(userId, {
      projectName: 'MCP Project',
      compositionName: 'Story',
    });
    projectId = stringValue(created.projectId);
    compositionId = stringValue(created.compositionId);
  }

  if (!projectId) {
    throw new Error('ACTIVE_PROJECT_RESOLUTION_FAILED');
  }

  if (compositionId) {
    const { data, error } = await admin
      .from('refusion_compositions')
      .select('id, owner_id, project_id')
      .eq('id', compositionId)
      .maybeSingle();
    if (error) throw error;
    if (data) {
      const compositionOwnerId = stringValue(data.owner_id);
      if (compositionOwnerId != userId) {
        compositionId = '';
      }
      const compositionProjectId = stringValue(data.project_id);
      if (compositionOwnerId == userId && compositionProjectId != projectId) {
        compositionId = '';
      }
    } else if (requestedCompositionId) {
      const { error: insertCompositionError } = await admin
        .from('refusion_compositions')
        .insert({
          id: requestedCompositionId,
          owner_id: userId,
          project_id: projectId,
          name: 'Story',
          aspect: 'story',
          width: 1080,
          height: 1920,
          duration_ms: 8000,
          fps: 30,
          is_active: true,
        });
      if (insertCompositionError) throw insertCompositionError;
      compositionId = requestedCompositionId;
    }
  }

  if (!compositionId) {
    const latestComposition = await selectSingle(
      'refusion_compositions',
      { owner_id: userId, project_id: projectId },
      'updated_at',
      false,
    );
    compositionId = stringValue(latestComposition?.id);
  }

  if (!compositionId) {
    const { data, error } = await admin
      .from('refusion_compositions')
      .insert({
        owner_id: userId,
        project_id: projectId,
        name: 'Story',
        aspect: 'story',
        width: 1080,
        height: 1920,
        duration_ms: 8000,
        fps: 30,
        is_active: true,
      })
      .select('id')
      .single();
    if (error) throw error;
    compositionId = stringValue(data?.id);
  }

  if (!compositionId) {
    throw new Error('ACTIVE_COMPOSITION_RESOLUTION_FAILED');
  }

  return { projectId, compositionId };
}

async function ensureOwnedProjectRevisionEntry(
  ownerId: string,
  projectId: string,
) {
  const { data, error } = await admin
    .from('refusion_project_revisions')
    .select('project_id')
    .eq('project_id', projectId)
    .maybeSingle();
  if (error) throw error;
  if (data) {
    return;
  }
  const { error: insertError } = await admin
    .from('refusion_project_revisions')
    .insert({ project_id: projectId, owner_id: ownerId, revision: 1 });
  if (insertError) throw insertError;
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
      'refusion.ack_command_applied',
      'Acknowledge Command Applied',
      'Called by the open app after it applies remote changes locally; marks matching running commands appApplied=true.',
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
      'refusion.update_layer',
      'Update Layer',
      'Update an existing target layer in-place. This never inserts a new layer.',
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
      'refusion.set_text_style',
      'Set Text Style',
      'Update typography/style fields of an existing text layer without inserting a duplicate.',
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
      'refusion.apply_video_pip_recipe',
      'Apply Video PIP Recipe',
      'Apply circle mask + border + glow + pop-up motion and move video to canvas corner using deterministic composition-aware coordinates.',
      true,
    ),
    tool(
      'refusion.position_at_anchor',
      'Position At Anchor',
      'Place target layer at semantic anchors (topLeft/topRight/goldenTop/thirds) with optional safe-area and padding.',
      true,
    ),
    tool(
      'refusion.align_to',
      'Align To',
      'Align target layer to canvas/zone/anchor/another layer using semantic alignment tokens.',
      true,
    ),
    tool(
      'refusion.fit_in_zone',
      'Fit In Zone',
      'Fit target layer into a layout zone (contain/cover/fill/stretch) with optional safe area.',
      true,
    ),
    tool(
      'refusion.scale_to',
      'Scale To',
      'Scale target layer by exact/percent/fitWidth/fitHeight/contain/cover modes.',
      true,
    ),
    tool(
      'refusion.center_in',
      'Center In',
      'Center target layer in canvas/titleSafe/actionSafe/zone/layer.',
      true,
    ),
    tool(
      'refusion.layout.preview_change',
      'Layout Preview Change',
      'Simulate a proposed transform/style patch and return geometry impact without mutation.',
    ),
    tool(
      'refusion.layout.validate_intent',
      'Layout Validate Intent',
      'Validate current/proposed layout intent and return structured blockers/suggestions.',
    ),
    tool(
      'refusion.layout.detect_overlaps',
      'Layout Detect Overlaps',
      'Return overlap diagnostics for visible layers at a timeline time.',
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
      'refusion.get_pending_commands',
      'Get Pending Commands',
      'Return pending/running command bus rows for the active composition so the open app can acknowledge exact commandIds after local apply.',
      true,
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

function readStringList(value: unknown): string[] {
  const list = readList(value);
  const out: string[] = [];
  for (const item of list) {
    const normalized = stringValue(item).trim();
    if (!normalized) continue;
    out.push(normalized);
  }
  return [...new Set(out)];
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

function allowRevisionRebase(args: JsonMap): boolean {
  const candidate = firstDefined(
    args.autoRebase,
    args.allowRebase,
    args.rebaseOnConflict,
    args.revisionStrategy,
    args.onRevisionConflict,
  );
  if (typeof candidate === 'boolean') {
    return candidate;
  }
  if (typeof candidate === 'number') {
    return candidate !== 0;
  }
  if (typeof candidate === 'string') {
    const normalized = candidate.trim().toLowerCase();
    if (!normalized) {
      return true;
    }
    if (
      normalized === 'false' ||
      normalized === '0' ||
      normalized === 'strict' ||
      normalized === 'reject' ||
      normalized === 'fail'
    ) {
      return false;
    }
    return true;
  }
  return true;
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
  const x = firstDefined(args.x, out.x);
  const y = firstDefined(args.y, out.y);
  const centerX = firstDefined(args.centerX, args.cx, out.centerX, out.cx);
  const centerY = firstDefined(args.centerY, args.cy, out.centerY, out.cy);
  if (x !== undefined) out.x = x;
  if (y !== undefined) out.y = y;
  if (centerX !== undefined) out.centerX = centerX;
  if (centerY !== undefined) out.centerY = centerY;

  const coordinateSpace = firstText(
    args.coordinateSpace,
    args.coordinate_system,
    args.coordinateSystem,
    args.origin,
    out.coordinateSpace,
    out.coordinate_system,
    out.coordinateSystem,
    out.origin,
  );
  if (coordinateSpace) {
    out.coordinateSpace = coordinateSpace;
  } else if (centerX !== undefined || centerY !== undefined) {
    // Preserve absolute center semantics for MCP clients that send centerX/Y.
    out.coordinateSpace = 'absoluteTopLeft';
  }

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

function hasExplicitMotionTime(args: JsonMap): boolean {
  const payload = readMap(args.payload);
  return firstDefined(
    args.startTimeMs,
    args.startMs,
    args.atMs,
    args.timeMs,
    args.time,
    payload.startTimeMs,
    payload.startMs,
    payload.atMs,
    payload.timeMs,
    payload.time,
  ) != null;
}

function resolveMotionBaseTimeMs(activeContext: JsonMap, args: JsonMap): number {
  const timeline = readMap(activeContext.timeline);
  const activePlayhead = numberValue(firstDefined(timeline.playheadMs, 0), 0);
  const hintedPlayhead = optionalNumber(firstDefined(args.playheadMs, args.timelinePlayheadMs));
  const base = hintedPlayhead ?? activePlayhead;
  return Math.max(0, Math.round(base));
}

function shiftMotionWritesBy(
  writes: MotionChannelWrite[],
  offsetMs: number,
): MotionChannelWrite[] {
  if (offsetMs <= 0) {
    return writes;
  }
  return writes.map((write) => ({
    ...write,
    keyframes: write.keyframes.map((keyframe) => {
      const timeMs = numberValue(keyframe.timeMs, 0);
      return {
        ...keyframe,
        timeMs: Math.max(0, Math.round(timeMs + offsetMs)),
      };
    }),
  }));
}

function inferMotionWrites(args: JsonMap): MotionChannelWrite[] {
  const payload = readMap(args.payload);
  const updates = readMap(payload.updates);
  const updatePayload = readMap(updates.payload);
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
    const expanded = expandMotionRecipe(motionRecipe, numberValue(args.durationMs, 650));
    if (expanded.length > 0) {
      return expanded;
    }
  }

  const legacyMotionMaps = [
    readMap(firstDefined(args.motion, payload.motion, updates.motion, updatePayload.motion)),
    readMap(firstDefined(args.animation, payload.animation, updates.animation, updatePayload.animation)),
    readMap(readMap(payload.motion).in),
    readMap(readMap(updates.motion).in),
    readMap(readMap(updatePayload.motion).in),
    readMap(readMap(payload.animation).in),
    readMap(readMap(updates.animation).in),
    readMap(readMap(updatePayload.animation).in),
  ];
  for (const legacyMap of legacyMotionMaps) {
    if (Object.keys(legacyMap).length === 0) {
      continue;
    }
    const preset = firstText(
      legacyMap.preset,
      legacyMap.recipe,
      legacyMap.motionRecipe,
      legacyMap.animationRecipe,
      legacyMap.type,
      legacyMap.animation,
    );
    if (preset.trim().length === 0) {
      continue;
    }
    const durationMs = numberValue(
      firstDefined(
        legacyMap.durationMs,
        legacyMap.duration,
        args.durationMs,
        payload.durationMs,
      ),
      650,
    );
    const normalizedPreset = normalizeLegacyMotionRecipe(preset);
    const expanded = expandMotionRecipe(normalizedPreset, durationMs);
    if (expanded.length > 0) {
      return expanded;
    }
  }

  return [];
}

function normalizeLegacyMotionRecipe(value: string): string {
  const normalized = value.trim().toLowerCase().replace(/[^a-z0-9]+/g, '');
  if (normalized === 'popup' || normalized === 'popupspring' || normalized === 'springpopup') {
    return '$motion.scaleInBounce';
  }
  if (normalized === 'scaleinbounce') {
    return '$motion.scaleInBounce';
  }
  if (normalized === 'scalein') {
    return '$motion.scaleIn';
  }
  if (normalized === 'slideinfromleft') {
    return '$motion.slideInFromLeft';
  }
  if (normalized === 'slideinfromright') {
    return '$motion.slideInFromRight';
  }
  return value;
}

function legacyAnimationChannelsToMotionWrites(
  keyframes: unknown[],
  options: {
    canvasWidth: number;
    canvasHeight: number;
  },
): JsonMap[] {
  const scaleKeyframes: JsonMap[] = [];
  const opacityKeyframes: JsonMap[] = [];
  const positionXKeyframes: JsonMap[] = [];
  const positionYKeyframes: JsonMap[] = [];

  for (const raw of keyframes) {
    const map = readMap(raw);
    const timeMs = optionalNumber(firstDefined(map.timeMs, map.time, map.t));
    if (timeMs == null || timeMs < 0) {
      continue;
    }
    const easing = firstText(map.easing, map.interpolation, 'easeOut');

    const scale = numberOrNull(firstDefined(
      map.scale,
      map.scaleX,
      readMap(map.transform).scale,
      readMap(map.transform).scaleX,
    ));
    if (scale != null) {
      scaleKeyframes.push({
        id: firstText(map.id) || `kf_scale_${timeMs}_${scaleKeyframes.length}`,
        timeMs,
        value: scale,
        easing,
      });
    }

    const opacity = numberOrNull(firstDefined(
      map.opacity,
      readMap(map.visual).opacity,
    ));
    if (opacity != null) {
      opacityKeyframes.push({
        id: firstText(map.id) || `kf_opacity_${timeMs}_${opacityKeyframes.length}`,
        timeMs,
        value: opacity,
        easing,
      });
    }

    const absoluteX = numberOrNull(firstDefined(
      map.x,
      map.centerX,
      readMap(map.position).x,
      readMap(map.transform).x,
    ));
    if (absoluteX != null) {
      positionXKeyframes.push({
        id: firstText(map.id) || `kf_x_${timeMs}_${positionXKeyframes.length}`,
        timeMs,
        value: absoluteX - (options.canvasWidth / 2),
        easing,
      });
    }

    const absoluteY = numberOrNull(firstDefined(
      map.y,
      map.centerY,
      readMap(map.position).y,
      readMap(map.transform).y,
    ));
    if (absoluteY != null) {
      positionYKeyframes.push({
        id: firstText(map.id) || `kf_y_${timeMs}_${positionYKeyframes.length}`,
        timeMs,
        value: absoluteY - (options.canvasHeight / 2),
        easing,
      });
    }
  }

  const channels: JsonMap[] = [];
  if (scaleKeyframes.length > 0) {
    channels.push({
      propertyId: 'transform.scale.x',
      keyframes: scaleKeyframes,
    });
    channels.push({
      propertyId: 'transform.scale.y',
      keyframes: scaleKeyframes,
    });
  }
  if (opacityKeyframes.length > 0) {
    channels.push({
      propertyId: 'visual.opacity',
      keyframes: opacityKeyframes,
    });
  }
  if (positionXKeyframes.length > 0) {
    channels.push({
      propertyId: 'transform.position.x',
      keyframes: positionXKeyframes,
    });
  }
  if (positionYKeyframes.length > 0) {
    channels.push({
      propertyId: 'transform.position.y',
      keyframes: positionYKeyframes,
    });
  }
  return channels;
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
  if (normalized === '$motion.scalein' || normalized === 'scalein') {
    const keyframes: JsonMap[] = [
      makeScalarKeyframe(0, 0.65, 'easeOut'),
      makeScalarKeyframe(durationMs, 1.0, 'easeInOut'),
    ];
    return [
      {
        propertyId: 'transform.scale.x',
        keyframes,
        motionRecipe: '$motion.scaleIn',
      },
      {
        propertyId: 'transform.scale.y',
        keyframes,
        motionRecipe: '$motion.scaleIn',
      },
      {
        propertyId: 'visual.opacity',
        keyframes: [
          makeScalarKeyframe(0, 0.0, 'linear'),
          makeScalarKeyframe(Math.round(durationMs * 0.35), 1.0, 'easeOut'),
          makeScalarKeyframe(durationMs, 1.0, 'linear'),
        ],
        motionRecipe: '$motion.scaleIn',
      },
    ];
  }
  if (normalized === '$motion.slideinfromleft' || normalized === 'slideinfromleft') {
    return [
      {
        propertyId: 'transform.position.x',
        keyframes: [
          makeScalarKeyframe(0, -360, 'easeOut'),
          makeScalarKeyframe(durationMs, 0, 'easeInOut'),
        ],
        motionRecipe: '$motion.slideInFromLeft',
      },
      {
        propertyId: 'visual.opacity',
        keyframes: [
          makeScalarKeyframe(0, 0.0, 'linear'),
          makeScalarKeyframe(Math.round(durationMs * 0.24), 1.0, 'easeOut'),
          makeScalarKeyframe(durationMs, 1.0, 'linear'),
        ],
        motionRecipe: '$motion.slideInFromLeft',
      },
    ];
  }
  if (normalized === '$motion.slideinfromright' || normalized === 'slideinfromright') {
    return [
      {
        propertyId: 'transform.position.x',
        keyframes: [
          makeScalarKeyframe(0, 360, 'easeOut'),
          makeScalarKeyframe(durationMs, 0, 'easeInOut'),
        ],
        motionRecipe: '$motion.slideInFromRight',
      },
      {
        propertyId: 'visual.opacity',
        keyframes: [
          makeScalarKeyframe(0, 0.0, 'linear'),
          makeScalarKeyframe(Math.round(durationMs * 0.24), 1.0, 'easeOut'),
          makeScalarKeyframe(durationMs, 1.0, 'linear'),
        ],
        motionRecipe: '$motion.slideInFromRight',
      },
    ];
  }
  return [];
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
