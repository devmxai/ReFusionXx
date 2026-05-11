import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'refusion_mcp_json_rpc_server.dart';

/// Lightweight Streamable HTTP transport adapter for the ReFusion MCP JSON-RPC
/// server.
///
/// - `POST /mcp` handles JSON-RPC messages.
/// - `GET /mcp` supports SSE keep-alive for streamable HTTP clients.
class RefusionMcpStreamableHttpServer {
  RefusionMcpStreamableHttpServer({
    required RefusionMcpJsonRpcServer jsonRpcServer,
    this.endpointPath = '/mcp',
    this.ssePingInterval = const Duration(seconds: 15),
  })  : _jsonRpcServer = jsonRpcServer,
        assert(endpointPath.isNotEmpty);

  final RefusionMcpJsonRpcServer _jsonRpcServer;
  final String endpointPath;
  final Duration ssePingInterval;

  HttpServer? _server;

  bool get isRunning => _server != null;

  int? get port => _server?.port;

  Future<HttpServer> start({
    InternetAddress? address,
    int port = 0,
  }) async {
    final running = _server;
    if (running != null) {
      return running;
    }
    final server =
        await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    _server = server;
    unawaited(
      server.forEach(_handleRequest).whenComplete(() {
        _server = null;
      }),
    );
    return server;
  }

  Future<void> stop({bool force = false}) async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: force);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path != endpointPath) {
      await _respondNotFound(request);
      return;
    }
    _applyCorsHeaders(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method == 'GET') {
      await _handleGet(request);
      return;
    }
    if (request.method == 'POST') {
      await _handlePost(request);
      return;
    }
    request.response.statusCode = HttpStatus.methodNotAllowed;
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json');
    request.response.write(
      jsonEncode(<String, Object?>{
        'error': 'Method not allowed.',
        'allowed': <String>['GET', 'POST', 'OPTIONS'],
      }),
    );
    await request.response.close();
  }

  Future<void> _handleGet(HttpRequest request) async {
    final acceptsSse = request.headers
            .value(HttpHeaders.acceptHeader)
            ?.contains('text/event-stream') ??
        false;
    if (!acceptsSse) {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'transport': 'streamable-http',
          'endpoint': endpointPath,
          'message': 'Use POST for JSON-RPC messages.',
        }),
      );
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.write(': connected\n\n');
    await request.response.flush();

    final timer = Timer.periodic(ssePingInterval, (_) {
      try {
        request.response.write(': ping\n\n');
      } catch (_) {
        // Ignore write errors if client closed.
      }
    });
    try {
      await request.response.done;
    } finally {
      timer.cancel();
    }
  }

  Future<void> _handlePost(HttpRequest request) async {
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json');
    final body = await utf8.decoder.bind(request).join();
    Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('JSON body must be an object.');
      }
      payload = <String, Object?>{};
      for (final entry in decoded.entries) {
        if (entry.key is String) {
          payload[entry.key as String] = entry.value;
        }
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'error': <String, Object?>{
            'code': -32700,
            'message': 'Parse error: $error',
          },
        }),
      );
      await request.response.close();
      return;
    }

    final result = _jsonRpcServer.handle(payload);
    request.response.statusCode = HttpStatus.ok;
    request.response.write(jsonEncode(result));
    await request.response.close();
  }

  Future<void> _respondNotFound(HttpRequest request) async {
    _applyCorsHeaders(request.response);
    request.response.statusCode = HttpStatus.notFound;
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json');
    request.response.write(
      jsonEncode(<String, Object?>{
        'error': 'Not found.',
        'expectedPath': endpointPath,
      }),
    );
    await request.response.close();
  }

  void _applyCorsHeaders(HttpResponse response) {
    response.headers.set('access-control-allow-origin', '*');
    response.headers.set('access-control-allow-methods', 'GET,POST,OPTIONS');
    response.headers.set(
      'access-control-allow-headers',
      'content-type,authorization,mcp-session-id',
    );
    response.headers.set('access-control-expose-headers', 'mcp-session-id');
  }
}
