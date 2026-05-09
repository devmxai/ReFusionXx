import 'package:flutter_test/flutter_test.dart';
import 'package:refusion_app/features/editor/domain/services/scene_brand_motion_mapping.dart';

void main() {
  const mapping = SceneBrandMotionMapping();

  test('maps ChatGPT brand token to tech motion profile', () {
    final result = mapping.resolve(
      brandToken: r'$brand.chatgpt',
      mood: 'energetic professional',
      label: 'AI',
      body: 'Build with intelligence',
    );

    expect(result.profile.id, r'$motion.brand.tech');
    expect(result.profile.style, 'tech');
    expect(
      result.issues.any(
        (issue) => issue.message.contains(kSceneBrandMotionMappingProofTag),
      ),
      isTrue,
    );
  });

  test('maps social brand token to playful profile', () {
    final result = mapping.resolve(
      brandToken: r'$brand.instagram',
      mood: 'playful campaign',
      label: 'Stories',
      body: 'Social-first motion',
    );

    expect(result.profile.id, r'$motion.brand.playful');
    expect(result.profile.style, 'playful');
  });

  test('maps premium/luxury mood to minimal profile', () {
    final result = mapping.resolve(
      mood: 'luxury minimal launch',
      label: 'Premium',
      body: 'Refined composition',
    );

    expect(result.profile.id, r'$motion.brand.minimal');
    expect(result.profile.style, 'minimal');
  });
}
