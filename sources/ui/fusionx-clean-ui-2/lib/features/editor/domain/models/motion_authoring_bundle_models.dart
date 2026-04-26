import 'package:flutter/foundation.dart';

import 'professional_motion_animation_models.dart';
import 'professional_motion_compilation_models.dart';
import 'professional_motion_models.dart';

@immutable
class MotionAuthoringBundle {
  MotionAuthoringBundle({
    required this.origin,
    List<MotionElementModel> elements = const <MotionElementModel>[],
    List<MotionPropertyChannelModel> propertyChannels =
        const <MotionPropertyChannelModel>[],
  })  : elements = List.unmodifiable(elements),
        propertyChannels = List.unmodifiable(propertyChannels);

  final MotionAuthoringOrigin origin;
  final List<MotionElementModel> elements;
  final List<MotionPropertyChannelModel> propertyChannels;

  bool get hasEditableMotion => propertyChannels.isNotEmpty;
}
