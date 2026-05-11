import 'package:flutter/foundation.dart';

@immutable
class RefusionMcpPromptDescriptor {
  const RefusionMcpPromptDescriptor({
    required this.name,
    required this.title,
    required this.description,
    this.arguments = const <Map<String, Object?>>[],
  });

  final String name;
  final String title;
  final String description;
  final List<Map<String, Object?>> arguments;
}

@immutable
class RefusionMcpPromptResult {
  const RefusionMcpPromptResult({
    required this.ok,
    this.message,
    this.descriptor,
  });

  final bool ok;
  final String? message;
  final RefusionMcpPromptDescriptor? descriptor;
}

class RefusionMcpPromptProvider {
  RefusionMcpPromptProvider({
    List<RefusionMcpPromptDescriptor> prompts = _defaultPrompts,
  }) : _prompts = Map<String, RefusionMcpPromptDescriptor>.fromEntries(
          prompts.map(
            (prompt) => MapEntry<String, RefusionMcpPromptDescriptor>(
              prompt.name,
              prompt,
            ),
          ),
        );

  final Map<String, RefusionMcpPromptDescriptor> _prompts;

  static const List<RefusionMcpPromptDescriptor> _defaultPrompts =
      <RefusionMcpPromptDescriptor>[
    RefusionMcpPromptDescriptor(
      name: 'refusion.scene_repair',
      title: 'Scene Repair',
      description:
          'Repair a failing scene using QA diagnostics and patch tools.',
      arguments: <Map<String, Object?>>[
        <String, Object?>{
          'name': 'goal',
          'description':
              'Repair intent (e.g. text overflow, timing, alignment).',
          'required': true,
        },
      ],
    ),
    RefusionMcpPromptDescriptor(
      name: 'refusion.motion_pass',
      title: 'Motion Pass',
      description:
          'Apply a professional animation pass to selected timeline elements.',
      arguments: <Map<String, Object?>>[
        <String, Object?>{
          'name': 'style',
          'description': 'Motion style token like snappy, calm, or cinematic.',
          'required': true,
        },
      ],
    ),
  ];

  List<RefusionMcpPromptDescriptor> list() {
    final values = _prompts.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return values;
  }

  RefusionMcpPromptResult get(String name) {
    final descriptor = _prompts[name];
    if (descriptor == null) {
      return const RefusionMcpPromptResult(
        ok: false,
        message: 'Prompt was not found.',
      );
    }
    return RefusionMcpPromptResult(
      ok: true,
      descriptor: descriptor,
    );
  }
}
