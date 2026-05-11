import 'package:flutter/foundation.dart';

import '../../domain/mcp/refusion_mcp_agent_control_plane.dart';
import '../../domain/mcp/refusion_mcp_command_result.dart';
import '../../domain/mcp/refusion_mcp_prompt_provider.dart';
import '../../domain/mcp/refusion_mcp_resource_provider.dart';
import '../../domain/mcp/refusion_mcp_session.dart';
import '../../domain/mcp/refusion_mcp_session_store.dart';

@immutable
class RefusionMcpBridgeHealth {
  const RefusionMcpBridgeHealth({
    required this.ready,
    required this.sessionCount,
    required this.toolCount,
    required this.resourceCount,
  });

  final bool ready;
  final int sessionCount;
  final int toolCount;
  final int resourceCount;
}

class RefusionMcpAppBridge {
  RefusionMcpAppBridge({
    required RefusionMcpAgentControlPlane controlPlane,
    required RefusionMcpSessionStore sessionStore,
    required RefusionMcpResourceProvider resourceProvider,
    RefusionMcpPromptProvider? promptProvider,
  })  : _controlPlane = controlPlane,
        _sessionStore = sessionStore,
        _resourceProvider = resourceProvider,
        _promptProvider = promptProvider ?? RefusionMcpPromptProvider();

  final RefusionMcpAgentControlPlane _controlPlane;
  final RefusionMcpSessionStore _sessionStore;
  final RefusionMcpResourceProvider _resourceProvider;
  final RefusionMcpPromptProvider _promptProvider;

  void openSession(RefusionMcpSession session) {
    _sessionStore.upsert(session);
  }

  bool closeSession(String sessionId) {
    return _sessionStore.remove(sessionId);
  }

  List<RefusionMcpSession> listSessions() {
    return _sessionStore.list();
  }

  List<String> listTools() {
    return _controlPlane.listTools();
  }

  List<String> listResourceUris() {
    return _resourceProvider.listUris();
  }

  List<RefusionMcpPromptDescriptor> listPrompts() {
    return _promptProvider.list();
  }

  RefusionMcpPromptResult getPrompt(String name) {
    return _promptProvider.get(name);
  }

  RefusionMcpResourceResult readResource(String uri) {
    return _resourceProvider.read(uri);
  }

  RefusionMcpCommandResult executeTool(RefusionMcpToolCallRequest request) {
    return _controlPlane.executeTool(request);
  }

  RefusionMcpBridgeHealth health() {
    return RefusionMcpBridgeHealth(
      ready: true,
      sessionCount: _sessionStore.list().length,
      toolCount: _controlPlane.listTools().length,
      resourceCount: _resourceProvider.listUris().length,
    );
  }
}
