# Scope Layer

## 0. Binding Directives

هذه الوثيقة هي المرجع التنفيذي الملزم لمسار `Scope Layer` ومسار
`animation authoring foundation` المرتبط به.

### 0.1 Protected Live Scrub Rule

مسار `live scrub` الحالي في `root timeline` مسار حساس ومحمي بدرجة عالية.

هذا لا يعني أنه "ممنوع مطلقًا" في جميع الظروف.

المعنى الصحيح هو:

- لا يجوز المساس به بشكل عابر أو غير مقصود
- لا يجوز إدخال تغييرات عليه دون إعلانها صراحة
- لا يجوز تمرير تعديل عليه كأثر جانبي مخفي
- وإذا ظهر أن الوصول إلى نتيجة احترافية يتطلب تعديلًا حقيقيًا في هذا المسار،
  فيجب رفع ذلك للمستخدم أولًا بوضوح قبل التنفيذ

القواعد غير القابلة للتفاوض:

- لا يجوز لأي مرحلة في هذه الخطة تعديل `active live scrub path` بشكل مخفي
  أو غير معلن
- لا يجوز تعديل `native scrub ownership` كأثر جانبي غير مقصود
- لا يجوز تعديل `scrub render surface routing` بلا قرار صريح ومعلن
- لا يجوز تعديل `root background scrub gesture hot path` دون رفع الأمر
  للمستخدم أولًا
- لا يجوز تعديل `transport settle handoff` كجزء جانبي من هذا المسار
- لا يجوز بناء `scope-specific scrub path`
- لا يجوز عمل `fallback` جديد يمر عبر scrub path مختلف دون موافقة صريحة

الأجزاء المحمية تشمل على الأقل:

- `Stage5TimelineScrubPlatformView`
- `Stage5NativeScrubEngine`
- `Stage5SurfaceScrubDecoder`
- `Stage5ScrubOverlayTextureView`
- `Stage5PreviewPlatformView`
- أي wiring مباشر يخص `native_timeline_scrub_surface.dart`

هذه القائمة ليست حصرًا كاملاً. القاعدة الأهم هي حماية السلوك، لا الاسم فقط.

### 0.2 Approval Gate For Any Live Scrub Change

إذا ظهر أثناء التنفيذ أن هناك نقطة لا يمكن حلها دون تعديل متعلق بـ
`live scrub`:

1. يتوقف التنفيذ في هذه النقطة
2. يتم توثيق السبب بدقة
3. يتم تحديد الملفات أو المسارات المتأثرة بدقة
4. يتم اقتراح أصغر تعديل ممكن
5. لا يتم تنفيذ أي تعديل قبل موافقة المستخدم الصريحة

ممنوع تمامًا:

- تمرير تعديل على `live scrub` بشكل جانبي
- إجبار تغيير على المسار المحمي بحجة أنه "ضروري"
- إلغاء سلوك scrub الحالي أو إضعافه قسرًا

ومسموح فقط بالصيغة التالية:

- تحديد التعديل المطلوب بدقة
- شرح لماذا هو مسار إجباري للوصول إلى الجودة المطلوبة
- شرح المخاطر المحتملة
- تنفيذ التعديل بعد موافقة المستخدم
- مراقبة هذا المسار مباشرة أثناء التنفيذ والاختبار

### 0.3 Execution Priority Rule

الأولوية الصحيحة ليست بناء `Scope Layer` كامل شكليًا أولاً، وليست إعادة
كتابة محرك الأنيميشن كله أولاً.

الأولوية الصحيحة هي:

1. بناء `animation authoring foundation` صغيرة ومباشرة
2. ثم بناء `Scope Layer shell` فوق نفس التايملاين الحالي
3. ثم تنفيذ `Text Scope` كأول `vertical slice`

السبب:

- التايملاين الحالي قوي وحساس جدًا في `live scrub`
- نظام الأنيميشن الحالي يملك foundation حقيقية لكنه لا يملك بعد
  `manual keyframe authoring bridge`
- بناء `Scope` قبل هذا الجسر سيعطي timeline داخليًا شكليًا بدون authoring
  حقيقي

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

قاعدة أساسية يجب تثبيتها منذ البداية:

- `Scope Layer` ليس timeline ثانيًا مستقلًا
- `Scope Layer` هو `projection / mode` فوق نفس نظام التايملاين الأساسي
- لا يجوز بناء `scope timeline` من الصفر أو عمل fork جديد للـ timeline engine
- الهدف هو الاحتفاظ بنفس جودة:
  - `live scrub`
  - `gesture routing`
  - `zoom`
  - `playhead`
  - `visual style`

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

### 4.6 Main Timeline Reuse Mandate

أهم ملاحظة عملية من التجارب السابقة هي:

- عندما تم فتح scope عبر timeline مبني من جديد، ظهرت مشاكل مباشرة في:
  - `live scrub`
  - بعض gestures
  - ثبات السلوك
  - تطابق الشكل والأسلوب
- لذلك فإن `Scope Layer` يجب أن يعيد استخدام:
  - نفس `timeline core`
  - نفس `timeline widgets`
  - نفس `live scrub path`
  - نفس `interaction system`
- الذي يتغير فقط هو:
  - `active scope`
  - `data projection`
  - `visible rows / lanes`
  - `toolbar toolset`

هذه ليست توصية اختيارية، بل قاعدة معمارية مانعة لإعادة بناء التايملاين من الصفر داخل scope.

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

### 5.5 يوجد motion foundation جزئي لكنه غير مكتمل authoring

المشروع الحالي لا يساوي "zero animation system".

الموجود فعليًا:

- `MotionPropertyChannelModel`
- `MotionKeyframeModel`
- `MotionPropertyCatalog`
- `MotionNormalizedComposition`
- `BasicMotionRuntimeEvaluator`
- `MotionTextAnimationBindingModel`
- `MotionEffectBindingModel`

لكن الناقص حاليًا هو ما يهم هذا المسار:

- لا يوجد `manual keyframe authoring bridge` من الكانفا إلى القنوات
- لا توجد `general scope lanes` حقيقية لكل الأنواع
- لا يوجد `typed modifier lane model` يفصل بوضوح بين `Animate` و`FX`
- لا يوجد `nested scope graph`
- لا يوجد `general purpose layer authoring flow` يربط الكانفا والتايملاين
  والـ keyframes في حلقة واحدة

وبالتالي لا يجوز بناء `Scope Layer` الآن على افتراض أن محرك الأنيميشن
مكتمل، ولا يجوز أيضًا تجاهل الـ foundation الموجودة بالفعل.

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

## 7.4 Visual Continuity Rule

عند الدخول إلى `Scope Mode` لا يجب أن يشعر المستخدم أنه دخل إلى timeline مختلف.

القواعد غير القابلة للتغيير:

- شكل التايملاين لا يتغير نهائيًا
- نفس:
  - `ruler`
  - `playhead`
  - `live scrub`
  - `zoom behavior`
  - `spacing`
  - `timeline style`
  - `gesture feel`
- لا يتم فتح timeline جديد مختلف بصريًا
- لا يتم إعادة بناء واجهة timeline ثانية من الصفر

الذي يتغير فقط:

- المحتوى المعروض داخل النطاق
- الطبقة المالكة المعروضة داخل scope
- الـ rows أو lanes التابعة لهذا النوع
- شريط الأدوات العلوي الخاص بالـ scope

## 7.5 Scope Toolbar Contract

عند الدخول إلى `Scope Mode`، التغيير الأساسي المرئي للمستخدم يجب أن يكون في `top toolbar` لا في شكل التايملاين نفسه.

الترتيب الأساسي المطلوب لأدوات الـ scope:

1. `Back`
2. `Split`
3. `Trim`
4. `Duplicate`
5. أدوات تحرير دقيقة حسب النوع

قواعد هذا الشريط:

- `Back` يحل محل أول أداة في root mode
- `Delete` لا يظهر داخل `Scope Mode` كأداة رئيسية
- بعد الأدوات الأساسية تأتي الأدوات الدقيقة المرتبطة بالنوع أو بالمحتوى الداخلي
- الأدوات المتقدمة يجب أن تكون `typed` بحسب نوع الطبقة

أمثلة على الأدوات الدقيقة:

- `Keyframe`
- `FX`
- `Transform`
- `Opacity`
- `Text Style`
- `Gain`
- `Fade`
- `Transition Params`

أمثلة typed:

- `Text Scope`
  - `Back`
  - `Split`
  - `Trim`
  - `Duplicate`
  - `Keyframe`
  - `Text Style`
  - `Transform`
  - `FX`
- `Image Scope`
  - `Back`
  - `Split`
  - `Trim`
  - `Duplicate`
  - `Keyframe`
  - `Transform`
  - `Opacity`
  - `FX`
- `Audio Scope`
  - `Back`
  - `Split`
  - `Trim`
  - `Duplicate`
  - `Keyframe`
  - `Gain`
  - `Fade`
  - `Audio FX`
- `Transition Scope`
  - `Back`
  - `Duration`
  - `Curve`
  - `Direction`
  - `Transition Params`

## 7.6 Scope Content Rule

عند فتح scope:

- لا نعرض المشروع كله
- لا نعرض timeline آخر مستقل
- نعرض فقط:
  - `owner layer`
  - وما يتبعه من lanes أو rows مرتبطة به

هذا يحافظ على تركيز المستخدم ويمنع تحول scope إلى نسخة ثانية من root timeline.

## 8. المعمارية المقترحة

## 8.0 Non-Negotiable Architecture Rule

`Scope Layer` يجب أن يعيد استخدام `primary timeline engine`.

هذا يعني:

- نفس محرك التايملاين الأساسي
- نفس مسار `live scrub`
- نفس gesture routing
- نفس rendering core
- نفس visual timeline system

وما لا يجب فعله:

- عدم بناء `ScopeTimelineScreen` بنسخة timeline منفصلة
- عدم عمل fork مستقل لـ `TimelinePanel`
- عدم بناء scrub manager جديد خاص بالـ scope
- عدم بناء playback path ثانٍ
- عدم نسخ timeline interactions إلى implementation أخرى
- عدم إدخال أي تعديل على `live scrub` path المحمي ضمن هذا المسار بدون
  موافقة صريحة ومعلنة

التركيب الصحيح هو:

- `Timeline Core`
- `Timeline Projection`
- `Scope Controller`

بمعنى:

- `Scope` = نفس timeline
- لكن مع `different projection`
- و`different toolbar profile`
- و`different visible rows`

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

هذه هي الخطة المهنية المقترحة بعد تثبيت حقيقة الكود الحالي:

- يوجد `motion foundation` حقيقية
- لا يوجد بعد `manual keyframe authoring bridge`
- `Scope Layer` يجب أن يبنى فوق نفس التايملاين الحالي
- `live scrub` مسار محمي لا يُمس

### Phase 0: Freeze + Guardrails

الهدف:

- تثبيت حدود التنفيذ قبل أي تغيير

التسليمات:

- توثيق `protected live scrub rule`
- توثيق `approval gate` لأي تغيير محتمل في scrub path
- تعريف `protected behaviors` التي لا يجوز كسرها
- قائمة تحقق regression إلزامية لـ:
  - `root live scrub`
  - `background scrub`
  - `zoom`
  - `selection`
  - `playhead continuity`

هذه المرحلة لا تغيّر سلوك التطبيق.
هي مرحلة منع انحراف المسار.

### Phase 1: Text Animation Authoring Foundation

الهدف:

- إنشاء الجسر الحقيقي بين:
  - `timeline time`
  - `canvas transform edits`
  - `MotionPropertyChannelModel`
  - `keyframes`

التسليمات:

- `text element motion authoring service`
- `positionX/positionY` authoring عند الزمن الحالي
- `scaleX/scaleY` authoring عند الزمن الحالي
- `rotationDegrees` authoring عند الزمن الحالي
- `opacity` authoring عند الزمن الحالي
- سياسة واضحة:
  - متى نعدّل `static property`
  - ومتى ننشئ أو نحدّث `channel keyframe`
- `minimal identity/span primitives` اللازمة لهذا الجسر فقط

هذه المرحلة لا تبني `Scope UI` بعد.
الهدف هو أن يصبح للأنيميشن مسار تحرير حقيقي، لا مجرد preview أو preset path.

ملاحظة تنفيذ صارمة وملزمة:

- لا يجوز اعتبار هذه المرحلة مكتملة إذا بقيت canvas transform edits تكتب فقط
  إلى `static properties`
- لا يجوز ترك `move / scale / rotate / opacity` في حالة نصف مرتبطة بين
  static وchannels
- لا يجوز بناء UI جديد فوق هذه المرحلة قبل أن تعمل القنوات اليدوية في:
  - preview
  - timeline time evaluation
  - export composition path
  - delete/duplicate/trim lifecycle
- يجب أن يكون أي نقص متبقٍ مكتوبًا كـ blocker صريح، لا كملاحظة مؤجلة
  عائمة

### Phase 2: Modifier Taxonomy + Lane Contract

الهدف:

- تثبيت الفصل الرسمي بين `Animate` و`FX`
- وتعريف model واضح لـ `modifier lanes`

التسليمات:

- taxonomy رسمي:
  - ما الذي يعد `Animate`
  - ما الذي يعد `FX`
- `modifier domain = animate | fx`
- lane contract موحد للعرض والتحرير
- slot contract للأزرار الجانبية على التراك
- capability gating واضح حسب النوع

هذه المرحلة تمنع تكرار الخطأ السابق حيث تختلط `Animate` و`FX`
أو يتم تمثيلها كـ lane واحدة شكلية.

### Phase 3: Scope Session + Projection Shell

الهدف:

- بناء `Scope Layer` كـ `projection / mode` فوق نفس `TimelinePanel`

التسليمات:

- `ScopeSession`
- `ScopeStack`
- `enterScope() / exitScope()`
- `scope-local selection`
- `scope-local toolbar profile`
- `timeline projection`
- `breadcrumb/back path`
- `Open Scope`
- `double tap entry`

شروط هذه المرحلة:

- لا يوجد fork جديد للتايملاين
- لا يوجد timeline جديد مستقل
- لا يوجد scrub path جديد
- لا يوجد تغيير في شكل التايملاين
- لا يوجد تغيير في root live scrub behavior

### Phase 4: Text Scope First Vertical Slice

الهدف:

- تقديم أول `Scope` احترافي حقيقي على `Text`

التسليمات:

- `Text Scope` على نفس التايملاين
- lanes حقيقية لـ:
  - `Position`
  - `Scale`
  - `Rotation`
  - `Opacity`
- `Animate` entry مستقل
- `FX` entry مستقل
- أدوات `scope toolbar` الخاصة بالنص
- ربط الكانفا والتايملاين على نفس source of truth

هذه المرحلة هي أول نقطة يجب أن نستطيع فيها القول:

- التعديل من الكانفا يكتب keyframes
- التعديل من lane ينعكس على الكانفا
- scrub يعكس النتيجة بشكل موحد

### Phase 5: FX Parameter Foundation

الهدف:

- جعل `FX` أكثر من binding ثابت

التسليمات:

- `fx parameter channel model`
- `FX lane rows`
- parameter timelines
- keyframe-capable FX parameters عند الحاجة
- bottom sheet منفصل لـ `FX`

### Phase 6: Image Scope

الهدف:

- تعميم النموذج على `Image Overlay`

التسليمات:

- transform
- opacity
- animate lanes
- fx lanes
- overlay-specific controls

### Phase 7: Video Scope

الهدف:

- تعميم النموذج على `Video`

التسليمات:

- video transform/opacity authoring
- animate lanes
- fx lanes
- hooks لخصائص أكثر تعقيدًا لاحقًا

### Phase 8: Audio Scope

الهدف:

- إدخال `Audio Scope` على model واضح

التسليمات:

- gain lane
- fade lane
- audio modifier foundation

### Phase 9: Transition Scope

الهدف:

- ترقية الانتقال إلى كيان قابل للتحرير داخل scope

التسليمات:

- `transition entity`
- `transition scope`
- duration/curve/parameter editing

### Phase 10: History + Persistence

الهدف:

- تثبيت النظام للاستخدام الطويل

التسليمات:

- command history حقيقي
- `undo/redo` متكامل عبر scope
- serialization
- reopen scope safely
- round-trip integrity

## 10. لماذا Text Scope أولاً

أولوية `Text Scope` ليست اجتهادًا عشوائيًا، بل هي أفضل نقطة بداية للأسباب التالية:

- المستخدم شرح هذه الحالة تحديدًا كمثال أساسي
- النص يحتاج `animation/fx` بشكل طبيعي
- لا يعتمد على video engine معقد
- يثبت `scope entry/exit` و`child timeline` بسرعة
- إذا نجح النص، يصبح تعميم الفكرة على `image/video/audio` أوضح بكثير
- النص هو أيضًا أقصر طريق لاختبار `manual keyframe authoring bridge`
  قبل التوسع إلى باقي الأنواع

## 11. ما الذي لا يجب فعله في البداية

لتجنب دخول المشروع في مسار ثقيل مبكرًا، يجب عدم البدء بهذه الأشياء أولًا:

- عدم بناء `full FX library` قبل تأسيس الموديل
- عدم بناء `complex transition catalog` قبل وجود `transition entity`
- عدم ربط كل أنواع الطبقات دفعة واحدة
- عدم بناء `Scope UI` كامل قبل وجود `authoring bridge` حقيقي للـ keyframes
- عدم إدخال `undo/redo` الشامل قبل وجود operation layer واضحة
- عدم المساس بمسار `live scrub` المحمي بشكل غير معلن أو جانبي ضمن هذا
  المسار

## 12. الملفات المرشحة للتأثر لاحقًا

هذه ليست قائمة تنفيذ نهائية، لكنها خريطة أولية للأماكن التي ستتأثر غالبًا.

### ملفات موجودة ستتغير

- `lib/features/editor/presentation/screens/fusionx_clean_ui_screen.dart`
- `lib/features/editor/presentation/widgets/timeline_panel.dart`
- `lib/features/editor/presentation/widgets/editor_tools_bar.dart`
- `lib/features/editor/presentation/widgets/editor_top_bar.dart`
- `lib/features/editor/presentation/widgets/preview_stage.dart`
- `lib/features/editor/presentation/models/timeline_mock_models.dart`
- `lib/features/editor/domain/models/professional_motion_*.dart`

### ملفات جديدة متوقعة

- `lib/features/editor/domain/models/...`
- `lib/features/editor/domain/scope/...`
- `lib/features/editor/application/...`
- `lib/features/editor/presentation/widgets/scope/...`

### ملفات ومسارات محمية لا تدخل ضمن التنفيذ بدون موافقة صريحة

- أي جزء من `Stage5` live scrub path
- أي ربط native خاص بـ `scrub surface`
- أي wiring يغير ملكية `active scrub rendering`
- أي مسار يغير `root live scrub` behavior

## 13. Definition of Done للنسخة الأولى من Scope Layer

نعتبر أول نسخة احترافية ناجحة عندما يتحقق الآتي:

1. يمكن تحديد `Text Layer` ثم الدخول إليه عبر `double tap` أو `Open Scope`.
2. يظهر `scoped timeline projection` حقيقي وليس sheet أو dialog ولا timeline منفصلًا.
3. يوجد `breadcrumb/back path` واضح.
4. يوجد `scope-local selection` و`scope-local playhead`.
5. يمكن تعديل `Position / Scale / Rotation / Opacity` كـ keyframes حقيقية داخل `Text Scope`.
6. يوجد فصل واضح بين `Animate` و`FX`.
7. عند الرجوع إلى الـ `root timeline` يبقى العنصر نفسه في مكانه مع التعديلات المرتبطة به.
8. لا ينكسر `root timeline` interaction أثناء الدخول والخروج من النطاق.
9. لا يحدث أي تراجع في `root live scrub`.

## 14. القرار التنفيذي المقترح الآن

القرار الصحيح التالي ليس البدء مباشرة في UI التفصيلي، بل تنفيذ هذا التسلسل:

1. تثبيت `Freeze + Guardrails`
2. بناء `Text Animation Authoring Foundation`
3. بناء `Modifier Taxonomy + Lane Contract`
4. بناء `Scope Session + Projection Shell`
5. تنفيذ `Text Scope` كأول `vertical slice`

هذا هو المسار الأكثر احترافية وأقل مخاطرة داخل هذا المشروع الحالي لأنه:

- يحترم حساسية `live scrub`
- لا يبني `Scope` شكليًا قبل وجود authoring حقيقي
- يستثمر الـ motion foundation الموجودة بدل تجاهلها
- يقدّم أسرع vertical slice احترافي يمكن الوثوق به
