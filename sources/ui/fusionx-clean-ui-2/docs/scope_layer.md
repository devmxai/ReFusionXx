# Scope Layer

## 1. الهدف

هذه الوثيقة تضع خطة احترافية لبناء ميزة `Scope Layer` داخل مشروع `fusionx-clean-ui-2`.

المقصود بـ `Scope Layer` هو:

- عندما يحدد المستخدم عنصرًا في الـ `Timeline` ثم يقوم بـ `double tap` عليه، ندخل إلى `nested timeline` خاص بهذا العنصر.
- داخل هذا الـ `scope` يظهر فقط هذا العنصر بوصفه محور التحرير، وتظهر تحته طبقات وممرات إضافية خاصة به مثل:
  - `Animation`
  - `FX`
  - `Text-specific controls`
  - `Audio-specific controls`
  - `Transition-specific controls`
- عند الرجوع إلى الـ `root timeline` يبقى العنصر في مكانه الطبيعي، لكن مع كل التعديلات الداخلية التي تمت عليه.

المرجع التصوري هو أسلوب قريب من:

- `After Effects` من ناحية الدخول إلى طبقة والعمل داخلها
- `Alight Motion` من ناحية التركيز على طبقة واحدة وبناء حركة/تأثيرات خاصة بها

## 2. تعريف الميزة

الميزة ليست مجرد `inspector` أو `property sheet`.

الميزة المطلوبة هي `editing scope` حقيقي، أي:

- `Root Timeline` يمثل المشروع الكامل
- كل `Layer/Clip` قابل للدخول إلى `child scope`
- هذا `child scope` يملك:
  - `local timeline`
  - `local selection`
  - `local playhead`
  - `local tools`
  - `local animation/effect lanes`
- التعديلات داخل هذا النطاق يجب أن تعود بشكل منظم إلى العنصر الأصلي في الـ `root timeline`

## 3. الحالة الحالية المؤكدة من الكود

هذه الخطة مبنية على المشروع الحالي فقط، وليس على افتراضات خارجية.

### 3.1 ما هو موجود اليوم

- المشروع الحالي هو `UI-only clean baseline` بحسب `README.md`
- الشاشة الرئيسية الحالية هي:
  - `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- لوحة التايملاين الحالية هي:
  - `lib/features/editor/presentation/widgets/timeline_panel.dart`
- نموذج البيانات الحالي هو:
  - `lib/features/editor/presentation/models/timeline_mock_models.dart`

### 3.2 أنواع التراكات/الطبقات الموجودة في الموديل

الموديل الحالي يعرّف:

- `video`
- `image`
- `audio`
- `text`
- `lipSync`

لكن الحالة الابتدائية الفعلية في الشاشة تبني فقط:

- `video`
- `audio`
- `text` placeholder

ولا تبني ابتدائيًا:

- `image track`
- `lipSync track`

### 3.3 ما يدعمه الـ timeline اليوم

الموجود فعليًا في الكود الحالي:

- `single clip selection`
- `background tap`
- `background scrub`
- `pinch zoom`
- `split`
- `trim left/right`
- `duplicate`
- `delete`
- `clip reorder`
- `split bridge` visual only

### 3.4 ما هو غير موجود اليوم

غير موجود في المشروع الحالي:

- `double tap open scope`
- `nested timeline`
- `scope stack`
- `timeline-in-timeline`
- `transition model` حقيقي
- `per-layer animation model`
- `FX stack model`
- `text content/style animation model`
- `overlay composition model`
- `audio automation model`
- `command history` حقيقي لـ `undo/redo`
- `persistent editor store`

## 4. الأساس القابل لإعادة الاستخدام

رغم أن `Scope Layer` غير موجود بعد، هناك أساس جيد يمكن البناء فوقه.

### 4.1 Editor state seed

في `fusionx_clean_ui_screen.dart` يوجد أساس state واضح يمكن تحويله لاحقًا إلى `ScopeController` أو `EditorStore`:

- `_tracks`
- `_selectedClipId`
- `_currentSeconds`
- `_isPlaying`
- `_assetLibrary`
- `_activeTab`

هذا مهم لأن `Scope Layer` سيحتاج نفس المفاهيم لكن داخل `scope` محلي أيضًا.

### 4.2 Timeline geometry and time mapping

`timeline_panel.dart` يملك أساسًا جيدًا لـ:

- تحويل `scroll offset` إلى وقت
- تثبيت التركيز أثناء `pinch zoom`
- حساب عرض العناصر على أساس الزمن
- التعامل مع `playhead`

هذه الطبقة الهندسية قابلة لإعادة الاستخدام داخل `root timeline` وداخل أي `child scope`.

### 4.3 Reorder interaction pattern

مسار `clip reorder` الحالي يحتوي على pattern جيد يمكن تعميمه:

- أخذ `snapshot`
- الدخول في `interaction mode`
- تحديث حالة وسيطة أثناء التفاعل
- `commit` عند الإفلات
- `delayed exit`

هذا النمط ممتاز لاحقًا لـ:

- `trim sessions`
- `scope-local edits`
- `transition edits`
- `animation drag handles`

### 4.4 Scope-aware action surfaces

يوجد فصل جيد نسبيًا بين:

- `EditorTopBar`
- `EditorToolsBar`
- `MediaDock`
- `TimelinePanel`

وهذا مفيد لأن `Scope Layer` يحتاج أن تتبدل الأدوات بحسب النطاق الحالي.

### 4.5 Preview shell

`PreviewStage` يدعم `overlay` widget، وهذا ليس كافيًا وحده، لكنه إشارة جيدة إلى أن واجهة المعاينة قابلة مستقبلًا لاستيعاب `scope-specific overlays`.

## 5. الفجوات المعمارية التي تمنع Scope Layer اليوم

هذه هي الفجوات الجوهرية التي تمنع بناء الميزة مباشرة على الوضع الحالي.

### 5.1 الموديل الحالي مسطح جدًا

`TimelineTrackData` اليوم يحتوي فقط على:

- `kind`
- `clips`
- `placeholderLabel`

و`TimelineClipData` يحتوي فقط على:

- `id`
- `duration`
- `type`
- `tone`
- `assetId`
- `sourceOffsetSeconds`
- `label`
- `splitGroupId`

هذا لا يكفي لتمثيل:

- `nested scope`
- `child timeline`
- `scope-local tracks`
- `effect lanes`
- `animation lanes`
- `transition nodes`

### 5.2 لا توجد هوية مستقرة كافية

الهوية الحالية غير كافية لبناء round-trip محترف بين `child scope` و`root timeline`.

النواقص:

- لا يوجد `trackId`
- لا يوجد `timelineId`
- لا يوجد `layerId`
- لا يوجد `scopeId`
- لا يوجد `clip instance identity` مستقل عن asset

وهذا سيمنع لاحقًا:

- حفظ علاقات الأب/الابن
- إعادة فتح الـ `scope`
- تطبيق التعديلات الداخلية على العنصر الصحيح
- بناء `undo/redo` احترافي عبر النطاقات

### 5.3 الزمن ما زال ضمنيًا لا span-based

الوضع الحالي يستنتج تموضع العنصر من ترتيب القائمة + مجموع `duration`.

هذا لا يكفي لـ:

- `overlays`
- `layer overlaps`
- `gaps`
- `nested local time`
- `mapping child time -> root time`

لذلك لا بد من الانتقال إلى `time span primitives`.

### 5.4 لا توجد أنواع payload حقيقية للطبقات

في الوضع الحالي الـ clip يحمل بيانات عامة جدًا.

لكن `Scope Layer` يحتاج payloads حقيقية بحسب النوع:

- `video layer payload`
- `image layer payload`
- `text layer payload`
- `audio layer payload`
- `transition payload`

### 5.5 لا يوجد animation/effects system

لا يوجد اليوم مكان في الموديل لوضع:

- `keyframes`
- `animated properties`
- `easing`
- `effect stack`
- `effect parameters`
- `opacity/transform/blend`
- `audio gain/fades`

وبالتالي لا يمكن أن يكون الـ `Scope` اليوم أكثر من شاشة شكلية فقط.

### 5.6 لا يوجد nested editor state

كل شيء اليوم مملوك مباشرة داخل `FusionXCleanUiScreen`.

هذا يعيق:

- `scope stack`
- `breadcrumbs`
- `return to parent scope`
- `scope-local selection`
- `scope-local history`

## 6. أنواع Scope المطلوبة

الميزة يجب أن تغطي خمسة أنواع رئيسية:

1. `Video Scope`
2. `Image Overlay Scope`
3. `Text Layer Scope`
4. `Audio Scope`
5. `Transition Scope`

### 6.1 Video Scope

عند الدخول إلى `video layer`:

- يظهر العنصر بوصفه `owner layer`
- يظهر تحته لاحقًا:
  - `Transform lane`
  - `Opacity lane`
  - `FX lane`
  - `Animation lane`
  - `Mask lane` مستقبلًا

### 6.2 Image Overlay Scope

هذا مشابه للفيديو لكن بدون منطق `source video trimming` المعقد.

الأولوية هنا:

- `position`
- `scale`
- `rotation`
- `opacity`
- `blend mode`
- `entry/exit animation`

### 6.3 Text Layer Scope

هذا هو المثال الأوضح الذي طلبه المستخدم.

عند `double tap` على `text layer`:

- ندخل إلى `Text Scope`
- يظهر النص بوصفه `owner layer`
- تظهر تحته ممرات مثل:
  - `Text content / style`
  - `Transform`
  - `Opacity`
  - `Animation`
  - `Text FX`

### 6.4 Audio Scope

عند الدخول إلى `audio layer`:

- نحتاج على الأقل:
  - `gain`
  - `fade in/out`
  - `pan`
  - `ducking hooks`
  - `audio FX` مستقبلًا

### 6.5 Transition Scope

الانتقال لا يجب أن يبقى مجرد bridge visual.

نحتاج `transition node` حقيقي يمكن تحديده والدخول إليه.

داخل `Transition Scope` لاحقًا:

- `duration`
- `curve`
- `direction`
- `transition-specific parameters`

## 7. سلوك الدخول والخروج من Scope

## 7.1 قواعد UX الأساسية

- `single tap`:
  - يحدد العنصر فقط
- `double tap`:
  - يفتح `Scope Layer`
- `background tap`:
  - يلغي التحديد داخل النطاق الحالي فقط
- `back`:
  - يرجع إلى النطاق الأب مع الحفاظ على `selection/playhead` قدر الإمكان

## 7.2 توصية مهمة للموبايل

رغم أن `double tap` هو الدخول الأساسي المطلوب، يجب توفير طريق ثانوي صريح:

- `Open Scope` action عندما يكون العنصر محددًا

السبب:

- `double tap` قد يتداخل على الهاتف مع:
  - `scrub`
  - `drag`
  - `reorder`
  - `trim handles`

لذلك التنفيذ الاحترافي الأفضل هو:

- `double tap` كـ primary shortcut
- `Open Scope` كـ deterministic fallback

## 7.3 Breadcrumbs

كل نطاق يجب أن يوضح مكان المستخدم بوضوح، مثال:

- `Project / Text Layer / Animation`
- `Project / Video Layer / FX`
- `Project / Transition`

## 8. المعمارية المقترحة

## 8.1 طبقة هوية جديدة

المرحلة الأولى يجب أن تقدم هويات صريحة مثل:

```dart
class ProjectId {}
class TimelineId {}
class TrackId {}
class LayerId {}
class ScopeId {}
class ClipInstanceId {}
```

لا يشترط أن تكون classes حرفيًا، لكن لا بد من وجود هذه الطبقة مفهوميًا في الموديل.

## 8.2 Time span primitives

بدل الاعتماد الكامل على ترتيب القائمة، يجب تعريف primitive من هذا النوع:

```dart
class TimelineSpan {
  final double startSeconds;
  final double endSeconds;
  final double sourceInSeconds;
  final double sourceOutSeconds;
}
```

هذا ضروري لـ:

- `layer-local time`
- `root time`
- `scope mapping`
- `overlays`
- `transition windows`

## 8.3 Scope graph

نحتاج بنية تربط المشروع الكامل بالنطاقات الداخلية:

```dart
class ScopeNode {
  final ScopeId scopeId;
  final TimelineId timelineId;
  final ScopeId? parentScopeId;
  final LayerId ownerLayerId;
  final ScopeKind kind;
}
```

حيث:

- `Root Scope` = المشروع الكامل
- `Child Scope` = نطاق خاص بطبقة معينة أو انتقال معين

## 8.4 Layer payloads

كل طبقة يجب أن تتحول إلى كيان حقيقي لا مجرد clip عام.

مثال مفهومي:

```dart
sealed class LayerPayload {}

class VideoLayerPayload extends LayerPayload {}
class ImageLayerPayload extends LayerPayload {}
class TextLayerPayload extends LayerPayload {}
class AudioLayerPayload extends LayerPayload {}
class TransitionLayerPayload extends LayerPayload {}
```

### Text payload minimum

- text content
- style
- alignment
- font metadata
- color
- stroke/shadow
- transform
- opacity

### Audio payload minimum

- gain
- fades
- mute state
- pan

### Transition payload minimum

- transition type
- duration
- easing/curve
- parameter set

## 8.5 Animation model

يجب إدخال بنية animation قابلة للتوسع:

```dart
class AnimatedPropertyTrack {}
class Keyframe {}
class Easing {}
```

الأولوية الأولى ليست بناء جميع التأثيرات، بل بناء container واضح يستطيع حملها.

## 8.6 FX stack model

كل `Scope` يحتاج `effect stack` خاصًا به:

```dart
class EffectStack {}
class EffectNode {}
class EffectParameter {}
```

## 8.7 Editor store boundary

قبل التوسع في الواجهة، يجب فصل الـ state عن `FusionXCleanUiScreen` إلى طبقة أوضح:

- `EditorStore`
- أو `ScopeController`
- أو `EditorSession`

المهم أن تصبح هناك طبقة تملك:

- timeline graph
- scope stack
- selection
- playhead mapping
- operations
- history

## 9. خطة التنفيذ بالترتيب الصارم

هذه هي الخطة المهنية المقترحة، بالترتيب الذي يقلل الهدر ويمنع بناء UI فوق أساس غير جاهز.

### Phase 1: Identity + Timeline Primitives

الهدف:

- تحويل الموديل من `flat mock clips` إلى model يملك هوية وزمنًا واضحين

التسليمات:

- `trackId`
- `layerId`
- `timelineId`
- `scopeId`
- `TimelineSpan`
- `LayerPayload` base

لا نبني `Scope UI` كامل هنا.
هذه مرحلة foundation فقط.

### Phase 2: Scope Graph + Editor Store

الهدف:

- إنشاء `root scope` و`child scope` كنظام state حقيقي

التسليمات:

- `ScopeNode`
- `ScopeStack`
- `EditorStore`
- `enterScope()`
- `exitScope()`
- `scope-local selection`
- `scope-local playhead`

### Phase 3: Scope Entry Shell

الهدف:

- بناء shell مرئي يسمح بالدخول والخروج من النطاقات بدون animation/effects متقدمة بعد

التسليمات:

- `double tap` entry
- `Open Scope` action
- `breadcrumb header`
- `scoped timeline viewport`
- `return to root`

في هذه المرحلة يكفي أن نثبت:

- التنقل
- state ownership
- selection correctness
- playhead correctness

### Phase 4: Text Scope First

الهدف:

- جعل أول `Scope` حقيقي هو `Text Scope`

السبب:

- هو أوضح حالة استخدام عند المستخدم
- أقل تعقيدًا من `video scope`
- يثبت architecture بدون تعقيد media engine

التسليمات:

- `TextLayerPayload`
- `Text Scope timeline`
- `Text Animation lane`
- `Text FX placeholder stack`
- `Text transform/opacity animation`

### Phase 5: Image Overlay Scope

الهدف:

- إضافة `overlay-style scoped editing`

التسليمات:

- `ImageLayerPayload`
- transform
- opacity
- entry/exit animations
- overlay-specific controls

### Phase 6: Video Scope

الهدف:

- توسيع النظام ليخدم `video layer` بنطاق خاص به

التسليمات:

- `VideoLayerPayload`
- `video-local effect stack`
- transform/opacity animation
- foundation لطبقات مستقبلية مثل masking

### Phase 7: Audio Scope

الهدف:

- بناء طبقة `audio-local editing`

التسليمات:

- `AudioLayerPayload`
- gain/fade primitives
- audio effect hooks

### Phase 8: Transition Scope

الهدف:

- تحويل `split bridge` أو seam visual إلى `transition entity` قابل للتحرير

التسليمات:

- `TransitionLayerPayload`
- transition node identity
- transition scope entry
- transition parameters

### Phase 9: History + Persistence

الهدف:

- جعل النظام قابلاً للاستمرار والرجوع

التسليمات:

- command history حقيقي
- `undo/redo`
- serialization
- reopen scope safely
- round-trip parent/child integrity

## 10. لماذا Text Scope أولاً

أولوية `Text Scope` ليست اجتهادًا عشوائيًا، بل هي أفضل نقطة بداية للأسباب التالية:

- المستخدم شرح هذه الحالة تحديدًا كمثال أساسي
- النص يحتاج `animation/fx` بشكل طبيعي
- لا يعتمد على video engine معقد
- يثبت `scope entry/exit` و`child timeline` بسرعة
- إذا نجح النص، يصبح تعميم الفكرة على `image/video/audio` أوضح بكثير

## 11. ما الذي لا يجب فعله في البداية

لتجنب دخول المشروع في مسار ثقيل مبكرًا، يجب عدم البدء بهذه الأشياء أولًا:

- عدم بناء `full FX library` قبل تأسيس الموديل
- عدم بناء `complex transition catalog` قبل وجود `transition entity`
- عدم ربط كل أنواع الطبقات دفعة واحدة
- عدم بناء `real export/runtime engine` قبل استقرار editor model
- عدم إدخال `undo/redo` الشامل قبل وجود operation layer واضحة

## 12. الملفات المرشحة للتأثر لاحقًا

هذه ليست قائمة تنفيذ نهائية، لكنها خريطة أولية للأماكن التي ستتأثر غالبًا.

### ملفات موجودة ستتغير

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `lib/features/editor/presentation/widgets/editor_tools_bar.dart`
- `lib/features/editor/presentation/widgets/editor_top_bar.dart`
- `lib/features/editor/presentation/widgets/preview_stage.dart`
- `lib/features/editor/presentation/models/timeline_mock_models.dart`

### ملفات جديدة متوقعة

- `lib/features/editor/domain/models/...`
- `lib/features/editor/domain/scope/...`
- `lib/features/editor/application/...`
- `lib/features/editor/presentation/widgets/scope/...`
- `lib/features/editor/presentation/screens/scope_layer_screen.dart`

## 13. Definition of Done للنسخة الأولى من Scope Layer

نعتبر أول نسخة احترافية ناجحة عندما يتحقق الآتي:

1. يمكن تحديد `Text Layer` ثم الدخول إليه عبر `double tap` أو `Open Scope`.
2. يظهر `child timeline` حقيقي وليس مجرد sheet أو dialog.
3. يوجد `breadcrumb/back path` واضح.
4. يوجد `scope-local selection` و`scope-local playhead`.
5. يمكن إضافة `text animation/effect primitives` داخل النطاق.
6. عند الرجوع إلى الـ `root timeline` يبقى العنصر نفسه في مكانه مع التعديلات المرتبطة به.
7. لا ينكسر `root timeline` interaction أثناء الدخول والخروج من النطاق.

## 14. القرار التنفيذي المقترح الآن

القرار الصحيح التالي ليس البدء مباشرة في UI التفصيلي، بل تنفيذ هذا التسلسل:

1. تأسيس `Identity + Span + Scope Graph`
2. بناء `EditorStore / ScopeController`
3. بناء `Scope Entry Shell`
4. تنفيذ `Text Scope` كأول vertical slice

هذا هو المسار الأكثر احترافية وأقل مخاطرة لبناء `Scope Layer` داخل هذا المشروع الحالي.
