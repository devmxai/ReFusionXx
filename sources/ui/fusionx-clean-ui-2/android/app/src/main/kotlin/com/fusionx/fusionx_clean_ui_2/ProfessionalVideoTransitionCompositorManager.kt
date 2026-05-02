package com.refusion.app

import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.LinkedHashMap
import kotlin.math.abs
import kotlin.math.roundToInt

class ProfessionalVideoTransitionCompositorManager(
    private val appContext: Context,
) {
    private val rendererRegistry = ProfessionalVideoTransitionRendererRegistry.foundation()
    private val pixelFrameBufferStore = ProfessionalVideoTransitionPixelFrameBufferStore()

    fun capabilities(): Map<String, Any> =
        mapOf(
            "dualVideoSampling" to true,
            "temporalMotionBlur" to false,
            "mirrorEdgeTiling" to false,
            "previewParity" to false,
            "liveScrubParity" to false,
            "playbackParity" to false,
            "exportParity" to false,
            "rendererVersion" to "foundation",
            "registeredDefinitions" to rendererRegistry.registeredDefinitionIds(),
        )

    fun prepareRenderPlan(plan: Map<String, Any?>?): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        val requestedCapabilities =
            (plan?.get("requiredCapabilities") as? List<*>)?.map { entry ->
                entry.toString()
            } ?: emptyList()
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        val session = sessionResult.session
        val registryResult =
            rendererRegistry.prepare(
                definitionId = definitionId,
                requestedCapabilities = requestedCapabilities,
            )
        if (registryResult != null) {
            return registryResult.withSessionMetadata(session)
        }
        return mapOf(
            "status" to "unsupported",
            "reason" to "native_video_transition_renderer_not_implemented",
            "rendererVersion" to "foundation",
            "definitionId" to definitionId,
            "missingCapabilities" to requestedCapabilities,
        ).withSessionMetadata(session)
    }

    fun prepareZoomInCameraRenderPlan(plan: Map<String, Any?>?): Map<String, Any> =
        prepareRenderPlan(plan)

    fun planVideoSourceBindings(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_source_bindings",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planVideoSourceBindings(timelineTimeMs)
    }

    fun planFrameSamples(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_sample_plan",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planFrameSamples(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
        )
    }

    fun planFrameDecodeRequests(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_decode_plan",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planFrameDecodeRequests(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
        )
    }

    fun planVideoSourceProbe(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_source_probe",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planVideoSourceProbe(
            timelineTimeMs = timelineTimeMs,
            appContext = appContext,
        )
    }

    fun planDualVideoDecoderSession(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_decoder_session",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planDualVideoDecoderSession(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planTemporalSampleAccumulator(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_temporal_accumulator",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTemporalSampleAccumulator(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planMirrorEdgeTiling(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_mirror_edge_tiling",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planMirrorEdgeTiling(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planRenderPassGraph(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pass_graph",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planRenderPassGraph(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planOutputSurface(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_output_surface",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planOutputSurface(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planRenderGraphExecution(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_graph_execution",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planRenderGraphExecution(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planSurfaceRenderer(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_surface_renderer",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planSurfaceRenderer(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planFrameRenderCommands(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_frame_render_commands",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planFrameRenderCommands(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planRendererBackend(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_renderer_backend",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planRendererBackend(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planRendererDrawLoop(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_renderer_draw_loop",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planRendererDrawLoop(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planTransitionShaderEvaluation(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_shader_evaluation",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionShaderEvaluation(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planTransitionPixelRenderer(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pixel_renderer",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionPixelRenderer(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    fun planTransitionPixelRenderExecution(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pixel_render_execution",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionPixelRenderExecution(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
            frameBufferStore = pixelFrameBufferStore,
        )
    }

    fun planTransitionPixelFrameBufferWriter(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pixel_frame_buffer_writer",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionPixelFrameBufferWriter(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
            frameBufferStore = pixelFrameBufferStore,
        )
    }

    fun planTransitionPixelFrameBuffer(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pixel_frame_buffer",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionPixelFrameBuffer(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
            frameBufferStore = pixelFrameBufferStore,
        )
    }

    fun planTransitionPixelOutputProof(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_pixel_output_proof",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planTransitionPixelOutputProof(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
            frameBufferStore = pixelFrameBufferStore,
        )
    }

    fun planParityOutputs(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_parity_outputs",
                "rendererVersion" to "foundation",
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
            )
        }
        return sessionResult.session.planParityOutputs(
            timelineTimeMs = timelineTimeMs,
            motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
            edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
            parameters = plan?.get("parameters") as? Map<*, *>,
            appContext = appContext,
        )
    }

    private fun hasRequiredField(plan: Map<String, Any?>?, field: String): Boolean {
        if (plan == null) {
            return false
        }
        val value = plan[field]
        return when (field) {
            "sources" -> value is List<*> && value.isNotEmpty()
            "parameters", "samplingPolicy", "edgePolicy", "motionBlurPolicy" -> value is Map<*, *>
            "requiredCapabilities" -> value is List<*>
            "transitionId", "definitionId" -> value is String && value.isNotBlank()
            else -> value is Number
        }
    }

    private companion object {
        val requiredRenderPlanFields =
            listOf(
                "definitionId",
                "transitionId",
                "canvasWidth",
                "canvasHeight",
                "boundaryTimeMs",
                "leadingDurationMs",
                "trailingDurationMs",
                "sources",
                "requiredCapabilities",
                "parameters",
                "samplingPolicy",
                "edgePolicy",
                "motionBlurPolicy",
            )
    }
}

private fun isOpenGlEs20Available(context: Context): Boolean {
    val activityManager =
        context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
    val openGlEsVersion =
        activityManager?.deviceConfigurationInfo?.reqGlEsVersion ?: 0
    return openGlEsVersion >= 0x20000
}

private data class ProfessionalVideoTransitionRenderSessionParseResult(
    val session: ProfessionalVideoTransitionRenderSession?,
    val issues: List<Map<String, Any>>,
)

private data class ProfessionalVideoTransitionRenderSession(
    val id: String,
    val definitionId: String,
    val transitionId: String,
    val canvasWidth: Long,
    val canvasHeight: Long,
    val boundaryTimeMs: Long,
    val leadingDurationMs: Long,
    val trailingDurationMs: Long,
    val transitionStartMs: Long,
    val transitionEndMs: Long,
    val outgoing: ProfessionalVideoTransitionRenderSource,
    val incoming: ProfessionalVideoTransitionRenderSource,
    val sourceRoles: List<String>,
) {
    fun metadata(): Map<String, Any> =
        mapOf(
            "renderSessionId" to id,
            "transitionStartMs" to transitionStartMs,
            "transitionEndMs" to transitionEndMs,
            "sourceCount" to 2,
            "sourceRoles" to sourceRoles,
            "outgoingClipId" to outgoing.clipId,
            "incomingClipId" to incoming.clipId,
            "outgoingSourceTimeAtBoundaryMs" to outgoing.sourceTimeForTimelineTime(boundaryTimeMs),
            "incomingSourceTimeAtBoundaryMs" to incoming.sourceTimeForTimelineTime(boundaryTimeMs),
        )

    fun planVideoSourceBindings(timelineTimeMs: Long): Map<String, Any> {
        val bindings =
            listOf(
                sourceBinding(role = "outgoing", source = outgoing),
                sourceBinding(role = "incoming", source = incoming),
            )
        val allSourcesBound = bindings.all { binding ->
            binding["sourceUriBound"] == true
        }
        val blockedReasons =
            if (allSourcesBound) {
                emptyList()
            } else {
                listOf("native_video_source_uri_missing")
            }
        return mapOf(
            "status" to "planned",
            "reason" to "",
            "rendererVersion" to "foundation",
            "definitionId" to definitionId,
            "renderSessionId" to id,
            "timelineTimeMs" to timelineTimeMs,
            "transitionStartMs" to transitionStartMs,
            "transitionEndMs" to transitionEndMs,
            "requiresConcreteSourceUri" to true,
            "allSourcesBound" to allSourcesBound,
            "allowAssetIdOnlyDecode" to false,
            "allowGeneratedProxyDecode" to false,
            "bindings" to bindings,
            "blockedReasons" to blockedReasons,
        )
    }

    fun planVideoSourceProbe(
        timelineTimeMs: Long,
        appContext: Context,
    ): Map<String, Any> {
        val bindingPlan = planVideoSourceBindings(timelineTimeMs)
        if (bindingPlan["status"] != "planned") {
            return bindingPlan
        }
        val bindings =
            (bindingPlan["bindings"] as? List<*>)?.mapNotNull { binding ->
                binding as? Map<*, *>
            } ?: emptyList()
        val probeImplemented = true
        val probes =
            bindings.map { binding ->
                val sourceUri = binding["sourceUri"]?.toString() ?: ""
                val sourceUriBound = binding["sourceUriBound"] == true
                val uriScheme = sourceUri.substringBefore(":", missingDelimiterValue = "")
                val supportedScheme = uriScheme == "file" || uriScheme == "content"
                val probeResult =
                    if (sourceUriBound && supportedScheme) {
                        probeVideoSource(appContext, sourceUri)
                    } else {
                        VideoSourceProbeResult(
                            canOpenSource = false,
                            hasVideoTrack = false,
                            width = null,
                            height = null,
                            durationUs = null,
                            frameRate = null,
                            mimeType = "",
                            reason = null,
                        )
                    }
                val blockedReasons =
                    buildList {
                        if (!sourceUriBound) {
                            add("native_video_source_uri_missing")
                        }
                        if (sourceUriBound && !supportedScheme) {
                            add("native_video_source_uri_scheme_unsupported")
                        }
                        if (!probeImplemented) {
                            add("native_video_source_probe_missing")
                        }
                        if (probeImplemented && supportedScheme && !probeResult.canOpenSource) {
                            add(probeResult.reason ?: "native_video_source_open_failed")
                        }
                        if (probeResult.canOpenSource && !probeResult.hasVideoTrack) {
                            add("native_video_track_missing")
                        }
                    }
                mapOf(
                    "role" to (binding["role"]?.toString() ?: ""),
                    "clipId" to (binding["clipId"]?.toString() ?: ""),
                    "assetId" to (binding["assetId"]?.toString() ?: ""),
                    "sourceUri" to sourceUri,
                    "uriScheme" to uriScheme,
                    "sourceUriBound" to sourceUriBound,
                    "requiresRealVideoSource" to true,
                    "probeImplemented" to probeImplemented,
                    "canOpenSource" to probeResult.canOpenSource,
                    "hasVideoTrack" to probeResult.hasVideoTrack,
                    "videoMimeType" to probeResult.mimeType,
                    "videoWidth" to (probeResult.width ?: 0),
                    "videoHeight" to (probeResult.height ?: 0),
                    "videoDurationUs" to (probeResult.durationUs ?: 0L),
                    "videoFrameRate" to (probeResult.frameRate ?: 0),
                    "allowSyntheticSource" to false,
                    "blockedReasons" to blockedReasons,
                )
            }
        val blockedReasons =
            probes.flatMap { probe ->
                (probe["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                    ?: emptyList()
            }.distinct()
        val allSourcesProbeable =
            probes.size == 2 &&
                probes.all { probe ->
                    probe["sourceUriBound"] == true &&
                        probe["canOpenSource"] == true &&
                        probe["hasVideoTrack"] == true &&
                        probe["allowSyntheticSource"] == false &&
                        ((probe["blockedReasons"] as? List<*>)?.isEmpty() != false)
                }
        return bindingPlan +
            mapOf(
                "requiresRealVideoSource" to true,
                "probeImplemented" to probeImplemented,
                "allSourcesProbeable" to allSourcesProbeable,
                "allowSyntheticSource" to false,
                "probes" to probes,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planFrameSamples(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
    ): Map<String, Any> {
        if (timelineTimeMs < transitionStartMs || timelineTimeMs > transitionEndMs) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "timeline_time_outside_transition_render_session",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "timelineTimeMs" to timelineTimeMs,
                "transitionStartMs" to transitionStartMs,
                "transitionEndMs" to transitionEndMs,
            )
        }
        val timelineSamples =
            temporalSampleTimelineTimes(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
            )
        val transitionDurationMs = (transitionEndMs - transitionStartMs).coerceAtLeast(1L)
        val progress =
            ((timelineTimeMs - transitionStartMs).toDouble() / transitionDurationMs.toDouble())
                .coerceIn(0.0, 1.0)
        val mode = motionBlurPolicy?.get("mode")?.toString() ?: "none"
        val shutterAngleDegrees =
            motionBlurPolicy?.doubleValue("shutterAngleDegrees", defaultValue = 0.0)
                ?.coerceIn(0.0, 720.0) ?: 0.0
        val frameRate =
            motionBlurPolicy?.doubleValue("frameRate", defaultValue = 30.0)
                ?.takeIf { value -> value.isFinite() && value > 0.0 } ?: 30.0
        val sampleCount =
            motionBlurPolicy?.intValue("sampleCount", defaultValue = 1)
                ?.coerceIn(1, 32) ?: 1
        return mapOf(
            "status" to "planned",
            "reason" to "",
            "rendererVersion" to "foundation",
            "definitionId" to definitionId,
            "renderSessionId" to id,
            "timelineTimeMs" to timelineTimeMs,
            "progress" to progress,
            "transitionStartMs" to transitionStartMs,
            "transitionEndMs" to transitionEndMs,
            "sourceRoles" to sourceRoles,
            "outgoingSourceTimeMs" to outgoing.sourceTimeForTimelineTime(timelineTimeMs),
            "incomingSourceTimeMs" to incoming.sourceTimeForTimelineTime(timelineTimeMs),
            "temporalSampleTimelineTimesMs" to timelineSamples,
            "outgoingTemporalSourceTimesMs" to timelineSamples.map { sampleTime ->
                outgoing.sourceTimeForTimelineTime(sampleTime)
            },
            "incomingTemporalSourceTimesMs" to timelineSamples.map { sampleTime ->
                incoming.sourceTimeForTimelineTime(sampleTime)
            },
            "motionBlurMode" to mode,
            "shutterAngleDegrees" to shutterAngleDegrees,
            "frameRate" to frameRate,
            "shutterSampleCount" to sampleCount,
        )
    }

    fun planFrameDecodeRequests(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
    ): Map<String, Any> {
        val framePlan =
            planFrameSamples(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
            )
        if (framePlan["status"] != "planned") {
            return framePlan
        }
        val timelineSamples =
            (framePlan["temporalSampleTimelineTimesMs"] as? List<*>)?.mapNotNull { sample ->
                (sample as? Number)?.toLong()
            } ?: emptyList()
        val outgoingSamples =
            (framePlan["outgoingTemporalSourceTimesMs"] as? List<*>)?.mapNotNull { sample ->
                (sample as? Number)?.toLong()
            } ?: emptyList()
        val incomingSamples =
            (framePlan["incomingTemporalSourceTimesMs"] as? List<*>)?.mapNotNull { sample ->
                (sample as? Number)?.toLong()
            } ?: emptyList()
        val centerSampleIndex =
            timelineSamples.indices.minByOrNull { index ->
                kotlin.math.abs(timelineSamples[index] - timelineTimeMs)
            } ?: 0
        val decodeRequests =
            decodeRequestsForSource(
                role = "outgoing",
                source = outgoing,
                timelineSamples = timelineSamples,
                sourceSamples = outgoingSamples,
                centerSampleIndex = centerSampleIndex,
            ) +
                decodeRequestsForSource(
                    role = "incoming",
                    source = incoming,
                    timelineSamples = timelineSamples,
                    sourceSamples = incomingSamples,
                    centerSampleIndex = centerSampleIndex,
                )
        return framePlan +
            mapOf(
                "decodeMode" to "exactVideoFrame",
                "allowThumbnailFallback" to false,
                "allowBoundaryFreeze" to false,
                "requiresRealVideoFrame" to true,
                "decodeRequests" to decodeRequests,
            )
    }

    fun planDualVideoDecoderSession(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val decodePlan =
            planFrameDecodeRequests(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
            )
        if (decodePlan["status"] != "planned") {
            return decodePlan
        }
        val decodeRequests =
            (decodePlan["decodeRequests"] as? List<*>)?.mapNotNull { request ->
                request as? Map<*, *>
            } ?: emptyList()
        val sourceProbePlan =
            planVideoSourceProbe(
                timelineTimeMs = timelineTimeMs,
                appContext = appContext,
            )
        val sourceProbes =
            (sourceProbePlan["probes"] as? List<*>)?.mapNotNull { probe ->
                probe as? Map<*, *>
            } ?: emptyList()
        val probesByRole = sourceProbes.associateBy { probe ->
            probe["role"]?.toString() ?: ""
        }
        val tracks =
            listOf("outgoing", "incoming").map { role ->
                val roleRequests = decodeRequests.filter { request ->
                    request["role"] == role
                }
                val firstRequest = roleRequests.firstOrNull()
                val centerRequest =
                    roleRequests.firstOrNull { request -> request["centerSample"] == true }
                        ?: firstRequest
                val sourceUri = firstRequest?.get("sourceUri")?.toString() ?: ""
                val sourceProbe = probesByRole[role]
                val sourceProbeReady =
                    sourceProbe != null &&
                        sourceProbe["sourceUriBound"] == true &&
                        sourceProbe["canOpenSource"] == true &&
                        sourceProbe["hasVideoTrack"] == true &&
                        ((sourceProbe["blockedReasons"] as? List<*>)?.isEmpty() != false)
                val centerSourceTimeMs =
                    (centerRequest?.get("sourceTimeMs") as? Number)?.toLong()
                        ?: centerRequest?.get("sourceTimeMs")?.toString()?.toLongOrNull()
                        ?: 0L
                val sourceSampleTimesMs =
                    roleRequests.mapNotNull { request ->
                        (request["sourceTimeMs"] as? Number)?.toLong()
                            ?: request["sourceTimeMs"]?.toString()?.toLongOrNull()
                    }
                val roleSource =
                    if (role == "outgoing") {
                        outgoing
                    } else {
                        incoming
                    }
                val liveDecodeTimelineStartMs =
                    if (role == "outgoing") {
                        transitionStartMs
                    } else {
                        boundaryTimeMs
                    }
                val liveDecodeTimelineEndMs =
                    if (role == "outgoing") {
                        boundaryTimeMs
                    } else {
                        transitionEndMs
                    }
                val liveDecodeSourceStartMs =
                    roleSource.sourceTimeForTimelineTime(liveDecodeTimelineStartMs)
                val liveDecodeSourceEndMs =
                    roleSource.sourceTimeForTimelineTime(liveDecodeTimelineEndMs)
                val liveDecodeWindowDurationMs =
                    (liveDecodeTimelineEndMs - liveDecodeTimelineStartMs).coerceAtLeast(0L)
                val sourceWindowDurationMs =
                    abs(liveDecodeSourceEndMs - liveDecodeSourceStartMs)
                val videoFrameRate =
                    (sourceProbe?.get("videoFrameRate") as? Number)?.toInt()
                val liveDecodeCoverageSourceTimesMs =
                    liveDecodeCoverageSourceTimes(
                        sourceStartMs = liveDecodeSourceStartMs,
                        sourceEndMs = liveDecodeSourceEndMs,
                        frameRate = videoFrameRate,
                    )
                val decodeProbe =
                    if (sourceProbeReady && sourceUri.isNotBlank()) {
                        probeExactVideoFrames(
                            appContext = appContext,
                            sourceUri = sourceUri,
                            sourceTimesMs = sourceSampleTimesMs,
                            frameRate = videoFrameRate,
                        )
                    } else {
                        ExactVideoFrameBatchProbeResult(
                            canDecodeAllFrames = false,
                            outputFormatMimeType = "",
                            outputWidth = 0,
                            outputHeight = 0,
                            samples = sourceSampleTimesMs.map { sourceTime ->
                                ExactVideoFrameSampleProbeResult(
                                    sourceTimeMs = sourceTime,
                                    canDecodeFrame = false,
                                    decodedFrameTimeUs = null,
                                    reason = "native_video_source_probe_not_ready",
                                )
                            },
                            reason = "native_video_source_probe_not_ready",
                        )
                    }
                val liveCoverageProbe =
                    if (
                        sourceProbeReady &&
                            sourceUri.isNotBlank() &&
                            liveDecodeWindowDurationMs > 0L &&
                            sourceWindowDurationMs > 0L
                    ) {
                        probeExactVideoFrames(
                            appContext = appContext,
                            sourceUri = sourceUri,
                            sourceTimesMs = liveDecodeCoverageSourceTimesMs,
                            frameRate = videoFrameRate,
                        )
                    } else {
                        ExactVideoFrameBatchProbeResult(
                            canDecodeAllFrames = false,
                            outputFormatMimeType = "",
                            outputWidth = 0,
                            outputHeight = 0,
                            samples = liveDecodeCoverageSourceTimesMs.map { sourceTime ->
                                ExactVideoFrameSampleProbeResult(
                                    sourceTimeMs = sourceTime,
                                    canDecodeFrame = false,
                                    decodedFrameTimeUs = null,
                                    reason = "native_dual_video_live_decode_window_not_ready",
                                )
                            },
                            reason = "native_dual_video_live_decode_window_not_ready",
                        )
                    }
                val liveStreamProbe =
                    if (
                        sourceProbeReady &&
                            sourceUri.isNotBlank() &&
                            liveDecodeWindowDurationMs > 0L &&
                            sourceWindowDurationMs > 0L
                    ) {
                        probeLiveVideoDecodeStream(
                            appContext = appContext,
                            sourceUri = sourceUri,
                            sourceStartMs = liveDecodeSourceStartMs,
                            sourceEndMs = liveDecodeSourceEndMs,
                            frameRate = videoFrameRate,
                        )
                    } else {
                        LiveVideoDecodeStreamProbeResult(
                            canDecodeStream = false,
                            allDecodedBuffersReadable = false,
                            decodedFrameCount = 0,
                            readableBufferCount = 0,
                            firstFrameTimeUs = null,
                            lastFrameTimeUs = null,
                            minRequiredFrameCount = 0,
                            outputFormatMimeType = "",
                            outputWidth = 0,
                            outputHeight = 0,
                            reason = "native_dual_video_live_decode_window_not_ready",
                        )
                    }
                val continuousSampleCoverageReady =
                    liveCoverageProbe.canDecodeAllFrames &&
                        liveCoverageProbe.canReadAllBuffers &&
                        liveStreamProbe.canDecodeStream &&
                        liveStreamProbe.allDecodedBuffersReadable
                val centerSampleProbe =
                    decodeProbe.samples.minByOrNull { sample ->
                        abs(sample.sourceTimeMs - centerSourceTimeMs)
                    }
                mapOf(
                    "role" to role,
                    "clipId" to (firstRequest?.get("clipId")?.toString() ?: ""),
                    "assetId" to (firstRequest?.get("assetId")?.toString() ?: ""),
                    "sourceUri" to sourceUri,
                    "decodeRequestIds" to roleRequests.mapNotNull { request ->
                        request["decodeRequestId"]?.toString()
                    },
                    "sampleCount" to roleRequests.size,
                    "requiresExactFrameDecode" to true,
                    "allowThumbnailFallback" to false,
                    "allowBoundaryFreeze" to false,
                    "sourceProbeReady" to sourceProbeReady,
                    "videoMimeType" to (sourceProbe?.get("videoMimeType")?.toString() ?: ""),
                    "videoWidth" to ((sourceProbe?.get("videoWidth") as? Number)?.toInt() ?: 0),
                    "videoHeight" to ((sourceProbe?.get("videoHeight") as? Number)?.toInt() ?: 0),
                    "videoDurationUs" to ((sourceProbe?.get("videoDurationUs") as? Number)?.toLong() ?: 0L),
                    "videoFrameRate" to ((sourceProbe?.get("videoFrameRate") as? Number)?.toInt() ?: 0),
                    "requiresContinuousFrameStream" to true,
                    "liveDecodeWindowTimelineStartMs" to liveDecodeTimelineStartMs,
                    "liveDecodeWindowTimelineEndMs" to liveDecodeTimelineEndMs,
                    "liveDecodeWindowSourceStartMs" to liveDecodeSourceStartMs,
                    "liveDecodeWindowSourceEndMs" to liveDecodeSourceEndMs,
                    "liveDecodeWindowDurationMs" to liveDecodeWindowDurationMs,
                    "liveDecodeSourceWindowDurationMs" to sourceWindowDurationMs,
                    "liveDecodeCoverageDecodeProbeImplemented" to true,
                    "liveDecodeCoverageSourceTimesMs" to liveDecodeCoverageSourceTimesMs,
                    "liveDecodeCoverageRequestedSampleCount" to liveDecodeCoverageSourceTimesMs.size,
                    "liveDecodeCoverageDecodedSampleCount" to
                        liveCoverageProbe.samples.count { sample -> sample.canDecodeFrame },
                    "liveDecodeCoverageDecodedBufferCount" to
                        liveCoverageProbe.samples.count { sample -> sample.decodedBufferReadable },
                    "liveDecodeWindowReady" to (
                        sourceProbeReady &&
                            liveDecodeWindowDurationMs > 0L &&
                            sourceWindowDurationMs > 0L
                    ),
                    "liveDecodeStreamProbeImplemented" to true,
                    "liveDecodeStreamDecodedFrameCount" to liveStreamProbe.decodedFrameCount,
                    "liveDecodeStreamReadableBufferCount" to liveStreamProbe.readableBufferCount,
                    "liveDecodeStreamFirstFrameTimeMs" to ((liveStreamProbe.firstFrameTimeUs ?: 0L) / 1000L),
                    "liveDecodeStreamLastFrameTimeMs" to ((liveStreamProbe.lastFrameTimeUs ?: 0L) / 1000L),
                    "liveDecodeStreamMinRequiredFrameCount" to liveStreamProbe.minRequiredFrameCount,
                    "liveDecodeStreamCoverageReady" to liveStreamProbe.canDecodeStream,
                    "liveDecodeStreamProbeReason" to (liveStreamProbe.reason ?: ""),
                    "continuousSampleCoverageReady" to continuousSampleCoverageReady,
                    "liveDecodeCoverageProbeReason" to (liveCoverageProbe.reason ?: ""),
                    "liveDecodeCoverageSampleProbes" to liveCoverageProbe.samples.map { sample ->
                        mapOf(
                            "sourceTimeMs" to sample.sourceTimeMs,
                            "canDecodeFrame" to sample.canDecodeFrame,
                            "decodedFrameTimeMs" to ((sample.decodedFrameTimeUs ?: 0L) / 1000L),
                            "decodedBufferReadable" to sample.decodedBufferReadable,
                            "decodedBufferByteCount" to sample.decodedBufferByteCount,
                            "decodedBufferChecksum" to sample.decodedBufferChecksum,
                            "reason" to (sample.reason ?: ""),
                        )
                    },
                    "centerSampleSourceTimeMs" to centerSourceTimeMs,
                    "exactFrameDecodeProbeImplemented" to true,
                    "sampleDecodeProbeImplemented" to true,
                    "requestedSampleCount" to sourceSampleTimesMs.size,
                    "decodedSampleCount" to decodeProbe.samples.count { sample -> sample.canDecodeFrame },
                    "decodedBufferProbeImplemented" to true,
                    "decodedBufferCount" to decodeProbe.samples.count { sample -> sample.decodedBufferReadable },
                    "allSamplesDecodable" to decodeProbe.canDecodeAllFrames,
                    "allDecodedBuffersReadable" to decodeProbe.canReadAllBuffers,
                    "canDecodeCenterFrame" to (centerSampleProbe?.canDecodeFrame ?: false),
                    "decodedCenterFrameTimeMs" to ((centerSampleProbe?.decodedFrameTimeUs ?: 0L) / 1000L),
                    "decodedCenterBufferByteCount" to (centerSampleProbe?.decodedBufferByteCount ?: 0),
                    "decodedCenterBufferChecksum" to (centerSampleProbe?.decodedBufferChecksum ?: 0L),
                    "decodeProbeReason" to (decodeProbe.reason ?: ""),
                    "decodedOutputMimeType" to decodeProbe.outputFormatMimeType,
                    "decodedOutputWidth" to decodeProbe.outputWidth,
                    "decodedOutputHeight" to decodeProbe.outputHeight,
                    "decodeSampleProbes" to decodeProbe.samples.map { sample ->
                        mapOf(
                            "sourceTimeMs" to sample.sourceTimeMs,
                            "canDecodeFrame" to sample.canDecodeFrame,
                            "decodedFrameTimeMs" to ((sample.decodedFrameTimeUs ?: 0L) / 1000L),
                            "decodedBufferReadable" to sample.decodedBufferReadable,
                            "decodedBufferByteCount" to sample.decodedBufferByteCount,
                            "decodedBufferChecksum" to sample.decodedBufferChecksum,
                            "reason" to (sample.reason ?: ""),
                        )
                    },
                )
            }
        val decoderImplemented =
            tracks.size == 2 &&
                tracks.all { track ->
                        track["sourceProbeReady"] == true &&
                        track["liveDecodeWindowReady"] == true &&
                        track["continuousSampleCoverageReady"] == true &&
                        track["canDecodeCenterFrame"] == true &&
                        track["allSamplesDecodable"] == true &&
                        track["allDecodedBuffersReadable"] == true
                }
        val sourceUrisBound =
            tracks.all { track -> track["sourceUri"]?.toString()?.isNotBlank() == true }
        val allSourcesProbeable = sourceProbePlan["allSourcesProbeable"] == true
        val blockedReasons =
            buildList {
                if (!sourceUrisBound) {
                    add("native_video_source_uri_missing")
                }
                if (!allSourcesProbeable) {
                    add("native_video_source_probe_not_ready")
                }
                if (!decoderImplemented) {
                    add("native_dual_video_decoder_not_ready")
                }
                if (tracks.any { track -> track["liveDecodeWindowReady"] != true }) {
                    add("native_dual_video_live_decode_window_not_ready")
                }
                if (tracks.any { track -> track["continuousSampleCoverageReady"] != true }) {
                    add("native_dual_video_live_decode_not_ready")
                }
                if (tracks.any { track -> track["liveDecodeStreamCoverageReady"] != true }) {
                    add("native_dual_video_live_decode_stream_not_ready")
                }
                tracks.forEach { track ->
                    val reason = track["decodeProbeReason"]?.toString().orEmpty()
                    if (reason.isNotBlank() && track["canDecodeCenterFrame"] != true) {
                        add(reason)
                    }
                    val liveDecodeReason = track["liveDecodeCoverageProbeReason"]?.toString().orEmpty()
                    if (liveDecodeReason.isNotBlank() &&
                        track["continuousSampleCoverageReady"] != true
                    ) {
                        add(liveDecodeReason)
                    }
                    val liveStreamReason = track["liveDecodeStreamProbeReason"]?.toString().orEmpty()
                    if (liveStreamReason.isNotBlank() &&
                        track["liveDecodeStreamCoverageReady"] != true
                    ) {
                        add(liveStreamReason)
                    }
                    if (track["allSamplesDecodable"] == true &&
                        track["allDecodedBuffersReadable"] != true
                    ) {
                        add("native_exact_frame_output_buffer_not_ready")
                    }
                }
            }.distinct()
        return decodePlan +
            mapOf(
                "decoderSessionId" to "$id:decoder:$timelineTimeMs",
                "requiresDualVideoDecoder" to true,
                "requiresExactFrameDecode" to true,
                "requiresContinuousFrameStream" to true,
                "allowThumbnailFallback" to false,
                "allowBoundaryFreeze" to false,
                "decoderImplemented" to decoderImplemented,
                "sourceUrisBound" to sourceUrisBound,
                "allSourcesProbeable" to allSourcesProbeable,
                "sourceProbePlanId" to "$id:source-probe:$timelineTimeMs",
                "tracks" to tracks,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTemporalSampleAccumulator(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val decoderPlan =
            planDualVideoDecoderSession(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                appContext = appContext,
            )
        if (decoderPlan["status"] != "planned") {
            return decoderPlan
        }
        val motionBlurMode = decoderPlan["motionBlurMode"]?.toString() ?: "none"
        val shutterSampleCount =
            (decoderPlan["shutterSampleCount"] as? Number)?.toInt()?.coerceAtLeast(1) ?: 1
        val requiresTemporalAccumulation =
            motionBlurMode == "temporalShutter" && shutterSampleCount > 1
        val tracks =
            (decoderPlan["tracks"] as? List<*>)?.mapNotNull { track ->
                track as? Map<*, *>
            } ?: emptyList()
        val accumulators =
            tracks.map { track ->
                val role = track["role"]?.toString() ?: ""
                val sampleCount =
                    (track["sampleCount"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
                val decodedSampleCount =
                    (track["decodedSampleCount"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
                val decodedBufferCount =
                    (track["decodedBufferCount"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
                val inputSamplesDecodable = track["allSamplesDecodable"] == true
                val inputDecodedBuffersReadable = track["allDecodedBuffersReadable"] == true
                val liveDecodeWindowReady = track["liveDecodeWindowReady"] == true
                val liveDecodeStreamProbeImplemented =
                    track["liveDecodeStreamProbeImplemented"] == true
                val liveDecodeStreamCoverageReady =
                    track["liveDecodeStreamCoverageReady"] == true
                val continuousSampleCoverageReady =
                    track["continuousSampleCoverageReady"] == true
                val liveDecodeStreamDecodedFrameCount =
                    (track["liveDecodeStreamDecodedFrameCount"] as? Number)
                        ?.toInt()
                        ?.coerceAtLeast(0) ?: 0
                val liveDecodeStreamReadableBufferCount =
                    (track["liveDecodeStreamReadableBufferCount"] as? Number)
                        ?.toInt()
                        ?.coerceAtLeast(0) ?: 0
                val accumulatedBufferByteCount =
                    (track["decodeSampleProbes"] as? List<*>)?.mapNotNull { sample ->
                        (sample as? Map<*, *>)?.get("decodedBufferByteCount") as? Number
                    }?.sumOf { count -> count.toLong() } ?: 0L
                val accumulatedBufferChecksum =
                    (track["decodeSampleProbes"] as? List<*>)?.mapNotNull { sample ->
                        (sample as? Map<*, *>)?.get("decodedBufferChecksum") as? Number
                    }?.fold(1469598103934665603L) { checksum, sampleChecksum ->
                        (checksum xor sampleChecksum.toLong()) * 1099511628211L
                    } ?: 0L
                mapOf(
                    "accumulatorId" to "$id:accumulator:$role:$timelineTimeMs",
                    "role" to role,
                    "inputTrackRole" to role,
                    "sampleCount" to sampleCount,
                    "decodedSampleCount" to decodedSampleCount,
                    "decodedBufferCount" to decodedBufferCount,
                    "inputSamplesDecodable" to inputSamplesDecodable,
                    "inputDecodedBuffersReadable" to inputDecodedBuffersReadable,
                    "liveDecodeWindowReady" to liveDecodeWindowReady,
                    "liveDecodeStreamProbeImplemented" to liveDecodeStreamProbeImplemented,
                    "liveDecodeStreamDecodedFrameCount" to liveDecodeStreamDecodedFrameCount,
                    "liveDecodeStreamReadableBufferCount" to liveDecodeStreamReadableBufferCount,
                    "liveDecodeStreamCoverageReady" to liveDecodeStreamCoverageReady,
                    "continuousSampleCoverageReady" to continuousSampleCoverageReady,
                    "accumulatedBufferByteCount" to accumulatedBufferByteCount,
                    "accumulatedBufferChecksum" to accumulatedBufferChecksum,
                    "accumulatedFrameReady" to (
                        sampleCount > 0 &&
                            decodedSampleCount == sampleCount &&
                            decodedBufferCount == sampleCount &&
                            inputSamplesDecodable &&
                            inputDecodedBuffersReadable &&
                            liveDecodeWindowReady &&
                            liveDecodeStreamProbeImplemented &&
                            liveDecodeStreamCoverageReady &&
                            continuousSampleCoverageReady
                    ),
                    "sampleWeights" to normalizedSampleWeights(sampleCount),
                    "normalization" to "weightedAverage",
                    "requiresTemporalShutter" to requiresTemporalAccumulation,
                    "requiresExactFrameDecode" to true,
                    "allowGaussianFallback" to false,
                    "allowDecorativeSpeedLines" to false,
                )
            }
        val accumulatorImplemented =
            accumulators.size == 2 &&
                accumulators.all { accumulator ->
                    accumulator["accumulatedFrameReady"] == true
                }
        val blockedReasons =
            buildList {
                if (accumulators.any { accumulator -> accumulator["inputSamplesDecodable"] != true }) {
                    add("native_temporal_sample_decode_not_ready")
                }
                if (accumulators.any { accumulator -> accumulator["inputDecodedBuffersReadable"] != true }) {
                    add("native_temporal_sample_buffer_not_ready")
                }
                if (accumulators.any { accumulator -> accumulator["liveDecodeStreamCoverageReady"] != true }) {
                    add("native_temporal_live_decode_stream_not_ready")
                }
                if (!accumulatorImplemented) {
                    add("native_temporal_sample_accumulator_not_ready")
                }
            }
        return decoderPlan +
            mapOf(
                "temporalAccumulatorSessionId" to "$id:accumulator-session:$timelineTimeMs",
                "motionBlurMode" to motionBlurMode,
                "shutterSampleCount" to shutterSampleCount,
                "requiresTemporalAccumulation" to requiresTemporalAccumulation,
                "requiresExactFrameDecode" to true,
                "allowGaussianFallback" to false,
                "allowDecorativeSpeedLines" to false,
                "accumulatorImplemented" to accumulatorImplemented,
                "accumulators" to accumulators,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planMirrorEdgeTiling(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val accumulatorPlan =
            planTemporalSampleAccumulator(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                appContext = appContext,
            )
        if (accumulatorPlan["status"] != "planned") {
            return accumulatorPlan
        }
        val edgeMode = edgePolicy?.get("mode")?.toString() ?: "none"
        val requiresMirrorEdgeTiling = edgeMode == "mirrorTile"
        val outputScaleX = edgePolicy?.doubleValue("outputScaleX", defaultValue = 1.0) ?: 1.0
        val outputScaleY = edgePolicy?.doubleValue("outputScaleY", defaultValue = 1.0) ?: 1.0
        val accumulators =
            (accumulatorPlan["accumulators"] as? List<*>)?.mapNotNull { accumulator ->
                accumulator as? Map<*, *>
            } ?: emptyList()
        val tiles =
            accumulators.map { accumulator ->
                val role = accumulator["role"]?.toString() ?: ""
                val inputAccumulatorId = accumulator["accumulatorId"]?.toString() ?: ""
                val sampleCount =
                    (accumulator["sampleCount"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
                val decodedSampleCount =
                    (accumulator["decodedSampleCount"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
                val inputSamplesDecodable = accumulator["inputSamplesDecodable"] == true
                val accumulatedFrameReady = accumulator["accumulatedFrameReady"] == true
                val liveDecodeStreamCoverageReady =
                    accumulator["liveDecodeStreamCoverageReady"] == true
                val continuousSampleCoverageReady =
                    accumulator["continuousSampleCoverageReady"] == true
                mapOf(
                    "tileId" to "$id:mirror-tile:$role:$timelineTimeMs",
                    "role" to role,
                    "inputAccumulatorId" to inputAccumulatorId,
                    "sampleCount" to sampleCount,
                    "decodedSampleCount" to decodedSampleCount,
                    "inputSamplesDecodable" to inputSamplesDecodable,
                    "inputAccumulatedFrameReady" to accumulatedFrameReady,
                    "liveDecodeStreamCoverageReady" to liveDecodeStreamCoverageReady,
                    "continuousSampleCoverageReady" to continuousSampleCoverageReady,
                    "edgeMode" to edgeMode,
                    "outputScaleX" to outputScaleX,
                    "outputScaleY" to outputScaleY,
                    "overscanScaleX" to outputScaleX,
                    "overscanScaleY" to outputScaleY,
                    "mirrorEdges" to requiresMirrorEdgeTiling,
                    "clipToCanvas" to true,
                    "allowBlackBorders" to false,
                    "tileReady" to (
                        !requiresMirrorEdgeTiling ||
                            (
                                inputSamplesDecodable &&
                                    accumulatedFrameReady &&
                                    liveDecodeStreamCoverageReady &&
                                    continuousSampleCoverageReady
                            )
                    ),
                )
            }
        val tilerImplemented =
            !requiresMirrorEdgeTiling ||
                (
                    accumulatorPlan["accumulatorImplemented"] == true &&
                        tiles.size == 2 &&
                        tiles.all { tile -> tile["tileReady"] == true }
                )
        val blockedReasons =
            buildList {
                if (tiles.any { tile -> tile["inputSamplesDecodable"] != true }) {
                    add("native_mirror_edge_input_samples_not_ready")
                }
                if (tiles.any { tile -> tile["inputAccumulatedFrameReady"] != true }) {
                    add("native_mirror_edge_accumulator_not_ready")
                }
                if (tiles.any { tile -> tile["liveDecodeStreamCoverageReady"] != true }) {
                    add("native_mirror_edge_live_decode_stream_not_ready")
                }
                if (requiresMirrorEdgeTiling && !tilerImplemented) {
                    add("native_mirror_edge_tiler_not_ready")
                }
            }
        return accumulatorPlan +
            mapOf(
                "mirrorEdgeTilingSessionId" to "$id:mirror-edge:$timelineTimeMs",
                "edgeMode" to edgeMode,
                "outputScaleX" to outputScaleX,
                "outputScaleY" to outputScaleY,
                "requiresMirrorEdgeTiling" to requiresMirrorEdgeTiling,
                "requiresTemporalAccumulator" to true,
                "allowBlackBorders" to false,
                "allowFlutterOverlay" to false,
                "allowTimelineOverlay" to false,
                "tilerImplemented" to tilerImplemented,
                "tiles" to tiles,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planRenderPassGraph(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val tilePlan =
            planMirrorEdgeTiling(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                appContext = appContext,
            )
        if (tilePlan["status"] != "planned") {
            return tilePlan
        }
        val decodeRequests =
            (tilePlan["decodeRequests"] as? List<*>)?.mapNotNull { request ->
                request as? Map<*, *>
            } ?: emptyList()
        val decoderTracks =
            (tilePlan["tracks"] as? List<*>)?.mapNotNull { track ->
                track as? Map<*, *>
            } ?: emptyList()
        val accumulators =
            (tilePlan["accumulators"] as? List<*>)?.mapNotNull { accumulator ->
                accumulator as? Map<*, *>
            } ?: emptyList()
        val tiles =
            (tilePlan["tiles"] as? List<*>)?.mapNotNull { tile ->
                tile as? Map<*, *>
            } ?: emptyList()
        val outgoingDecodeIds = decodeRequests.idsForRole("outgoing")
        val incomingDecodeIds = decodeRequests.idsForRole("incoming")
        val allDecodeIds = outgoingDecodeIds + incomingDecodeIds
        val outgoingAccumulatorId =
            accumulators.firstOrNull { accumulator -> accumulator["role"] == "outgoing" }
                ?.get("accumulatorId")?.toString() ?: outgoingTemporalPassFallback(timelineTimeMs)
        val incomingAccumulatorId =
            accumulators.firstOrNull { accumulator -> accumulator["role"] == "incoming" }
                ?.get("accumulatorId")?.toString() ?: incomingTemporalPassFallback(timelineTimeMs)
        val edgeMode = tilePlan["edgeMode"]?.toString() ?: "none"
        val requiresMirrorEdgeTiling = tilePlan["requiresMirrorEdgeTiling"] == true
        val shutterSampleCount =
            (tilePlan["shutterSampleCount"] as? Number)?.toInt()?.coerceAtLeast(1) ?: 1
        val requiresTemporalAccumulation =
            tilePlan["motionBlurMode"] == "temporalShutter" && shutterSampleCount > 1
        val liveStreamPass = "$id:pass:live-stream-decode:$timelineTimeMs"
        val outgoingTemporalPass = "$id:pass:temporal:outgoing:$timelineTimeMs"
        val incomingTemporalPass = "$id:pass:temporal:incoming:$timelineTimeMs"
        val edgePass = "$id:pass:edge:$timelineTimeMs"
        val transitionPass = "$id:pass:transition:$definitionId:$timelineTimeMs"
        val outputPass = "$id:pass:output:$timelineTimeMs"
        val upstreamBlockedReasons =
            (tilePlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val rendererImplemented = false
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!rendererImplemented) {
                    add("native_transition_renderer_missing")
                }
            }.distinct()
        val passes = mutableListOf<Map<String, Any>>()
        passes.add(
            renderPass(
                passId = liveStreamPass,
                type = "decodeLiveVideoStreams",
                role = "both",
                inputs =
                    decoderTracks.mapNotNull { track ->
                        track["sourceUri"]?.toString()?.takeIf { sourceUri ->
                            sourceUri.isNotBlank()
                        }
                    },
                parameters =
                    mapOf(
                        "requiresContinuousFrameStream" to true,
                        "trackCount" to decoderTracks.size,
                        "tracks" to decoderTracks.map { track ->
                            mapOf(
                                "role" to (track["role"]?.toString() ?: ""),
                                "sourceUri" to (track["sourceUri"]?.toString() ?: ""),
                                "liveDecodeWindowTimelineStartMs" to
                                    (track["liveDecodeWindowTimelineStartMs"] ?: 0L),
                                "liveDecodeWindowTimelineEndMs" to
                                    (track["liveDecodeWindowTimelineEndMs"] ?: 0L),
                                "liveDecodeWindowSourceStartMs" to
                                    (track["liveDecodeWindowSourceStartMs"] ?: 0L),
                                "liveDecodeWindowSourceEndMs" to
                                    (track["liveDecodeWindowSourceEndMs"] ?: 0L),
                                "liveDecodeStreamDecodedFrameCount" to
                                    (track["liveDecodeStreamDecodedFrameCount"] ?: 0),
                                "liveDecodeStreamReadableBufferCount" to
                                    (track["liveDecodeStreamReadableBufferCount"] ?: 0),
                                "liveDecodeStreamCoverageReady" to
                                    (track["liveDecodeStreamCoverageReady"] == true),
                                "continuousSampleCoverageReady" to
                                    (track["continuousSampleCoverageReady"] == true),
                            )
                        },
                        "allowThumbnailFallback" to false,
                        "allowBoundaryFreeze" to false,
                    ),
            ),
        )
        passes.add(
            renderPass(
                passId = "$id:pass:decode:$timelineTimeMs",
                type = "decodeExactVideoFrames",
                role = "both",
                inputs = allDecodeIds,
                parameters =
                    mapOf(
                        "decodeRequestCount" to decodeRequests.size,
                        "decodeMode" to "exactVideoFrame",
                        "allowThumbnailFallback" to false,
                        "allowBoundaryFreeze" to false,
                    ),
            ),
        )
        passes.add(
            renderPass(
                passId = outgoingTemporalPass,
                type = "temporalSampleAccumulator",
                role = "outgoing",
                inputs = listOf(liveStreamPass) + outgoingDecodeIds,
                parameters =
                    mapOf(
                        "sampleCount" to outgoingDecodeIds.size,
                        "motionBlurMode" to (tilePlan["motionBlurMode"] ?: "none"),
                        "accumulatorId" to outgoingAccumulatorId,
                        "requiresContinuousFrameStream" to true,
                        "allowGaussianFallback" to false,
                        "allowDecorativeSpeedLines" to false,
                    ),
            ),
        )
        passes.add(
            renderPass(
                passId = incomingTemporalPass,
                type = "temporalSampleAccumulator",
                role = "incoming",
                inputs = listOf(liveStreamPass) + incomingDecodeIds,
                parameters =
                    mapOf(
                        "sampleCount" to incomingDecodeIds.size,
                        "motionBlurMode" to (tilePlan["motionBlurMode"] ?: "none"),
                        "accumulatorId" to incomingAccumulatorId,
                        "requiresContinuousFrameStream" to true,
                        "allowGaussianFallback" to false,
                        "allowDecorativeSpeedLines" to false,
                    ),
            ),
        )
        if (requiresMirrorEdgeTiling) {
            passes.add(
                renderPass(
                    passId = edgePass,
                    type = "mirrorEdgeTile",
                    role = "both",
                    inputs = listOf(outgoingTemporalPass, incomingTemporalPass),
                    parameters =
                        mapOf(
                            "mode" to edgeMode,
                            "tileIds" to tiles.mapNotNull { tile -> tile["tileId"]?.toString() },
                            "outputScaleX" to (tilePlan["outputScaleX"] ?: 1.0),
                            "outputScaleY" to (tilePlan["outputScaleY"] ?: 1.0),
                            "allowBlackBorders" to false,
                        ),
                ),
            )
        }
        passes.add(
            renderPass(
                passId = transitionPass,
                type = "transitionShaderEvaluation",
                role = "both",
                inputs =
                    if (requiresMirrorEdgeTiling) {
                        listOf(edgePass)
                    } else {
                        listOf(outgoingTemporalPass, incomingTemporalPass)
                    },
                parameters =
                    mapOf(
                        "definitionId" to definitionId,
                        "progress" to (tilePlan["progress"] ?: 0.0),
                        "parameters" to (parameters?.stringKeyMap() ?: emptyMap<String, Any?>()),
                    ),
            ),
        )
        passes.add(
            renderPass(
                passId = outputPass,
                type = "composeToTransitionSurface",
                role = "output",
                inputs = listOf(transitionPass),
                parameters =
                    mapOf(
                        "canvasWidth" to canvasWidth,
                        "canvasHeight" to canvasHeight,
                    ),
            ),
        )
        return tilePlan +
            mapOf(
                "renderPassGraphId" to "$id:graph:$timelineTimeMs",
                "requiresExactVideoDecode" to true,
                "requiresTemporalAccumulation" to requiresTemporalAccumulation,
                "requiresMirrorEdgeTiling" to requiresMirrorEdgeTiling,
                "requiresGpuComposition" to true,
                "rendererInputsReady" to upstreamBlockedReasons.isEmpty(),
                "rendererImplemented" to rendererImplemented,
                "passes" to passes,
                "blockedReasons" to blockedReasons,
            )
    }

    private fun normalizedSampleWeights(sampleCount: Int): List<Double> {
        if (sampleCount <= 0) {
            return emptyList()
        }
        val weight = 1.0 / sampleCount.toDouble()
        return List(sampleCount) { weight }
    }

    private fun outgoingTemporalPassFallback(timelineTimeMs: Long): String =
        "$id:accumulator:outgoing:$timelineTimeMs"

    private fun incomingTemporalPassFallback(timelineTimeMs: Long): String =
        "$id:accumulator:incoming:$timelineTimeMs"


    fun planRenderGraphExecution(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val graphPlan =
            planRenderPassGraph(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (graphPlan["status"] != "planned") {
            return graphPlan
        }
        val passes =
            (graphPlan["passes"] as? List<*>)?.mapNotNull { pass ->
                pass as? Map<*, *>
            } ?: emptyList()
        val passTypes = passes.map { pass -> pass["type"]?.toString() ?: "" }
        val requiresMirrorEdgeTiling = graphPlan["requiresMirrorEdgeTiling"] == true
        val requiredPassTypes =
            buildList {
                add("decodeLiveVideoStreams")
                add("decodeExactVideoFrames")
                add("temporalSampleAccumulator")
                add("temporalSampleAccumulator")
                if (requiresMirrorEdgeTiling) {
                    add("mirrorEdgeTile")
                }
                add("transitionShaderEvaluation")
                add("composeToTransitionSurface")
            }
        val passIndexById =
            passes.withIndex().mapNotNull { indexedPass ->
                val passId = indexedPass.value["passId"]?.toString() ?: ""
                if (passId.isBlank()) {
                    null
                } else {
                    passId to indexedPass.index
                }
            }.toMap()
        val graphOrderValid = passTypes == requiredPassTypes
        val dependencyViolations =
            passes.withIndex().flatMap { indexedPass ->
                val inputs =
                    (indexedPass.value["inputs"] as? List<*>)?.map { input ->
                        input.toString()
                    } ?: emptyList()
                val passId = indexedPass.value["passId"]?.toString() ?: ""
                inputs.mapNotNull { input ->
                    val inputIndex = passIndexById[input] ?: return@mapNotNull null
                    if (inputIndex < indexedPass.index) {
                        null
                    } else {
                        "$passId:$input"
                    }
                }
            }
        val graphDependenciesValid = dependencyViolations.isEmpty()
        val outputPass = passes.lastOrNull()
        val outputPassBound =
            outputPass?.get("type")?.toString() == "composeToTransitionSurface" &&
                outputPass?.get("role")?.toString() == "output" &&
                ((outputPass?.get("inputs") as? List<*>)?.isNotEmpty() == true)
        val graphExecutorImplemented = true
        val rendererImplemented = graphPlan["rendererImplemented"] == true
        val upstreamBlockedReasons =
            (graphPlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val graphOwnershipReady =
            graphExecutorImplemented &&
                graphOrderValid &&
                graphDependenciesValid &&
                outputPassBound
        val executionStates =
            passes.withIndex().map { indexedPass ->
                val passId = indexedPass.value["passId"]?.toString() ?: ""
                val inputs =
                    (indexedPass.value["inputs"] as? List<*>)?.map { input ->
                        input.toString()
                    } ?: emptyList()
                val passDependencyViolations =
                    inputs.mapNotNull { input ->
                        val inputIndex = passIndexById[input] ?: return@mapNotNull null
                        if (inputIndex < indexedPass.index) {
                            null
                        } else {
                            input
                        }
                    }
                val passBlockedReasons =
                    buildList {
                        if (!graphOrderValid) {
                            add("native_transition_render_graph_order_invalid")
                        }
                        if (passDependencyViolations.isNotEmpty()) {
                            add("native_transition_render_graph_dependencies_invalid")
                        }
                    }.distinct()
                mapOf(
                    "passId" to passId,
                    "type" to (indexedPass.value["type"]?.toString() ?: ""),
                    "role" to (indexedPass.value["role"]?.toString() ?: ""),
                    "index" to indexedPass.index,
                    "inputs" to inputs,
                    "readyForExecutor" to passBlockedReasons.isEmpty(),
                    "blockedReasons" to passBlockedReasons,
                )
            }
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!graphOrderValid) {
                    add("native_transition_render_graph_order_invalid")
                }
                if (!graphDependenciesValid) {
                    add("native_transition_render_graph_dependencies_invalid")
                }
                if (!outputPassBound) {
                    add("native_transition_graph_output_pass_missing")
                }
                if (!rendererImplemented) {
                    add("native_transition_render_graph_executor_renderer_missing")
                }
            }.distinct()
        return graphPlan +
            mapOf(
                "renderGraphExecutorId" to "$id:executor:$timelineTimeMs",
                "graphExecutorImplemented" to graphExecutorImplemented,
                "rendererImplemented" to rendererImplemented,
                "graphOrderValid" to graphOrderValid,
                "graphDependenciesValid" to graphDependenciesValid,
                "graphOwnershipReady" to graphOwnershipReady,
                "canExecuteGraph" to
                    (graphOwnershipReady &&
                        rendererImplemented &&
                        upstreamBlockedReasons.isEmpty()),
                "drawsPixels" to false,
                "requiredPassTypes" to requiredPassTypes,
                "executionOrder" to passes.map { pass -> pass["passId"]?.toString() ?: "" },
                "passExecutionStates" to executionStates,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planOutputSurface(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val graphPlan =
            planRenderPassGraph(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (graphPlan["status"] != "planned") {
            return graphPlan
        }
        val rendererImplemented = graphPlan["rendererImplemented"] == true
        val outputSurfaceId = "$id:surface:transition-output:$timelineTimeMs"
        val passes =
            (graphPlan["passes"] as? List<*>)?.mapNotNull { pass ->
                pass as? Map<*, *>
            } ?: emptyList()
        val outputPass =
            passes.lastOrNull { pass ->
                pass["type"]?.toString() == "composeToTransitionSurface"
            }
        val outputPassId = outputPass?.get("passId")?.toString() ?: ""
        val outputPassType = outputPass?.get("type")?.toString() ?: ""
        val outputPassInputs =
            (outputPass?.get("inputs") as? List<*>)?.map { input ->
                input.toString()
            } ?: emptyList()
        val outputPassBound =
            outputPassId.isNotBlank() &&
                outputPassType == "composeToTransitionSurface" &&
                outputPass?.get("role")?.toString() == "output" &&
                outputPassInputs.isNotEmpty()
        val upstreamBlockedReasons =
            (graphPlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!outputPassBound) {
                    add("native_transition_output_pass_missing")
                }
                if (!rendererImplemented) {
                    add("native_transition_output_surface_renderer_missing")
                }
            }.distinct()
        return graphPlan +
            mapOf(
                "outputSurfaceId" to outputSurfaceId,
                "outputTarget" to "nativeTransitionCanvasSurface",
                "canvasWidth" to canvasWidth,
                "canvasHeight" to canvasHeight,
                "clipToCanvas" to true,
                "requiresNativeTexture" to true,
                "allowFlutterOverlay" to false,
                "allowTimelineOverlay" to false,
                "allowPlatformViewTransform" to false,
                "renderPassCount" to passes.size,
                "outputPassId" to outputPassId,
                "outputPassType" to outputPassType,
                "outputPassInputs" to outputPassInputs,
                "outputPassBound" to outputPassBound,
                "renderGraphOutputReady" to (outputPassBound && upstreamBlockedReasons.isEmpty()),
                "rendererImplemented" to rendererImplemented,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planSurfaceRenderer(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val executionPlan =
            planRenderGraphExecution(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (executionPlan["status"] != "planned") {
            return executionPlan
        }
        val surfacePlan =
            planOutputSurface(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (surfacePlan["status"] != "planned") {
            return surfacePlan
        }
        val graphExecutorImplemented = executionPlan["graphExecutorImplemented"] == true
        val graphOwnershipReady = executionPlan["graphOwnershipReady"] == true
        val outputPassBound = surfacePlan["outputPassBound"] == true
        val renderGraphOutputReady = surfacePlan["renderGraphOutputReady"] == true
        val outputSurfaceId = surfacePlan["outputSurfaceId"]?.toString() ?: ""
        val outputTarget = surfacePlan["outputTarget"]?.toString() ?: ""
        val outputSurfaceAttached =
            graphExecutorImplemented &&
                graphOwnershipReady &&
                outputPassBound &&
                outputSurfaceId.isNotBlank() &&
                outputTarget == "nativeTransitionCanvasSurface"
        val surfaceRendererImplemented = true
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (
                (executionPlan["blockedReasons"] as? List<*>)?.map { reason ->
                    reason.toString()
                } ?: emptyList()
                ) +
                (
                    (surfacePlan["blockedReasons"] as? List<*>)?.map { reason ->
                        reason.toString()
                    } ?: emptyList()
                    )
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!outputSurfaceAttached) {
                    add("native_transition_surface_renderer_output_not_attached")
                }
                if (!surfaceRendererImplemented) {
                    add("native_transition_surface_renderer_missing")
                }
                if (!rendererImplemented) {
                    add("native_transition_surface_renderer_pixels_missing")
                }
            }.distinct()
        return surfacePlan +
            mapOf(
                "renderGraphExecutorId" to
                    (executionPlan["renderGraphExecutorId"]?.toString() ?: ""),
                "surfaceRendererId" to "$id:surface-renderer:$timelineTimeMs",
                "graphExecutorImplemented" to graphExecutorImplemented,
                "graphOwnershipReady" to graphOwnershipReady,
                "surfaceRendererImplemented" to surfaceRendererImplemented,
                "rendererImplemented" to rendererImplemented,
                "outputSurfaceAttached" to outputSurfaceAttached,
                "outputPassBound" to outputPassBound,
                "renderGraphOutputReady" to renderGraphOutputReady,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderSurface" to
                    (surfaceRendererImplemented &&
                        rendererImplemented &&
                        outputSurfaceAttached &&
                        renderGraphOutputReady &&
                        blockedReasons.isEmpty()),
                "blockedReasons" to blockedReasons,
            )
    }

    fun planFrameRenderCommands(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val surfacePlan =
            planSurfaceRenderer(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (surfacePlan["status"] != "planned") {
            return surfacePlan
        }
        val passes =
            (surfacePlan["passes"] as? List<*>)?.mapNotNull { pass ->
                pass as? Map<*, *>
            } ?: emptyList()
        val surfaceRendererImplemented = surfacePlan["surfaceRendererImplemented"] == true
        val outputSurfaceAttached = surfacePlan["outputSurfaceAttached"] == true
        val graphOwnershipReady = surfacePlan["graphOwnershipReady"] == true
        val outputPassBound = surfacePlan["outputPassBound"] == true
        val renderGraphOutputReady = surfacePlan["renderGraphOutputReady"] == true
        val outputSurfaceId = surfacePlan["outputSurfaceId"]?.toString() ?: ""
        val outputTarget = surfacePlan["outputTarget"]?.toString() ?: ""
        val rendererCommandBufferImplemented = true
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (surfacePlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val commands =
            passes.withIndex().map { indexedPass ->
                val pass = indexedPass.value
                val passId = pass["passId"]?.toString() ?: ""
                val passType = pass["type"]?.toString() ?: ""
                val role = pass["role"]?.toString() ?: ""
                val inputs =
                    (pass["inputs"] as? List<*>)?.map { input -> input.toString() }
                        ?: emptyList()
                val passOutputTarget =
                    if (passType == "composeToTransitionSurface") {
                        outputTarget
                    } else {
                        "nativeTransitionIntermediateBuffer"
                    }
                val blockedReasons =
                    buildList {
                        if (passId.isBlank()) {
                            add("native_transition_frame_command_pass_id_missing")
                        }
                        if (passType.isBlank()) {
                            add("native_transition_frame_command_pass_type_missing")
                        }
                        if (!surfaceRendererImplemented) {
                            add("native_transition_surface_renderer_missing")
                        }
                        if (!outputSurfaceAttached) {
                            add("native_transition_frame_command_surface_not_attached")
                        }
                        if (!rendererImplemented) {
                            add("native_transition_frame_command_renderer_missing")
                        }
                    }.distinct()
                mapOf(
                    "commandId" to "$id:command:${indexedPass.index}:$timelineTimeMs",
                    "passId" to passId,
                    "passType" to passType,
                    "role" to role,
                    "index" to indexedPass.index,
                    "inputPassIds" to inputs,
                    "outputTarget" to passOutputTarget,
                    "writesToOutputSurface" to (passType == "composeToTransitionSurface"),
                    "requiresRealPixels" to true,
                    "readyForRenderer" to
                        (surfaceRendererImplemented &&
                            outputSurfaceAttached &&
                            passId.isNotBlank() &&
                            passType.isNotBlank() &&
                            blockedReasons.none { reason ->
                                reason != "native_transition_frame_command_renderer_missing"
                            }),
                    "blockedReasons" to blockedReasons,
                )
            }
        val commandGraphComplete =
            commands.isNotEmpty() &&
                commands.last()["writesToOutputSurface"] == true &&
                commands.map { command -> command["passType"] }.containsAll(
                    listOf(
                        "decodeLiveVideoStreams",
                        "decodeExactVideoFrames",
                        "temporalSampleAccumulator",
                        "transitionShaderEvaluation",
                        "composeToTransitionSurface",
                    ),
                )
        val commandBufferReady =
            rendererCommandBufferImplemented &&
                surfaceRendererImplemented &&
                graphOwnershipReady &&
                outputSurfaceAttached &&
                outputPassBound &&
                commandGraphComplete
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!commandGraphComplete) {
                    add("native_transition_frame_command_graph_incomplete")
                }
                if (!commandBufferReady) {
                    add("native_transition_frame_command_buffer_not_ready")
                }
                if (!renderGraphOutputReady) {
                    add("native_transition_frame_command_output_not_ready")
                }
                if (!rendererImplemented) {
                    add("native_transition_frame_command_renderer_missing")
                }
            }.distinct()
        return surfacePlan +
            mapOf(
                "frameRenderCommandBufferId" to "$id:frame-command-buffer:$timelineTimeMs",
                "rendererCommandBufferImplemented" to rendererCommandBufferImplemented,
                "rendererImplemented" to rendererImplemented,
                "commandGraphComplete" to commandGraphComplete,
                "commandBufferReady" to commandBufferReady,
                "commandCount" to commands.size,
                "commands" to commands,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canSubmitCommands" to
                    (commandBufferReady &&
                        rendererImplemented &&
                        renderGraphOutputReady &&
                        blockedReasons.isEmpty()),
                "canRenderFrame" to
                    (commandBufferReady &&
                        rendererImplemented &&
                        renderGraphOutputReady &&
                        blockedReasons.isEmpty()),
                "blockedReasons" to blockedReasons,
            )
    }

    fun planRendererBackend(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val commandPlan =
            planFrameRenderCommands(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (commandPlan["status"] != "planned") {
            return commandPlan
        }
        val rendererBackendImplemented = true
        val gpuContextAvailable = isOpenGlEs20Available(appContext)
        val nativeSurfaceRequired = true
        val commandBufferReady = commandPlan["commandBufferReady"] == true
        val outputSurfaceAttached = commandPlan["outputSurfaceAttached"] == true
        val outputTarget = commandPlan["outputTarget"]?.toString() ?: ""
        val drawLoopImplemented = false
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (commandPlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val backendReady =
            rendererBackendImplemented &&
                gpuContextAvailable &&
                commandBufferReady &&
                outputSurfaceAttached &&
                outputTarget == "nativeTransitionCanvasSurface"
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!rendererBackendImplemented) {
                    add("native_transition_renderer_backend_missing")
                }
                if (!gpuContextAvailable) {
                    add("native_transition_renderer_gpu_context_unavailable")
                }
                if (!commandBufferReady) {
                    add("native_transition_renderer_command_buffer_not_ready")
                }
                if (!outputSurfaceAttached) {
                    add("native_transition_renderer_output_surface_not_attached")
                }
                if (outputTarget != "nativeTransitionCanvasSurface") {
                    add("native_transition_renderer_output_target_invalid")
                }
            }.distinct()
        return commandPlan +
            mapOf(
                "rendererBackendId" to "$id:renderer-backend:$timelineTimeMs",
                "rendererBackendImplemented" to rendererBackendImplemented,
                "gpuContextAvailable" to gpuContextAvailable,
                "nativeSurfaceRequired" to nativeSurfaceRequired,
                "commandBufferReady" to commandBufferReady,
                "outputSurfaceAttached" to outputSurfaceAttached,
                "drawLoopImplemented" to drawLoopImplemented,
                "rendererImplemented" to rendererImplemented,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "backendReady" to (backendReady && blockedReasons.isEmpty()),
                "canSubmitCommands" to (backendReady && blockedReasons.isEmpty()),
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planRendererDrawLoop(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val backendPlan =
            planRendererBackend(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (backendPlan["status"] != "planned") {
            return backendPlan
        }
        val rendererBackendReady = backendPlan["backendReady"] == true ||
            backendPlan["canSubmitCommands"] == true
        val commands =
            (backendPlan["commands"] as? List<*>)
                ?.mapNotNull { command -> command as? Map<*, *> }
                ?: emptyList()
        val drawSubmissions =
            commands.mapIndexed { index, command ->
                val commandId = command["commandId"]?.toString() ?: "command:$index"
                val outputTarget = command["outputTarget"]?.toString() ?: ""
                mapOf(
                    "submissionId" to "$id:draw-submission:$timelineTimeMs:$index",
                    "commandId" to commandId,
                    "passId" to (command["passId"]?.toString() ?: ""),
                    "passType" to (command["passType"]?.toString() ?: ""),
                    "index" to index,
                    "outputTarget" to outputTarget,
                    "writesToOutputSurface" to (command["writesToOutputSurface"] == true),
                    "requiresRealPixels" to true,
                    "submitted" to rendererBackendReady,
                    "blockedReasons" to
                        if (!rendererBackendReady) {
                            listOf("native_transition_renderer_backend_not_ready")
                        } else {
                            emptyList()
                        },
                )
            }
        val drawLoopImplemented = true
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (backendPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!rendererBackendReady) {
                    add("native_transition_renderer_backend_not_ready")
                }
                if (commands.isEmpty()) {
                    add("native_transition_renderer_command_buffer_empty")
                }
            }.distinct()
        return backendPlan +
            mapOf(
                "rendererDrawLoopId" to "$id:draw-loop:$timelineTimeMs",
                "drawLoopImplemented" to drawLoopImplemented,
                "shaderEvaluatorImplemented" to false,
                "pixelRendererImplemented" to false,
                "rendererImplemented" to rendererImplemented,
                "drawSubmissionCount" to drawSubmissions.size,
                "drawSubmissions" to drawSubmissions,
                "drawLoopReady" to
                    (drawLoopImplemented &&
                        rendererBackendReady &&
                        commands.isNotEmpty() &&
                        blockedReasons.isEmpty()),
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canSubmitCommands" to
                    (drawLoopImplemented &&
                        rendererBackendReady &&
                        commands.isNotEmpty()),
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTransitionShaderEvaluation(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val drawLoopPlan =
            planRendererDrawLoop(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (drawLoopPlan["status"] != "planned") {
            return drawLoopPlan
        }
        val drawLoopReady = drawLoopPlan["drawLoopReady"] == true ||
            drawLoopPlan["canSubmitCommands"] == true
        val drawSubmissions =
            (drawLoopPlan["drawSubmissions"] as? List<*>)
                ?.mapNotNull { submission -> submission as? Map<*, *> }
                ?: emptyList()
        val requiresTemporalSamples =
            motionBlurPolicy?.get("mode")?.toString() == "temporalShutter"
        val requiresMirrorEdgeTiling =
            edgePolicy?.get("mode")?.toString() == "mirrorTile"
        val shaderInputs =
            drawSubmissions.mapIndexed { index, submission ->
                mapOf(
                    "shaderInputId" to "$id:shader-input:$timelineTimeMs:$index",
                    "submissionId" to (submission["submissionId"]?.toString() ?: ""),
                    "commandId" to (submission["commandId"]?.toString() ?: ""),
                    "passId" to (submission["passId"]?.toString() ?: ""),
                    "passType" to (submission["passType"]?.toString() ?: ""),
                    "outputTarget" to (submission["outputTarget"]?.toString() ?: ""),
                    "requiresRealPixels" to true,
                    "inputBound" to drawLoopReady,
                )
            }
        val shaderEvaluatorImplemented = true
        val shaderProgramReady =
            shaderEvaluatorImplemented &&
                drawLoopReady &&
                shaderInputs.isNotEmpty()
        val pixelRendererImplemented = false
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (drawLoopPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!drawLoopReady) {
                    add("native_transition_renderer_draw_loop_not_ready")
                }
                if (shaderInputs.isEmpty()) {
                    add("native_transition_shader_inputs_missing")
                }
                if (!shaderEvaluatorImplemented) {
                    add("native_transition_shader_evaluator_missing")
                }
            }.distinct()
        return drawLoopPlan +
            mapOf(
                "transitionShaderEvaluationId" to "$id:shader-evaluation:$timelineTimeMs",
                "transitionShaderProgramId" to "$id:shader-program:$definitionId",
                "shaderFamily" to definitionId,
                "shaderEvaluatorImplemented" to shaderEvaluatorImplemented,
                "shaderProgramReady" to shaderProgramReady,
                "shaderInputsBound" to
                    (shaderInputs.isNotEmpty() &&
                        shaderInputs.all { input -> input["inputBound"] == true }),
                "shaderInputCount" to shaderInputs.size,
                "shaderInputs" to shaderInputs,
                "requiresTemporalSamples" to requiresTemporalSamples,
                "requiresMirrorEdgeTiling" to requiresMirrorEdgeTiling,
                "pixelRendererImplemented" to pixelRendererImplemented,
                "rendererImplemented" to rendererImplemented,
                "canEvaluateShader" to
                    (shaderProgramReady &&
                        blockedReasons.none { reason ->
                            reason == "native_transition_renderer_draw_loop_not_ready" ||
                                reason == "native_transition_shader_inputs_missing" ||
                                reason == "native_transition_shader_evaluator_missing"
                        }),
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTransitionPixelRenderer(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val shaderPlan =
            planTransitionShaderEvaluation(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (shaderPlan["status"] != "planned") {
            return shaderPlan
        }
        val shaderReady = shaderPlan["canEvaluateShader"] == true
        val shaderInputs =
            (shaderPlan["shaderInputs"] as? List<*>)
                ?.mapNotNull { input -> input as? Map<*, *> }
                ?: emptyList()
        val pixelInputs =
            shaderInputs.mapIndexed { index, input ->
                mapOf(
                    "pixelInputId" to "$id:pixel-input:$timelineTimeMs:$index",
                    "shaderInputId" to (input["shaderInputId"]?.toString() ?: ""),
                    "submissionId" to (input["submissionId"]?.toString() ?: ""),
                    "commandId" to (input["commandId"]?.toString() ?: ""),
                    "passId" to (input["passId"]?.toString() ?: ""),
                    "passType" to (input["passType"]?.toString() ?: ""),
                    "outputTarget" to (input["outputTarget"]?.toString() ?: ""),
                    "requiresRealPixels" to true,
                    "inputBound" to (shaderReady && input["inputBound"] == true),
                )
            }
        val pixelWorkloadBound =
            shaderReady &&
                pixelInputs.isNotEmpty() &&
                pixelInputs.all { input -> input["inputBound"] == true }
        val upstreamBlockedReasons =
            (shaderPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!shaderReady) {
                    add("native_transition_shader_evaluation_not_ready")
                }
                if (pixelInputs.isEmpty()) {
                    add("native_transition_pixel_inputs_missing")
                }
            }.distinct()
        return shaderPlan +
            mapOf(
                "transitionPixelRendererId" to "$id:pixel-renderer:$timelineTimeMs",
                "pixelProgramId" to "$id:pixel-program:$definitionId",
                "pixelWorkloadBound" to pixelWorkloadBound,
                "pixelInputCount" to pixelInputs.size,
                "pixelInputs" to pixelInputs,
                "pixelRendererImplemented" to false,
                "pixelRendererReady" to false,
                "rendererImplemented" to false,
                "canRenderPixels" to false,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTransitionPixelRenderExecution(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): Map<String, Any> {
        val writerPlan =
            planTransitionPixelFrameBufferWriter(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
                frameBufferStore = frameBufferStore,
            )
        if (writerPlan["status"] != "planned") {
            return writerPlan
        }
        val pixelWorkloadBound = writerPlan["pixelWorkloadBound"] == true
        val outputFramebufferBound = writerPlan["outputFramebufferBound"] == true
        val frameBufferReady = writerPlan["frameBufferReady"] == true
        val writerReady = writerPlan["writerReady"] == true
        val canWriteTemporalPixels = writerPlan["canWriteTemporalPixels"] == true
        val wroteTemporalPixels = writerPlan["wroteTemporalPixels"] == true
        val frameBufferContainsRealPixels =
            writerPlan["frameBufferContainsRealPixels"] == true
        val sourceFrameBufferId = writerPlan["transitionPixelFrameBufferId"]?.toString() ?: ""
        val sourceFrameBufferByteCount =
            (writerPlan["writerFrameBufferWriteByteCount"] as? Number)?.toLong() ?: 0L
        val sourceFrameBufferChecksum =
            (writerPlan["writerFrameBufferChecksum"] as? Number)?.toLong() ?: 0L
        val pixelOutputWritten =
            pixelWorkloadBound &&
                outputFramebufferBound &&
                frameBufferReady &&
                writerReady &&
                canWriteTemporalPixels &&
                wroteTemporalPixels &&
                frameBufferContainsRealPixels &&
                sourceFrameBufferId.isNotBlank() &&
                sourceFrameBufferByteCount > 0L
        val pixelRendererImplemented = pixelOutputWritten
        val pixelRendererReady = pixelOutputWritten
        val pixelRenderExecutionReady = pixelOutputWritten
        val pixelOutputReady = false
        val rendererImplemented = writerPlan["rendererImplemented"] == true
        val upstreamBlockedReasons =
            (writerPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?.filterNot { reason -> reason == "native_transition_pixel_renderer_missing" }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!pixelWorkloadBound) {
                    add("native_transition_pixel_workload_not_ready")
                }
                if (!outputFramebufferBound) {
                    add("native_transition_output_framebuffer_not_bound")
                }
                if (!frameBufferReady) {
                    add("native_transition_pixel_frame_buffer_not_ready")
                }
                if (!writerReady || !canWriteTemporalPixels) {
                    add("native_transition_pixel_frame_buffer_writer_missing")
                }
                if (!wroteTemporalPixels) {
                    add("native_transition_pixel_frame_buffer_temporal_pixels_missing")
                }
                if (!frameBufferContainsRealPixels) {
                    add("native_transition_pixel_frame_buffer_pixels_missing")
                }
                if (!pixelRendererImplemented) {
                    add("native_transition_pixel_renderer_missing")
                }
                if (!pixelOutputWritten) {
                    add("native_transition_pixel_output_missing")
                }
                if (!pixelOutputReady) {
                    add("native_transition_pixel_output_not_ready")
                }
                if (!rendererImplemented) {
                    add("native_transition_renderer_pixels_missing")
                }
            }.distinct()
        return writerPlan +
            mapOf(
                "transitionPixelRenderExecutionId" to "$id:pixel-render-execution:$timelineTimeMs",
                "pixelOutputFrameId" to "$id:pixel-output-frame:$timelineTimeMs",
                "outputFramebufferTarget" to "nativeTransitionCanvasSurface",
                "pixelWorkloadBound" to pixelWorkloadBound,
                "outputFramebufferBound" to outputFramebufferBound,
                "pixelRendererImplemented" to pixelRendererImplemented,
                "pixelRendererReady" to pixelRendererReady,
                "pixelRenderExecutionReady" to pixelRenderExecutionReady,
                "pixelOutputWritten" to pixelOutputWritten,
                "pixelOutputReady" to pixelOutputReady,
                "pixelOutputSourceFrameBufferId" to sourceFrameBufferId,
                "pixelOutputWriteMode" to "offscreenTemporalFrameBuffer",
                "pixelOutputByteCount" to sourceFrameBufferByteCount,
                "pixelOutputChecksum" to sourceFrameBufferChecksum,
                "pixelOutputReason" to
                    if (pixelOutputWritten) {
                        ""
                    } else {
                        "native_transition_pixel_output_missing"
                    },
                "rendererImplemented" to rendererImplemented,
                "canRenderPixels" to false,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTransitionPixelFrameBufferWriter(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): Map<String, Any> {
        val frameBufferPlan =
            planTransitionPixelFrameBuffer(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
                frameBufferStore = frameBufferStore,
            )
        if (frameBufferPlan["status"] != "planned") {
            return frameBufferPlan
        }
        val pixelWorkloadBound = frameBufferPlan["pixelWorkloadBound"] == true
        val outputFramebufferBound = frameBufferPlan["outputFramebufferBound"] == true
        val frameBufferAllocated = frameBufferPlan["frameBufferAllocated"] == true
        val frameBufferReady = frameBufferPlan["frameBufferReady"] == true
        val writerBoundToFrameBuffer =
            pixelWorkloadBound &&
                outputFramebufferBound &&
                frameBufferAllocated &&
                frameBufferReady
        val requiresTemporalSamples = true
        val requiresDualSourceSamples = sourceRoles.size >= 2
        val frameBufferId = frameBufferPlan["transitionPixelFrameBufferId"]?.toString() ?: ""
        val writeResult =
            if (writerBoundToFrameBuffer && frameBufferId.isNotBlank()) {
                writeTemporalVideoPixelsToFrameBuffer(
                    appContext = appContext,
                    frameBufferStore = frameBufferStore,
                    frameBufferId = frameBufferId,
                    timelineTimeMs = timelineTimeMs,
                    motionBlurPolicy = motionBlurPolicy,
                )
            } else {
                ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = 0,
                    extractedFrameCount = 0,
                    reason = "native_transition_pixel_frame_buffer_writer_not_bound",
                )
            }
        val writerImplemented = writerBoundToFrameBuffer
        val writerReady = writeResult.wrotePixels
        val canWriteTemporalPixels = writeResult.wrotePixels
        val wroteTemporalPixels = writeResult.wrotePixels
        val frameBufferContainsRealPixels = writeResult.wrotePixels
        val upstreamBlockedReasons =
            (frameBufferPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?.filterNot { reason ->
                    reason == "native_transition_pixel_frame_buffer_pixels_missing" ||
                        reason == "native_transition_pixel_frame_buffer_renderer_missing"
                }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!writerBoundToFrameBuffer) {
                    add("native_transition_pixel_frame_buffer_writer_not_bound")
                }
                if (requiresTemporalSamples && !canWriteTemporalPixels) {
                    add("native_transition_pixel_frame_buffer_writer_missing")
                }
                if (requiresDualSourceSamples && !wroteTemporalPixels) {
                    add("native_transition_pixel_frame_buffer_temporal_pixels_missing")
                }
                if (!frameBufferContainsRealPixels) {
                    add("native_transition_pixel_frame_buffer_pixels_missing")
                }
                if (!writeResult.reason.isNullOrBlank()) {
                    add(writeResult.reason)
                }
            }.distinct()
        return frameBufferPlan +
            mapOf(
                "transitionPixelFrameBufferWriterId" to "$id:pixel-frame-buffer-writer:$timelineTimeMs",
                "writerBoundToFrameBuffer" to writerBoundToFrameBuffer,
                "requiresTemporalSamples" to requiresTemporalSamples,
                "requiresDualSourceSamples" to requiresDualSourceSamples,
                "allowsStillFrameWrite" to false,
                "allowsSyntheticPixels" to false,
                "allowsPosterFrame" to false,
                "allowsThumbnailFallback" to false,
                "allowsBoundaryFreeze" to false,
                "writerImplemented" to writerImplemented,
                "writerReady" to writerReady,
                "canWriteTemporalPixels" to canWriteTemporalPixels,
                "wroteTemporalPixels" to wroteTemporalPixels,
                "frameBufferContainsRealPixels" to frameBufferContainsRealPixels,
                "writerTemporalSampleCount" to writeResult.sampleCount,
                "writerExtractedFrameCount" to writeResult.extractedFrameCount,
                "writerFrameBufferWriteByteCount" to writeResult.byteCount,
                "writerFrameBufferChecksum" to writeResult.checksum,
                "writerSourceFrameExtractor" to "MediaMetadataRetriever.getFrameAtTime",
                "writerCanvasFillMode" to "centerCropFill",
                "writerReason" to (writeResult.reason ?: ""),
                "pixelRendererImplemented" to false,
                "pixelRendererReady" to false,
                "rendererImplemented" to false,
                "canRenderPixels" to false,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    private fun writeTemporalVideoPixelsToFrameBuffer(
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
        frameBufferId: String,
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
    ): ProfessionalVideoTransitionPixelFrameBufferWriteResult {
        val width = canvasWidth.toInt()
        val height = canvasHeight.toInt()
        if (width <= 0 || height <= 0) {
            return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                wrotePixels = false,
                byteCount = 0,
                checksum = 0L,
                sampleCount = 0,
                extractedFrameCount = 0,
                reason = "native_transition_pixel_frame_buffer_invalid_size",
            )
        }
        val timelineSamples = temporalSampleTimelineTimes(timelineTimeMs, motionBlurPolicy)
        if (timelineSamples.isEmpty()) {
            return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                wrotePixels = false,
                byteCount = 0,
                checksum = 0L,
                sampleCount = 0,
                extractedFrameCount = 0,
                reason = "native_transition_temporal_samples_missing",
            )
        }
        val progress =
            ((timelineTimeMs - transitionStartMs).toDouble() /
                (transitionEndMs - transitionStartMs).coerceAtLeast(1L).toDouble())
                .coerceIn(0.0, 1.0)
        val outgoingAlphaBase = ((1.0 - progress) * 255.0).roundToInt().coerceIn(0, 255)
        val incomingAlphaBase = (progress * 255.0).roundToInt().coerceIn(0, 255)
        val canvasBitmap =
            runCatching {
                Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            }.getOrNull()
                ?: return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = 0,
                    reason = "native_transition_pixel_frame_buffer_bitmap_allocation_failed",
                )
        var extractedFrameCount = 0
        var outgoingFrameCount = 0
        var incomingFrameCount = 0
        try {
            val canvas = Canvas(canvasBitmap)
            canvas.drawColor(Color.BLACK)
            val sampleCount = timelineSamples.size.coerceAtLeast(1)
            val outgoingAlpha = temporalSampleAlpha(outgoingAlphaBase, sampleCount)
            val incomingAlpha = temporalSampleAlpha(incomingAlphaBase, sampleCount)
            timelineSamples.forEach { sampleTimelineMs ->
                if (outgoingAlpha > 0 && outgoing.coversTimelineTime(sampleTimelineMs)) {
                    val sourceTimeMs = outgoing.sourceTimeForTimelineTime(sampleTimelineMs)
                    val frame = extractVideoFrameBitmap(appContext, outgoing.sourceUri, sourceTimeMs)
                    if (frame != null) {
                        drawBitmapCenterCrop(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = outgoingAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                        )
                        extractedFrameCount += 1
                        outgoingFrameCount += 1
                        frame.recycle()
                    }
                }
                if (incomingAlpha > 0 && incoming.coversTimelineTime(sampleTimelineMs)) {
                    val sourceTimeMs = incoming.sourceTimeForTimelineTime(sampleTimelineMs)
                    val frame = extractVideoFrameBitmap(appContext, incoming.sourceUri, sourceTimeMs)
                    if (frame != null) {
                        drawBitmapCenterCrop(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = incomingAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                        )
                        extractedFrameCount += 1
                        incomingFrameCount += 1
                        frame.recycle()
                    }
                }
            }
            if (outgoingFrameCount <= 0 || incomingFrameCount <= 0) {
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = extractedFrameCount,
                    reason = "native_transition_temporal_dual_source_pixels_missing",
                )
            }
            return frameBufferStore.writeBitmap(
                frameBufferId = frameBufferId,
                bitmap = canvasBitmap,
                sampleCount = timelineSamples.size,
                extractedFrameCount = extractedFrameCount,
            )
        } finally {
            canvasBitmap.recycle()
        }
    }

    private fun temporalSampleAlpha(
        baseAlpha: Int,
        sampleCount: Int,
    ): Int {
        if (baseAlpha <= 0) {
            return 0
        }
        return (baseAlpha / sampleCount.toDouble()).roundToInt().coerceIn(1, 255)
    }

    private fun extractVideoFrameBitmap(
        appContext: Context,
        sourceUri: String?,
        sourceTimeMs: Long,
    ): Bitmap? {
        if (sourceUri.isNullOrBlank()) {
            return null
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(appContext, Uri.parse(sourceUri))
            retriever.getFrameAtTime(
                sourceTimeMs.coerceAtLeast(0L) * 1000L,
                MediaMetadataRetriever.OPTION_CLOSEST,
            )
        } catch (_: SecurityException) {
            null
        } catch (_: Throwable) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun drawBitmapCenterCrop(
        canvas: Canvas,
        bitmap: Bitmap,
        alpha: Int,
        canvasWidth: Int,
        canvasHeight: Int,
    ) {
        if (alpha <= 0 || bitmap.width <= 0 || bitmap.height <= 0) {
            return
        }
        val bitmapRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        val canvasRatio = canvasWidth.toFloat() / canvasHeight.toFloat()
        val sourceRect =
            if (bitmapRatio > canvasRatio) {
                val cropWidth = (bitmap.height * canvasRatio).roundToInt().coerceAtLeast(1)
                val left = ((bitmap.width - cropWidth) / 2).coerceAtLeast(0)
                Rect(left, 0, (left + cropWidth).coerceAtMost(bitmap.width), bitmap.height)
            } else {
                val cropHeight = (bitmap.width / canvasRatio).roundToInt().coerceAtLeast(1)
                val top = ((bitmap.height - cropHeight) / 2).coerceAtLeast(0)
                Rect(0, top, bitmap.width, (top + cropHeight).coerceAtMost(bitmap.height))
            }
        val destinationRect = RectF(0f, 0f, canvasWidth.toFloat(), canvasHeight.toFloat())
        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
                this.alpha = alpha.coerceIn(0, 255)
            }
        canvas.drawBitmap(bitmap, sourceRect, destinationRect, paint)
    }

    fun planTransitionPixelFrameBuffer(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): Map<String, Any> {
        val pixelPlan =
            planTransitionPixelRenderer(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (pixelPlan["status"] != "planned") {
            return pixelPlan
        }
        val pixelWorkloadBound = pixelPlan["pixelWorkloadBound"] == true
        val outputTarget = pixelPlan["outputTarget"]?.toString() ?: ""
        val outputFramebufferBound =
            pixelWorkloadBound &&
                outputTarget == "nativeTransitionCanvasSurface" &&
                canvasWidth > 0 &&
                canvasHeight > 0
        val frameBufferFormat = "rgba8888"
        val allocation =
            if (outputFramebufferBound) {
                frameBufferStore.allocate(
                    renderSessionId = id,
                    timelineTimeMs = timelineTimeMs,
                    width = canvasWidth.toInt(),
                    height = canvasHeight.toInt(),
                    format = frameBufferFormat,
                )
            } else {
                ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                    frameBufferId = "$id:pixel-frame-buffer:$timelineTimeMs",
                    reason = "native_transition_output_framebuffer_not_bound",
                )
            }
        val frameBufferByteCount = allocation.byteCount
        val frameBufferAllocated = allocation.allocated
        val frameBufferContainsRealPixels = false
        val pixelRendererImplemented = false
        val rendererImplemented = false
        val upstreamBlockedReasons =
            (pixelPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!pixelWorkloadBound) {
                    add("native_transition_pixel_workload_not_ready")
                }
                if (!outputFramebufferBound) {
                    add("native_transition_output_framebuffer_not_bound")
                }
                if (!frameBufferAllocated) {
                    add(allocation.reason ?: "native_transition_pixel_frame_buffer_missing")
                }
                if (!frameBufferContainsRealPixels) {
                    add("native_transition_pixel_frame_buffer_pixels_missing")
                }
                if (!pixelRendererImplemented) {
                    add("native_transition_pixel_frame_buffer_renderer_missing")
                }
            }.distinct()
        return pixelPlan +
            mapOf(
                "transitionPixelFrameBufferId" to allocation.frameBufferId,
                "outputFramebufferTarget" to "nativeTransitionCanvasSurface",
                "frameBufferWidth" to allocation.width,
                "frameBufferHeight" to allocation.height,
                "frameBufferFormat" to frameBufferFormat,
                "frameBufferByteCount" to frameBufferByteCount,
                "pixelWorkloadBound" to pixelWorkloadBound,
                "outputFramebufferBound" to outputFramebufferBound,
                "pixelRendererImplemented" to pixelRendererImplemented,
                "pixelRendererReady" to false,
                "frameBufferAllocated" to frameBufferAllocated,
                "frameBufferReady" to frameBufferAllocated,
                "frameBufferContainsRealPixels" to frameBufferContainsRealPixels,
                "frameBufferMemoryClass" to allocation.memoryClass,
                "frameBufferAllocationReason" to (allocation.reason ?: ""),
                "allowsSyntheticPixels" to false,
                "allowsPosterFrame" to false,
                "allowsThumbnailFallback" to false,
                "allowsBoundaryFreeze" to false,
                "rendererImplemented" to rendererImplemented,
                "canRenderPixels" to false,
                "rendersRealPixels" to false,
                "drawsPixels" to false,
                "canRenderFrame" to false,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planTransitionPixelOutputProof(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): Map<String, Any> {
        val executionPlan =
            planTransitionPixelRenderExecution(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
                frameBufferStore = frameBufferStore,
            )
        if (executionPlan["status"] != "planned") {
            return executionPlan
        }
        val outputTarget = executionPlan["outputTarget"]?.toString() ?: ""
        val outputFramebufferTarget =
            executionPlan["outputFramebufferTarget"]?.toString() ?: ""
        val outputSurfaceIsNative =
            outputTarget == "nativeTransitionCanvasSurface" &&
                outputFramebufferTarget == "nativeTransitionCanvasSurface"
        val writesOnlyToNativeSurface = outputSurfaceIsNative
        val forbidsFlutterOverlay = true
        val forbidsTimelineOverlay = true
        val forbidsPlatformViewTransform = true
        val pixelOutputWritten = executionPlan["pixelOutputWritten"] == true
        val pixelOutputReady = executionPlan["pixelOutputReady"] == true
        val pixelOutputSourceFrameBufferId =
            executionPlan["pixelOutputSourceFrameBufferId"]?.toString() ?: ""
        val pixelOutputByteCount =
            (executionPlan["pixelOutputByteCount"] as? Number)?.toLong() ?: 0L
        val pixelOutputChecksum =
            (executionPlan["pixelOutputChecksum"] as? Number)?.toLong() ?: 0L
        val outputSurfaceUploadPacketReady =
            pixelOutputWritten &&
                outputSurfaceIsNative &&
                writesOnlyToNativeSurface &&
                pixelOutputSourceFrameBufferId.isNotBlank() &&
                pixelOutputByteCount > 0L
        val outputSurfaceUploadPacketId =
            if (outputSurfaceUploadPacketReady) {
                "$id:surface-upload-packet:$timelineTimeMs"
            } else {
                ""
            }
        val surfaceUploadRendererImplemented = false
        val outputSurfaceUploadReason =
            when {
                !outputSurfaceUploadPacketReady ->
                    "native_transition_surface_upload_packet_missing"
                !surfaceUploadRendererImplemented ->
                    "native_transition_surface_upload_renderer_missing"
                else -> ""
            }
        val pixelRenderExecutionReady =
            executionPlan["pixelRenderExecutionReady"] == true &&
                executionPlan["canRenderPixels"] == true &&
                executionPlan["rendersRealPixels"] == true &&
                executionPlan["drawsPixels"] == true
        val outputProofReady =
            pixelRenderExecutionReady &&
                pixelOutputWritten &&
                pixelOutputReady &&
                outputSurfaceIsNative &&
                writesOnlyToNativeSurface
        val upstreamBlockedReasons =
            (executionPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?: emptyList()
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!pixelRenderExecutionReady) {
                    add("native_transition_pixel_render_execution_not_ready")
                }
                if (!pixelOutputWritten) {
                    add("native_transition_pixel_output_missing")
                }
                if (!pixelOutputReady) {
                    add("native_transition_pixel_output_not_ready")
                }
                if (!outputSurfaceUploadPacketReady) {
                    add("native_transition_surface_upload_packet_missing")
                }
                if (!surfaceUploadRendererImplemented) {
                    add("native_transition_surface_upload_renderer_missing")
                }
                if (!outputSurfaceIsNative) {
                    add("native_transition_output_surface_not_native")
                }
                if (!writesOnlyToNativeSurface) {
                    add("native_transition_output_surface_fallback_forbidden")
                }
                if (!outputProofReady) {
                    add("native_transition_pixel_output_proof_missing")
                }
            }.distinct()
        return executionPlan +
            mapOf(
                "transitionPixelOutputProofId" to "$id:pixel-output-proof:$timelineTimeMs",
                "outputSurfaceIsNative" to outputSurfaceIsNative,
                "writesOnlyToNativeSurface" to writesOnlyToNativeSurface,
                "forbidsFlutterOverlay" to forbidsFlutterOverlay,
                "forbidsTimelineOverlay" to forbidsTimelineOverlay,
                "forbidsPlatformViewTransform" to forbidsPlatformViewTransform,
                "outputSurfaceUploadPacketId" to outputSurfaceUploadPacketId,
                "outputSurfaceUploadPacketReady" to outputSurfaceUploadPacketReady,
                "outputSurfaceUploadSourceFrameBufferId" to pixelOutputSourceFrameBufferId,
                "outputSurfaceUploadByteCount" to pixelOutputByteCount,
                "outputSurfaceUploadChecksum" to pixelOutputChecksum,
                "surfaceUploadRendererImplemented" to surfaceUploadRendererImplemented,
                "outputSurfaceUploadReason" to outputSurfaceUploadReason,
                "pixelRenderExecutionReady" to pixelRenderExecutionReady,
                "pixelOutputWritten" to pixelOutputWritten,
                "pixelOutputReady" to pixelOutputReady,
                "outputProofReady" to outputProofReady,
                "rendererImplemented" to (executionPlan["rendererImplemented"] == true),
                "canRenderPixels" to outputProofReady,
                "rendersRealPixels" to outputProofReady,
                "drawsPixels" to outputProofReady,
                "canRenderFrame" to outputProofReady,
                "blockedReasons" to blockedReasons,
            )
    }

    fun planParityOutputs(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
        appContext: Context,
    ): Map<String, Any> {
        val surfacePlan =
            planOutputSurface(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
            )
        if (surfacePlan["status"] != "planned") {
            return surfacePlan
        }
        val rendererImplemented = surfacePlan["rendererImplemented"] == true
        val outputSurfaceId = surfacePlan["outputSurfaceId"]?.toString() ?: ""
        val outputTarget = surfacePlan["outputTarget"]?.toString() ?: ""
        val outputPassId = surfacePlan["outputPassId"]?.toString() ?: ""
        val outputPassType = surfacePlan["outputPassType"]?.toString() ?: ""
        val outputPassInputs =
            (surfacePlan["outputPassInputs"] as? List<*>)?.map { input ->
                input.toString()
            } ?: emptyList()
        val outputPassBound = surfacePlan["outputPassBound"] == true
        val renderGraphOutputReady = surfacePlan["renderGraphOutputReady"] == true
        val upstreamBlockedReasons =
            (surfacePlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val parityModes = listOf("preview", "liveScrub", "playback")
        val outputs =
            parityModes.map { mode ->
                val blockedReasons =
                    buildList {
                        if (!outputPassBound) {
                            add("native_transition_${mode}_output_pass_missing")
                        }
                        if (!rendererImplemented) {
                            add("native_transition_${mode}_renderer_missing")
                        }
                    }.distinct()
                mapOf(
                    "mode" to mode,
                    "outputSurfaceId" to outputSurfaceId,
                    "outputTarget" to outputTarget,
                    "outputPassId" to outputPassId,
                    "outputPassType" to outputPassType,
                    "outputPassInputs" to outputPassInputs,
                    "outputPassBound" to outputPassBound,
                    "renderGraphOutputReady" to renderGraphOutputReady,
                    "rendererImplemented" to rendererImplemented,
                    "canRender" to
                        (rendererImplemented &&
                            outputPassBound &&
                            renderGraphOutputReady &&
                            blockedReasons.isEmpty()),
                    "blockedReasons" to blockedReasons,
                )
            }
        val blockedReasons =
            (upstreamBlockedReasons +
                outputs.flatMap { output ->
                    (output["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                        ?: emptyList()
                }).distinct()
        return surfacePlan +
            mapOf(
                "sameOutputContractForAllModes" to
                    (outputSurfaceId.isNotBlank() &&
                        outputPassBound &&
                        outputs.map { output -> output["outputPassId"] }.distinct().size == 1),
                "exportDeferred" to true,
                "allModesRenderable" to
                    (rendererImplemented &&
                        outputPassBound &&
                        renderGraphOutputReady &&
                        blockedReasons.isEmpty()),
                "outputs" to outputs,
                "blockedReasons" to blockedReasons,
            )
    }

    private fun renderPass(
        passId: String,
        type: String,
        role: String,
        inputs: List<String>,
        parameters: Map<String, Any?>,
    ): Map<String, Any> =
        mapOf(
            "passId" to passId,
            "type" to type,
            "role" to role,
            "inputs" to inputs,
            "parameters" to parameters,
        )

    private fun sourceBinding(
        role: String,
        source: ProfessionalVideoTransitionRenderSource,
    ): Map<String, Any> =
        mapOf(
            "role" to role,
            "clipId" to source.clipId,
            "assetId" to source.assetId,
            "sourceUri" to (source.sourceUri ?: ""),
            "sourceUriBound" to !source.sourceUri.isNullOrBlank(),
            "timelineStartMs" to source.timelineStartMs,
            "timelineEndMs" to source.timelineEndMs,
            "sourceStartMs" to source.sourceStartMs,
            "sourceDurationMs" to source.sourceDurationMs,
            "requiresConcreteSourceUri" to true,
            "allowAssetIdOnlyDecode" to false,
            "allowGeneratedProxyDecode" to false,
        )

    private fun decodeRequestsForSource(
        role: String,
        source: ProfessionalVideoTransitionRenderSource,
        timelineSamples: List<Long>,
        sourceSamples: List<Long>,
        centerSampleIndex: Int,
    ): List<Map<String, Any>> {
        return timelineSamples.mapIndexed { index, timelineSampleMs ->
            val sourceSampleMs = sourceSamples.getOrElse(index) {
                source.sourceTimeForTimelineTime(timelineSampleMs)
            }
            mapOf(
                "decodeRequestId" to "$id:$role:$index:$sourceSampleMs",
                "role" to role,
                "clipId" to source.clipId,
                "assetId" to source.assetId,
                "sourceUri" to (source.sourceUri ?: ""),
                "sampleIndex" to index,
                "timelineTimeMs" to timelineSampleMs,
                "sourceTimeMs" to sourceSampleMs,
                "decodeMode" to "exactVideoFrame",
                "temporalSample" to true,
                "centerSample" to (index == centerSampleIndex),
                "allowThumbnailFallback" to false,
                "allowBoundaryFreeze" to false,
            )
        }
    }

    private fun temporalSampleTimelineTimes(
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
    ): List<Long> {
        val mode = motionBlurPolicy?.get("mode")?.toString()
        val shutterAngleDegrees =
            motionBlurPolicy?.doubleValue("shutterAngleDegrees", defaultValue = 0.0)
                ?.coerceIn(0.0, 720.0) ?: 0.0
        val frameRate =
            motionBlurPolicy?.doubleValue("frameRate", defaultValue = 30.0)
                ?.takeIf { value -> value.isFinite() && value > 0.0 } ?: 30.0
        val sampleCount =
            motionBlurPolicy?.intValue("sampleCount", defaultValue = 1)
                ?.coerceIn(1, 32) ?: 1
        val clampedTimelineTimeMs = timelineTimeMs.coerceIn(transitionStartMs, transitionEndMs)
        if (mode != "temporalShutter" || sampleCount == 1 || shutterAngleDegrees <= 0.0) {
            return listOf(clampedTimelineTimeMs)
        }
        val exposureMs = (shutterAngleDegrees / (360.0 * frameRate)) * 1000.0
        if (!exposureMs.isFinite() || exposureMs <= 0.0) {
            return listOf(clampedTimelineTimeMs)
        }
        val firstOffsetMs = -exposureMs / 2.0
        val stepMs = exposureMs / (sampleCount - 1).toDouble()
        return List(sampleCount) { index ->
            val sampleTimeMs = timelineTimeMs + firstOffsetMs + (stepMs * index)
            Math.round(sampleTimeMs).coerceIn(transitionStartMs, transitionEndMs)
        }
    }

    private fun liveDecodeCoverageSourceTimes(
        sourceStartMs: Long,
        sourceEndMs: Long,
        frameRate: Int?,
    ): List<Long> {
        val startMs = minOf(sourceStartMs, sourceEndMs).coerceAtLeast(0L)
        val endExclusiveMs = maxOf(sourceStartMs, sourceEndMs).coerceAtLeast(startMs)
        val frameDurationMs =
            (1000L / (frameRate ?: 30).coerceAtLeast(1).toLong()).coerceAtLeast(1L)
        if (endExclusiveMs <= startMs) {
            return emptyList()
        }
        val lastSampleMs = (endExclusiveMs - frameDurationMs).coerceAtLeast(startMs)
        if (lastSampleMs == startMs) {
            return listOf(startMs)
        }
        val middleSampleMs = startMs + ((lastSampleMs - startMs) / 2L)
        return listOf(startMs, middleSampleMs, lastSampleMs).distinct()
    }

    companion object {
        fun fromPlan(plan: Map<String, Any?>?): ProfessionalVideoTransitionRenderSessionParseResult {
            if (plan == null) {
                return invalid("plan", "Render plan is missing.")
            }
            val issues = mutableListOf<Map<String, Any>>()
            val definitionId = plan.stringValue("definitionId")
            val transitionId = plan.stringValue("transitionId")
            val canvasWidth = plan.longValue("canvasWidth")
            val canvasHeight = plan.longValue("canvasHeight")
            val boundaryTimeMs = plan.longValue("boundaryTimeMs")
            val leadingDurationMs = plan.longValue("leadingDurationMs")
            val trailingDurationMs = plan.longValue("trailingDurationMs")

            if (definitionId.isBlank()) {
                issues.add(issue("definitionId", "Transition definition id is required."))
            }
            if (transitionId.isBlank()) {
                issues.add(issue("transitionId", "Transition id is required."))
            }
            if (canvasWidth <= 0L || canvasHeight <= 0L) {
                issues.add(issue("canvas", "Canvas width and height must be positive."))
            }
            if (boundaryTimeMs < 0L) {
                issues.add(issue("boundaryTimeMs", "Boundary time must be non-negative."))
            }
            if (leadingDurationMs < 0L || trailingDurationMs < 0L) {
                issues.add(issue("duration", "Leading and trailing durations must be non-negative."))
            }
            if (leadingDurationMs + trailingDurationMs <= 0L) {
                issues.add(issue("duration", "Transition window must have positive duration."))
            }

            val transitionStartMs = boundaryTimeMs - leadingDurationMs
            val transitionEndMs = boundaryTimeMs + trailingDurationMs
            if (transitionStartMs < 0L) {
                issues.add(issue("transitionStartMs", "Transition start cannot be before timeline zero."))
            }

            val sources = plan["sources"] as? List<*>
            if (sources == null || sources.size != 2) {
                issues.add(issue("sources", "Professional video transitions require exactly two video sources."))
            }
            val outgoing =
                (sources?.getOrNull(0) as? Map<*, *>)?.let {
                    ProfessionalVideoTransitionRenderSource.fromMap(it, "sources[0]", issues)
                }
            val incoming =
                (sources?.getOrNull(1) as? Map<*, *>)?.let {
                    ProfessionalVideoTransitionRenderSource.fromMap(it, "sources[1]", issues)
                }

            val sourceRoles = readSourceRoles(plan["samplingPolicy"])
            if (sourceRoles != listOf("outgoing", "incoming")) {
                issues.add(issue("samplingPolicy.sourceRoles", "Source roles must be [outgoing, incoming]."))
            }

            if (outgoing != null && outgoing.timelineEndMs < boundaryTimeMs) {
                issues.add(issue("sources[0].timelineEndMs", "Outgoing source must reach the transition boundary."))
            }
            if (incoming != null && incoming.timelineStartMs > boundaryTimeMs) {
                issues.add(issue("sources[1].timelineStartMs", "Incoming source must start at or before the transition boundary."))
            }
            if (outgoing != null && outgoing.timelineStartMs > transitionStartMs) {
                issues.add(issue("sources[0].timelineStartMs", "Outgoing source must cover the leading transition window."))
            }
            if (incoming != null && incoming.timelineEndMs < transitionEndMs) {
                issues.add(issue("sources[1].timelineEndMs", "Incoming source must cover the trailing transition window."))
            }

            if (issues.isNotEmpty() || outgoing == null || incoming == null) {
                return ProfessionalVideoTransitionRenderSessionParseResult(
                    session = null,
                    issues = issues,
                )
            }

            return ProfessionalVideoTransitionRenderSessionParseResult(
                session =
                    ProfessionalVideoTransitionRenderSession(
                        id = "transition-session:$transitionId",
                        definitionId = definitionId,
                        transitionId = transitionId,
                        canvasWidth = canvasWidth,
                        canvasHeight = canvasHeight,
                        boundaryTimeMs = boundaryTimeMs,
                        leadingDurationMs = leadingDurationMs,
                        trailingDurationMs = trailingDurationMs,
                        transitionStartMs = transitionStartMs,
                        transitionEndMs = transitionEndMs,
                        outgoing = outgoing,
                        incoming = incoming,
                        sourceRoles = sourceRoles,
                    ),
                issues = emptyList(),
            )
        }

        private fun readSourceRoles(value: Any?): List<String> {
            val policy = value as? Map<*, *> ?: return listOf("outgoing", "incoming")
            val roles = policy["sourceRoles"] as? List<*> ?: return listOf("outgoing", "incoming")
            return roles.map { role -> role.toString() }
        }

        private fun invalid(path: String, message: String): ProfessionalVideoTransitionRenderSessionParseResult =
            ProfessionalVideoTransitionRenderSessionParseResult(
                session = null,
                issues = listOf(issue(path, message)),
            )
    }
}

private data class ProfessionalVideoTransitionRenderSource(
    val clipId: String,
    val assetId: String,
    val sourceUri: String?,
    val timelineStartMs: Long,
    val timelineEndMs: Long,
    val sourceStartMs: Long,
    val sourceDurationMs: Long,
) {
    fun coversTimelineTime(timelineTimeMs: Long): Boolean =
        timelineTimeMs >= timelineStartMs && timelineTimeMs <= timelineEndMs

    fun sourceTimeForTimelineTime(timelineTimeMs: Long): Long {
        val localTimeMs = timelineTimeMs - timelineStartMs
        val unclamped = sourceStartMs + localTimeMs
        return unclamped.coerceIn(sourceStartMs, sourceStartMs + sourceDurationMs)
    }

    companion object {
        fun fromMap(
            map: Map<*, *>,
            path: String,
            issues: MutableList<Map<String, Any>>,
        ): ProfessionalVideoTransitionRenderSource? {
            val clipId = map.stringValue("clipId")
            val assetId = map.stringValue("assetId")
            val sourceUri = map.stringValue("sourceUri").takeIf { it.isNotBlank() }
            val timelineStartMs = map.longValue("timelineStartMs")
            val timelineEndMs = map.longValue("timelineEndMs")
            val sourceStartMs = map.longValue("sourceStartMs")
            val sourceDurationMs = map.longValue("sourceDurationMs")

            if (clipId.isBlank()) {
                issues.add(issue("$path.clipId", "Source clip id is required."))
            }
            if (assetId.isBlank()) {
                issues.add(issue("$path.assetId", "Source asset id is required."))
            }
            if (timelineEndMs <= timelineStartMs) {
                issues.add(issue("$path.timelineRange", "Source timeline range must be positive."))
            }
            if (sourceStartMs < 0L) {
                issues.add(issue("$path.sourceStartMs", "Source start must be non-negative."))
            }
            if (sourceDurationMs <= 0L) {
                issues.add(issue("$path.sourceDurationMs", "Source duration must be positive."))
            }
            return if (
                clipId.isBlank() ||
                    assetId.isBlank() ||
                    timelineEndMs <= timelineStartMs ||
                    sourceStartMs < 0L ||
                    sourceDurationMs <= 0L
            ) {
                null
            } else {
                ProfessionalVideoTransitionRenderSource(
                    clipId = clipId,
                    assetId = assetId,
                    sourceUri = sourceUri,
                    timelineStartMs = timelineStartMs,
                    timelineEndMs = timelineEndMs,
                    sourceStartMs = sourceStartMs,
                    sourceDurationMs = sourceDurationMs,
                )
            }
        }
    }
}

private fun Map<*, *>.stringValue(key: String): String = this[key]?.toString() ?: ""

private fun Map<*, *>.longValue(key: String): Long =
    when (val value = this[key]) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: 0L
        else -> 0L
    }

private fun Map<*, *>.doubleValue(
    key: String,
    defaultValue: Double = 0.0,
): Double =
    when (val value = this[key]) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull() ?: defaultValue
        else -> defaultValue
    }

private fun Map<*, *>.intValue(
    key: String,
    defaultValue: Int = 0,
): Int =
    when (val value = this[key]) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull() ?: defaultValue
        else -> defaultValue
    }

private fun Map<*, *>.stringKeyMap(): Map<String, Any?> =
    mapKeys { entry -> entry.key.toString() }

private fun List<Map<*, *>>.idsForRole(role: String): List<String> =
    mapNotNull { request ->
        if (request["role"] == role) {
            request["decodeRequestId"]?.toString()
        } else {
            null
        }
    }

private fun issue(path: String, message: String): Map<String, Any> =
    mapOf(
        "path" to path,
        "message" to message,
    )

private data class VideoSourceProbeResult(
    val canOpenSource: Boolean,
    val hasVideoTrack: Boolean,
    val width: Int?,
    val height: Int?,
    val durationUs: Long?,
    val frameRate: Int?,
    val mimeType: String,
    val reason: String?,
)

private data class ExactVideoFrameProbeResult(
    val canDecodeFrame: Boolean,
    val decodedFrameTimeUs: Long?,
    val decodedBufferReadable: Boolean = false,
    val decodedBufferByteCount: Int = 0,
    val decodedBufferChecksum: Long = 0L,
    val outputFormatMimeType: String,
    val outputWidth: Int,
    val outputHeight: Int,
    val reason: String?,
)

private data class ExactVideoFrameSampleProbeResult(
    val sourceTimeMs: Long,
    val canDecodeFrame: Boolean,
    val decodedFrameTimeUs: Long?,
    val decodedBufferReadable: Boolean = false,
    val decodedBufferByteCount: Int = 0,
    val decodedBufferChecksum: Long = 0L,
    val reason: String?,
)

private data class ExactVideoFrameBatchProbeResult(
    val canDecodeAllFrames: Boolean,
    val canReadAllBuffers: Boolean = false,
    val outputFormatMimeType: String,
    val outputWidth: Int,
    val outputHeight: Int,
    val samples: List<ExactVideoFrameSampleProbeResult>,
    val reason: String?,
)

private data class LiveVideoDecodeStreamProbeResult(
    val canDecodeStream: Boolean,
    val allDecodedBuffersReadable: Boolean = false,
    val decodedFrameCount: Int,
    val readableBufferCount: Int,
    val firstFrameTimeUs: Long?,
    val lastFrameTimeUs: Long?,
    val minRequiredFrameCount: Int,
    val outputFormatMimeType: String,
    val outputWidth: Int,
    val outputHeight: Int,
    val reason: String?,
)

private data class DecodedVideoBufferSignature(
    val readable: Boolean,
    val byteCount: Int,
    val checksum: Long,
)

private fun probeVideoSource(
    appContext: Context,
    sourceUri: String,
): VideoSourceProbeResult {
    val uri =
        runCatching { Uri.parse(sourceUri) }.getOrElse {
            return VideoSourceProbeResult(
                canOpenSource = false,
                hasVideoTrack = false,
                width = null,
                height = null,
                durationUs = null,
                frameRate = null,
                mimeType = "",
                reason = "native_video_source_uri_parse_failed",
            )
        }
    val extractor = MediaExtractor()
    try {
        when (uri.scheme) {
            "file" -> {
                val path = uri.path
                if (path.isNullOrBlank()) {
                    return VideoSourceProbeResult(
                        canOpenSource = false,
                        hasVideoTrack = false,
                        width = null,
                        height = null,
                        durationUs = null,
                        frameRate = null,
                        mimeType = "",
                        reason = "native_video_source_file_path_missing",
                    )
                }
                extractor.setDataSource(path)
            }
            "content" -> extractor.setDataSource(appContext, uri, null)
            else -> {
                return VideoSourceProbeResult(
                    canOpenSource = false,
                    hasVideoTrack = false,
                    width = null,
                    height = null,
                    durationUs = null,
                    frameRate = null,
                    mimeType = "",
                    reason = "native_video_source_uri_scheme_unsupported",
                )
            }
        }
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mimeType =
                if (format.containsKey(MediaFormat.KEY_MIME)) {
                    format.getString(MediaFormat.KEY_MIME).orEmpty()
                } else {
                    ""
                }
            if (mimeType.startsWith("video/")) {
                return VideoSourceProbeResult(
                    canOpenSource = true,
                    hasVideoTrack = true,
                    width = format.optionalInt(MediaFormat.KEY_WIDTH),
                    height = format.optionalInt(MediaFormat.KEY_HEIGHT),
                    durationUs = format.optionalLong(MediaFormat.KEY_DURATION),
                    frameRate = format.optionalInt(MediaFormat.KEY_FRAME_RATE),
                    mimeType = mimeType,
                    reason = null,
                )
            }
        }
        return VideoSourceProbeResult(
            canOpenSource = true,
            hasVideoTrack = false,
            width = null,
            height = null,
            durationUs = null,
            frameRate = null,
            mimeType = "",
            reason = "native_video_track_missing",
        )
    } catch (_: SecurityException) {
        return VideoSourceProbeResult(
            canOpenSource = false,
            hasVideoTrack = false,
            width = null,
            height = null,
            durationUs = null,
            frameRate = null,
            mimeType = "",
            reason = "native_video_source_permission_denied",
        )
    } catch (_: Throwable) {
        return VideoSourceProbeResult(
            canOpenSource = false,
            hasVideoTrack = false,
            width = null,
            height = null,
            durationUs = null,
            frameRate = null,
            mimeType = "",
            reason = "native_video_source_open_failed",
        )
    } finally {
        extractor.release()
    }
}

private fun probeExactVideoFrame(
    appContext: Context,
    sourceUri: String,
    sourceTimeMs: Long,
    frameRate: Int?,
): ExactVideoFrameProbeResult {
    val uri =
        runCatching { Uri.parse(sourceUri) }.getOrElse {
            return ExactVideoFrameProbeResult(
                canDecodeFrame = false,
                decodedFrameTimeUs = null,
                outputFormatMimeType = "",
                outputWidth = 0,
                outputHeight = 0,
                reason = "native_video_source_uri_parse_failed",
            )
        }
    val extractor = MediaExtractor()
    var codec: MediaCodec? = null
    try {
        when (uri.scheme) {
            "file" -> {
                val path = uri.path
                if (path.isNullOrBlank()) {
                    return ExactVideoFrameProbeResult(
                        canDecodeFrame = false,
                        decodedFrameTimeUs = null,
                        outputFormatMimeType = "",
                        outputWidth = 0,
                        outputHeight = 0,
                        reason = "native_video_source_file_path_missing",
                    )
                }
                extractor.setDataSource(path)
            }
            "content" -> extractor.setDataSource(appContext, uri, null)
            else -> {
                return ExactVideoFrameProbeResult(
                    canDecodeFrame = false,
                    decodedFrameTimeUs = null,
                    outputFormatMimeType = "",
                    outputWidth = 0,
                    outputHeight = 0,
                    reason = "native_video_source_uri_scheme_unsupported",
                )
            }
        }

        var videoTrackIndex = -1
        var videoFormat: MediaFormat? = null
        var mimeType = ""
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val candidateMimeType =
                if (format.containsKey(MediaFormat.KEY_MIME)) {
                    format.getString(MediaFormat.KEY_MIME).orEmpty()
                } else {
                    ""
                }
            if (candidateMimeType.startsWith("video/")) {
                videoTrackIndex = index
                videoFormat = format
                mimeType = candidateMimeType
                break
            }
        }
        val format = videoFormat
            ?: return ExactVideoFrameProbeResult(
                canDecodeFrame = false,
                decodedFrameTimeUs = null,
                outputFormatMimeType = "",
                outputWidth = 0,
                outputHeight = 0,
                reason = "native_video_track_missing",
            )
        extractor.selectTrack(videoTrackIndex)

        val effectiveFrameRate =
            (frameRate ?: format.optionalInt(MediaFormat.KEY_FRAME_RATE) ?: 30).coerceAtLeast(1)
        val frameDurationUs = 1_000_000L / effectiveFrameRate.toLong()
        val durationUs = format.optionalLong(MediaFormat.KEY_DURATION)
        val requestedTargetUs = sourceTimeMs.coerceAtLeast(0L) * 1000L
        val targetUs =
            if (durationUs != null && durationUs > frameDurationUs) {
                requestedTargetUs.coerceIn(0L, durationUs - frameDurationUs)
            } else {
                requestedTargetUs
            }
        val toleranceUs = maxOf(100_000L, frameDurationUs * 3L)
        extractor.seekTo(targetUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        codec = MediaCodec.createDecoderByType(mimeType)
        codec.configure(format, null, null, 0)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var decodedFrames = 0
        val timeoutAtNanos = System.nanoTime() + 1_500_000_000L
        while (System.nanoTime() < timeoutAtNanos && decodedFrames < 240) {
            if (!inputDone) {
                val inputBufferIndex = codec.dequeueInputBuffer(10_000L)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                    val sampleSize =
                        if (inputBuffer == null) {
                            -1
                        } else {
                            extractor.readSampleData(inputBuffer, 0)
                        }
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            0,
                            0L,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            sampleSize,
                            extractor.sampleTime,
                            0,
                        )
                        extractor.advance()
                    }
                }
            }

            when (val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000L)) {
                MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                else -> {
                    if (outputBufferIndex >= 0) {
                        val presentationUs = bufferInfo.presentationTimeUs
                        val hasFrame = bufferInfo.size > 0
                        val eos =
                            bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        val bufferSignature =
                            if (hasFrame) {
                                decodedBufferSignature(codec, outputBufferIndex, bufferInfo)
                            } else {
                                DecodedVideoBufferSignature(
                                    readable = false,
                                    byteCount = 0,
                                    checksum = 0L,
                                )
                            }
                        codec.releaseOutputBuffer(outputBufferIndex, false)
                        if (hasFrame) {
                            decodedFrames += 1
                            if (abs(presentationUs - targetUs) <= toleranceUs) {
                                return ExactVideoFrameProbeResult(
                                    canDecodeFrame = true,
                                    decodedFrameTimeUs = presentationUs,
                                    decodedBufferReadable = bufferSignature.readable,
                                    decodedBufferByteCount = bufferSignature.byteCount,
                                    decodedBufferChecksum = bufferSignature.checksum,
                                    outputFormatMimeType = mimeType,
                                    outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                                    outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                                    reason = null,
                                )
                            }
                            if (presentationUs > targetUs + toleranceUs) {
                                return ExactVideoFrameProbeResult(
                                    canDecodeFrame = false,
                                    decodedFrameTimeUs = presentationUs,
                                    decodedBufferReadable = bufferSignature.readable,
                                    decodedBufferByteCount = bufferSignature.byteCount,
                                    decodedBufferChecksum = bufferSignature.checksum,
                                    outputFormatMimeType = mimeType,
                                    outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                                    outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                                    reason = "native_exact_frame_decode_tolerance_miss",
                                )
                            }
                        }
                        if (eos) {
                            return ExactVideoFrameProbeResult(
                                canDecodeFrame = false,
                                decodedFrameTimeUs = presentationUs.takeIf { hasFrame },
                                decodedBufferReadable = bufferSignature.readable,
                                decodedBufferByteCount = bufferSignature.byteCount,
                                decodedBufferChecksum = bufferSignature.checksum,
                                outputFormatMimeType = mimeType,
                                outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                                outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                                reason = "native_exact_frame_decode_eos_before_target",
                            )
                        }
                    }
                }
            }
        }
        return ExactVideoFrameProbeResult(
            canDecodeFrame = false,
            decodedFrameTimeUs = null,
            outputFormatMimeType = mimeType,
            outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
            outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
            reason = "native_exact_frame_decode_timeout",
        )
    } catch (_: SecurityException) {
        return ExactVideoFrameProbeResult(
            canDecodeFrame = false,
            decodedFrameTimeUs = null,
            outputFormatMimeType = "",
            outputWidth = 0,
            outputHeight = 0,
            reason = "native_video_source_permission_denied",
        )
    } catch (_: Throwable) {
        return ExactVideoFrameProbeResult(
            canDecodeFrame = false,
            decodedFrameTimeUs = null,
            outputFormatMimeType = "",
            outputWidth = 0,
            outputHeight = 0,
            reason = "native_exact_frame_decode_failed",
        )
    } finally {
        runCatching {
            codec?.stop()
        }
        codec?.release()
        extractor.release()
    }
}

private fun probeExactVideoFrames(
    appContext: Context,
    sourceUri: String,
    sourceTimesMs: List<Long>,
    frameRate: Int?,
): ExactVideoFrameBatchProbeResult {
    if (sourceTimesMs.isEmpty()) {
        return ExactVideoFrameBatchProbeResult(
            canDecodeAllFrames = false,
            outputFormatMimeType = "",
            outputWidth = 0,
            outputHeight = 0,
            samples = emptyList(),
            reason = "native_exact_frame_decode_requests_missing",
        )
    }
    var outputMimeType = ""
    var outputWidth = 0
    var outputHeight = 0
    val samples =
        sourceTimesMs.map { sourceTimeMs ->
            val result =
                probeExactVideoFrame(
                    appContext = appContext,
                    sourceUri = sourceUri,
                    sourceTimeMs = sourceTimeMs,
                    frameRate = frameRate,
                )
            if (result.outputFormatMimeType.isNotBlank()) {
                outputMimeType = result.outputFormatMimeType
            }
            if (result.outputWidth > 0) {
                outputWidth = result.outputWidth
            }
            if (result.outputHeight > 0) {
                outputHeight = result.outputHeight
            }
            ExactVideoFrameSampleProbeResult(
                sourceTimeMs = sourceTimeMs,
                canDecodeFrame = result.canDecodeFrame,
                decodedFrameTimeUs = result.decodedFrameTimeUs,
                decodedBufferReadable = result.decodedBufferReadable,
                decodedBufferByteCount = result.decodedBufferByteCount,
                decodedBufferChecksum = result.decodedBufferChecksum,
                reason = result.reason,
            )
        }
    val firstFailure = samples.firstOrNull { sample -> !sample.canDecodeFrame }
    val firstUnreadableBuffer =
        samples.firstOrNull { sample -> sample.canDecodeFrame && !sample.decodedBufferReadable }
    return ExactVideoFrameBatchProbeResult(
        canDecodeAllFrames = firstFailure == null,
        canReadAllBuffers = firstFailure == null && firstUnreadableBuffer == null,
        outputFormatMimeType = outputMimeType,
        outputWidth = outputWidth,
        outputHeight = outputHeight,
        samples = samples,
        reason = firstFailure?.reason
            ?: firstUnreadableBuffer?.let { "native_exact_frame_output_buffer_not_ready" },
    )
}

private fun probeLiveVideoDecodeStream(
    appContext: Context,
    sourceUri: String,
    sourceStartMs: Long,
    sourceEndMs: Long,
    frameRate: Int?,
): LiveVideoDecodeStreamProbeResult {
    val uri =
        runCatching { Uri.parse(sourceUri) }.getOrElse {
            return LiveVideoDecodeStreamProbeResult(
                canDecodeStream = false,
                decodedFrameCount = 0,
                readableBufferCount = 0,
                firstFrameTimeUs = null,
                lastFrameTimeUs = null,
                minRequiredFrameCount = 0,
                outputFormatMimeType = "",
                outputWidth = 0,
                outputHeight = 0,
                reason = "native_video_source_uri_parse_failed",
            )
        }
    val extractor = MediaExtractor()
    var codec: MediaCodec? = null
    try {
        when (uri.scheme) {
            "file" -> {
                val path = uri.path
                if (path.isNullOrBlank()) {
                    return LiveVideoDecodeStreamProbeResult(
                        canDecodeStream = false,
                        decodedFrameCount = 0,
                        readableBufferCount = 0,
                        firstFrameTimeUs = null,
                        lastFrameTimeUs = null,
                        minRequiredFrameCount = 0,
                        outputFormatMimeType = "",
                        outputWidth = 0,
                        outputHeight = 0,
                        reason = "native_video_source_file_path_missing",
                    )
                }
                extractor.setDataSource(path)
            }
            "content" -> extractor.setDataSource(appContext, uri, null)
            else -> {
                return LiveVideoDecodeStreamProbeResult(
                    canDecodeStream = false,
                    decodedFrameCount = 0,
                    readableBufferCount = 0,
                    firstFrameTimeUs = null,
                    lastFrameTimeUs = null,
                    minRequiredFrameCount = 0,
                    outputFormatMimeType = "",
                    outputWidth = 0,
                    outputHeight = 0,
                    reason = "native_video_source_uri_scheme_unsupported",
                )
            }
        }

        var videoTrackIndex = -1
        var videoFormat: MediaFormat? = null
        var mimeType = ""
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val candidateMimeType =
                if (format.containsKey(MediaFormat.KEY_MIME)) {
                    format.getString(MediaFormat.KEY_MIME).orEmpty()
                } else {
                    ""
                }
            if (candidateMimeType.startsWith("video/")) {
                videoTrackIndex = index
                videoFormat = format
                mimeType = candidateMimeType
                break
            }
        }
        val format = videoFormat
            ?: return LiveVideoDecodeStreamProbeResult(
                canDecodeStream = false,
                decodedFrameCount = 0,
                readableBufferCount = 0,
                firstFrameTimeUs = null,
                lastFrameTimeUs = null,
                minRequiredFrameCount = 0,
                outputFormatMimeType = "",
                outputWidth = 0,
                outputHeight = 0,
                reason = "native_video_track_missing",
            )
        extractor.selectTrack(videoTrackIndex)

        val effectiveFrameRate =
            (frameRate ?: format.optionalInt(MediaFormat.KEY_FRAME_RATE) ?: 30).coerceAtLeast(1)
        val frameDurationUs = (1_000_000L / effectiveFrameRate.toLong()).coerceAtLeast(1L)
        val requestedStartUs = minOf(sourceStartMs, sourceEndMs).coerceAtLeast(0L) * 1000L
        val requestedEndExclusiveUs = maxOf(sourceStartMs, sourceEndMs).coerceAtLeast(0L) * 1000L
        if (requestedEndExclusiveUs <= requestedStartUs) {
            return LiveVideoDecodeStreamProbeResult(
                canDecodeStream = false,
                decodedFrameCount = 0,
                readableBufferCount = 0,
                firstFrameTimeUs = null,
                lastFrameTimeUs = null,
                minRequiredFrameCount = 0,
                outputFormatMimeType = mimeType,
                outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                reason = "native_video_decode_stream_window_empty",
            )
        }
        val durationUs = format.optionalLong(MediaFormat.KEY_DURATION)
        if (durationUs != null && durationUs > 0L && requestedEndExclusiveUs > durationUs) {
            return LiveVideoDecodeStreamProbeResult(
                canDecodeStream = false,
                decodedFrameCount = 0,
                readableBufferCount = 0,
                firstFrameTimeUs = null,
                lastFrameTimeUs = null,
                minRequiredFrameCount = 0,
                outputFormatMimeType = mimeType,
                outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                reason = "native_video_decode_stream_window_outside_media",
            )
        }

        val streamStartUs = requestedStartUs
        val streamEndSampleUs = (requestedEndExclusiveUs - frameDurationUs).coerceAtLeast(streamStartUs)
        val estimatedFrameCount =
            (((streamEndSampleUs - streamStartUs).coerceAtLeast(0L) / frameDurationUs) + 1L)
                .coerceAtLeast(1L)
        val minRequiredFrameCount = estimatedFrameCount.coerceIn(3L, 18L).toInt()
        val toleranceUs = maxOf(100_000L, frameDurationUs * 3L)
        val feedUntilUs = streamEndSampleUs + toleranceUs
        extractor.seekTo(streamStartUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

        codec = MediaCodec.createDecoderByType(mimeType)
        codec.configure(format, null, null, 0)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        var inputDone = false
        var totalDecodedOutputFrames = 0
        var decodedFrameCount = 0
        var readableBufferCount = 0
        var firstFrameTimeUs: Long? = null
        var lastFrameTimeUs: Long? = null
        var unreadableBufferSeen = false
        val timeoutAtNanos = System.nanoTime() + 3_500_000_000L
        while (System.nanoTime() < timeoutAtNanos && totalDecodedOutputFrames < 720) {
            if (!inputDone) {
                val inputBufferIndex = codec.dequeueInputBuffer(10_000L)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                    val sampleTimeUs = extractor.sampleTime
                    val sampleSize =
                        if (inputBuffer == null || sampleTimeUs < 0L || sampleTimeUs > feedUntilUs) {
                            -1
                        } else {
                            extractor.readSampleData(inputBuffer, 0)
                        }
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            0,
                            0L,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(
                            inputBufferIndex,
                            0,
                            sampleSize,
                            sampleTimeUs,
                            0,
                        )
                        extractor.advance()
                    }
                }
            }

            when (val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000L)) {
                MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit
                else -> {
                    if (outputBufferIndex >= 0) {
                        val presentationUs = bufferInfo.presentationTimeUs
                        val hasFrame = bufferInfo.size > 0
                        val eos =
                            bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        val inWindow =
                            hasFrame &&
                                presentationUs >= streamStartUs - toleranceUs &&
                                presentationUs <= streamEndSampleUs + toleranceUs
                        val bufferSignature =
                            if (inWindow) {
                                decodedBufferSignature(codec, outputBufferIndex, bufferInfo)
                            } else {
                                DecodedVideoBufferSignature(
                                    readable = false,
                                    byteCount = 0,
                                    checksum = 0L,
                                )
                            }
                        codec.releaseOutputBuffer(outputBufferIndex, false)
                        if (hasFrame) {
                            totalDecodedOutputFrames += 1
                        }
                        if (inWindow) {
                            decodedFrameCount += 1
                            if (bufferSignature.readable) {
                                readableBufferCount += 1
                            } else {
                                unreadableBufferSeen = true
                            }
                            firstFrameTimeUs = firstFrameTimeUs ?: presentationUs
                            lastFrameTimeUs = presentationUs
                            if (
                                decodedFrameCount >= minRequiredFrameCount &&
                                    readableBufferCount == decodedFrameCount &&
                                    presentationUs >= streamEndSampleUs - toleranceUs
                            ) {
                                return LiveVideoDecodeStreamProbeResult(
                                    canDecodeStream = true,
                                    allDecodedBuffersReadable = true,
                                    decodedFrameCount = decodedFrameCount,
                                    readableBufferCount = readableBufferCount,
                                    firstFrameTimeUs = firstFrameTimeUs,
                                    lastFrameTimeUs = lastFrameTimeUs,
                                    minRequiredFrameCount = minRequiredFrameCount,
                                    outputFormatMimeType = mimeType,
                                    outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
                                    outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
                                    reason = null,
                                )
                            }
                        }
                        if (eos) {
                            break
                        }
                    }
                }
            }
        }
        val reason =
            when {
                decodedFrameCount <= 0 -> "native_video_decode_stream_frames_missing"
                unreadableBufferSeen || readableBufferCount < decodedFrameCount ->
                    "native_video_decode_stream_output_buffer_not_ready"
                decodedFrameCount < minRequiredFrameCount ->
                    "native_video_decode_stream_sample_coverage_low"
                (lastFrameTimeUs ?: 0L) < streamEndSampleUs - toleranceUs ->
                    "native_video_decode_stream_end_gap"
                else -> "native_video_decode_stream_timeout"
            }
        return LiveVideoDecodeStreamProbeResult(
            canDecodeStream = false,
            allDecodedBuffersReadable = readableBufferCount == decodedFrameCount && decodedFrameCount > 0,
            decodedFrameCount = decodedFrameCount,
            readableBufferCount = readableBufferCount,
            firstFrameTimeUs = firstFrameTimeUs,
            lastFrameTimeUs = lastFrameTimeUs,
            minRequiredFrameCount = minRequiredFrameCount,
            outputFormatMimeType = mimeType,
            outputWidth = format.optionalInt(MediaFormat.KEY_WIDTH) ?: 0,
            outputHeight = format.optionalInt(MediaFormat.KEY_HEIGHT) ?: 0,
            reason = reason,
        )
    } catch (_: SecurityException) {
        return LiveVideoDecodeStreamProbeResult(
            canDecodeStream = false,
            decodedFrameCount = 0,
            readableBufferCount = 0,
            firstFrameTimeUs = null,
            lastFrameTimeUs = null,
            minRequiredFrameCount = 0,
            outputFormatMimeType = "",
            outputWidth = 0,
            outputHeight = 0,
            reason = "native_video_source_permission_denied",
        )
    } catch (_: Throwable) {
        return LiveVideoDecodeStreamProbeResult(
            canDecodeStream = false,
            decodedFrameCount = 0,
            readableBufferCount = 0,
            firstFrameTimeUs = null,
            lastFrameTimeUs = null,
            minRequiredFrameCount = 0,
            outputFormatMimeType = "",
            outputWidth = 0,
            outputHeight = 0,
            reason = "native_video_decode_stream_failed",
        )
    } finally {
        runCatching {
            codec?.stop()
        }
        codec?.release()
        extractor.release()
    }
}

private fun decodedBufferSignature(
    codec: MediaCodec,
    outputBufferIndex: Int,
    bufferInfo: MediaCodec.BufferInfo,
): DecodedVideoBufferSignature {
    val byteCount = bufferInfo.size.coerceAtLeast(0)
    if (byteCount <= 0) {
        return DecodedVideoBufferSignature(readable = false, byteCount = 0, checksum = 0L)
    }
    val outputBuffer =
        codec.getOutputBuffer(outputBufferIndex)
            ?: return DecodedVideoBufferSignature(
                readable = false,
                byteCount = byteCount,
                checksum = 0L,
            )
    return runCatching {
        val duplicate = outputBuffer.duplicate()
        val start = bufferInfo.offset.coerceAtLeast(0)
        val end = (start + byteCount).coerceAtMost(duplicate.capacity())
        if (start >= end) {
            DecodedVideoBufferSignature(readable = false, byteCount = byteCount, checksum = 0L)
        } else {
            duplicate.position(start)
            duplicate.limit(end)
            var checksum = -3750763034362895579L
            var remaining = minOf(duplicate.remaining(), 4096)
            while (remaining > 0) {
                checksum = (checksum xor (duplicate.get().toLong() and 0xffL)) * 1099511628211L
                remaining -= 1
            }
            DecodedVideoBufferSignature(
                readable = true,
                byteCount = byteCount,
                checksum = checksum,
            )
        }
    }.getOrElse {
        DecodedVideoBufferSignature(readable = false, byteCount = byteCount, checksum = 0L)
    }
}

private fun MediaFormat.optionalInt(key: String): Int? =
    if (containsKey(key)) {
        getInteger(key)
    } else {
        null
    }

private fun MediaFormat.optionalLong(key: String): Long? =
    if (containsKey(key)) {
        getLong(key)
    } else {
        null
    }

private fun Map<String, Any>.withSessionMetadata(
    session: ProfessionalVideoTransitionRenderSession,
): Map<String, Any> = this + session.metadata()

private data class ProfessionalVideoTransitionRendererDefinition(
    val definitionId: String,
    val requiredCapabilities: Set<String>,
    val implemented: Boolean = false,
)

private data class ProfessionalVideoTransitionPixelFrameBufferAllocationResult(
    val frameBufferId: String,
    val width: Int,
    val height: Int,
    val format: String,
    val byteCount: Int,
    val allocated: Boolean,
    val memoryClass: String,
    val reason: String?,
) {
    companion object {
        fun invalid(
            frameBufferId: String,
            reason: String,
        ): ProfessionalVideoTransitionPixelFrameBufferAllocationResult =
            ProfessionalVideoTransitionPixelFrameBufferAllocationResult(
                frameBufferId = frameBufferId,
                width = 0,
                height = 0,
                format = "rgba8888",
                byteCount = 0,
                allocated = false,
                memoryClass = "none",
                reason = reason,
            )
    }
}

private data class ProfessionalVideoTransitionPixelFrameBufferAllocation(
    val id: String,
    val width: Int,
    val height: Int,
    val format: String,
    val byteCount: Int,
    val buffer: ByteBuffer,
)

private data class ProfessionalVideoTransitionPixelFrameBufferWriteResult(
    val wrotePixels: Boolean,
    val byteCount: Int,
    val checksum: Long,
    val sampleCount: Int,
    val extractedFrameCount: Int,
    val reason: String?,
)

private class ProfessionalVideoTransitionPixelFrameBufferStore(
    private val maxBuffers: Int = 3,
    private val maxFrameBufferBytes: Int = 64 * 1024 * 1024,
) {
    private val buffers =
        object : LinkedHashMap<String, ProfessionalVideoTransitionPixelFrameBufferAllocation>(
            maxBuffers,
            0.75f,
            true,
        ) {
            override fun removeEldestEntry(
                eldest: MutableMap.MutableEntry<String, ProfessionalVideoTransitionPixelFrameBufferAllocation>?,
            ): Boolean = size > maxBuffers
        }

    @Synchronized
    fun allocate(
        renderSessionId: String,
        timelineTimeMs: Long,
        width: Int,
        height: Int,
        format: String,
    ): ProfessionalVideoTransitionPixelFrameBufferAllocationResult {
        val frameBufferId = "$renderSessionId:pixel-frame-buffer:$timelineTimeMs"
        if (width <= 0 || height <= 0) {
            return ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                frameBufferId = frameBufferId,
                reason = "native_transition_pixel_frame_buffer_invalid_size",
            )
        }
        if (format != "rgba8888") {
            return ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                frameBufferId = frameBufferId,
                reason = "native_transition_pixel_frame_buffer_format_unsupported",
            )
        }
        val byteCountLong = width.toLong() * height.toLong() * 4L
        if (byteCountLong <= 0L || byteCountLong > maxFrameBufferBytes.toLong()) {
            return ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                frameBufferId = frameBufferId,
                reason = "native_transition_pixel_frame_buffer_too_large",
            )
        }
        val byteCount = byteCountLong.toInt()
        val existing = buffers[frameBufferId]
        if (
            existing != null &&
                existing.width == width &&
                existing.height == height &&
                existing.format == format &&
                existing.byteCount == byteCount
        ) {
            return existing.toResult()
        }
        return try {
            val buffer = ByteBuffer.allocateDirect(byteCount).order(ByteOrder.nativeOrder())
            val allocation =
                ProfessionalVideoTransitionPixelFrameBufferAllocation(
                    id = frameBufferId,
                    width = width,
                    height = height,
                    format = format,
                    byteCount = byteCount,
                    buffer = buffer,
                )
            buffers[frameBufferId] = allocation
            allocation.toResult()
        } catch (_: OutOfMemoryError) {
            ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                frameBufferId = frameBufferId,
                reason = "native_transition_pixel_frame_buffer_allocation_failed",
            )
        } catch (_: Throwable) {
            ProfessionalVideoTransitionPixelFrameBufferAllocationResult.invalid(
                frameBufferId = frameBufferId,
                reason = "native_transition_pixel_frame_buffer_allocation_failed",
            )
        }
    }

    @Synchronized
    fun writeBitmap(
        frameBufferId: String,
        bitmap: Bitmap,
        sampleCount: Int,
        extractedFrameCount: Int,
    ): ProfessionalVideoTransitionPixelFrameBufferWriteResult {
        val allocation =
            buffers[frameBufferId]
                ?: return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = sampleCount,
                    extractedFrameCount = extractedFrameCount,
                    reason = "native_transition_pixel_frame_buffer_missing",
                )
        if (bitmap.width != allocation.width || bitmap.height != allocation.height) {
            return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                wrotePixels = false,
                byteCount = 0,
                checksum = 0L,
                sampleCount = sampleCount,
                extractedFrameCount = extractedFrameCount,
                reason = "native_transition_pixel_frame_buffer_bitmap_size_mismatch",
            )
        }
        val bitmapForWrite =
            if (bitmap.config == Bitmap.Config.ARGB_8888) {
                bitmap
            } else {
                bitmap.copy(Bitmap.Config.ARGB_8888, false)
            }
        return try {
            allocation.buffer.clear()
            bitmapForWrite.copyPixelsToBuffer(allocation.buffer)
            allocation.buffer.rewind()
            val checksum = checksumFrameBuffer(allocation.buffer, allocation.byteCount)
            ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                wrotePixels = true,
                byteCount = allocation.byteCount,
                checksum = checksum,
                sampleCount = sampleCount,
                extractedFrameCount = extractedFrameCount,
                reason = null,
            )
        } catch (_: Throwable) {
            ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                wrotePixels = false,
                byteCount = 0,
                checksum = 0L,
                sampleCount = sampleCount,
                extractedFrameCount = extractedFrameCount,
                reason = "native_transition_pixel_frame_buffer_write_failed",
            )
        } finally {
            if (bitmapForWrite !== bitmap) {
                bitmapForWrite.recycle()
            }
        }
    }

    private fun checksumFrameBuffer(
        buffer: ByteBuffer,
        byteCount: Int,
    ): Long {
        val duplicate = buffer.duplicate()
        duplicate.position(0)
        duplicate.limit(byteCount.coerceAtMost(duplicate.capacity()))
        var checksum = -3750763034362895579L
        var remaining = minOf(duplicate.remaining(), 4096)
        while (remaining > 0) {
            checksum = (checksum xor (duplicate.get().toLong() and 0xffL)) * 1099511628211L
            remaining -= 1
        }
        buffer.rewind()
        return checksum
    }

    private fun ProfessionalVideoTransitionPixelFrameBufferAllocation.toResult():
        ProfessionalVideoTransitionPixelFrameBufferAllocationResult =
        ProfessionalVideoTransitionPixelFrameBufferAllocationResult(
            frameBufferId = id,
            width = width,
            height = height,
            format = format,
            byteCount = byteCount,
            allocated = true,
            memoryClass = "directByteBuffer",
            reason = null,
        )
}

private class ProfessionalVideoTransitionRendererRegistry(
    private val definitions: Map<String, ProfessionalVideoTransitionRendererDefinition>,
    private val availableCapabilities: Set<String>,
) {
    fun registeredDefinitionIds(): List<String> = definitions.keys.sorted()

    fun prepare(
        definitionId: String,
        requestedCapabilities: List<String>,
    ): Map<String, Any>? {
        val definition =
            definitions[definitionId]
                ?: return mapOf(
                    "status" to "unsupported",
                    "reason" to "unsupported_transition_definition",
                    "rendererVersion" to "foundation",
                    "definitionId" to definitionId,
                    "missingCapabilities" to requestedCapabilities,
                )
        val requiredCapabilities =
            (definition.requiredCapabilities + requestedCapabilities).toSortedSet()
        val missingCapabilities =
            requiredCapabilities.filterNot { capability ->
                availableCapabilities.contains(capability)
            }
        if (missingCapabilities.isNotEmpty()) {
            return mapOf(
                "status" to "unsupported",
                "reason" to "missing_renderer_capabilities",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "missingCapabilities" to missingCapabilities,
            )
        }
        if (!definition.implemented) {
            return mapOf(
                "status" to "unsupported",
                "reason" to "renderer_not_implemented",
                "rendererVersion" to "foundation",
                "definitionId" to definitionId,
                "missingCapabilities" to emptyList<String>(),
            )
        }
        return null
    }

    companion object {
        fun foundation(): ProfessionalVideoTransitionRendererRegistry {
            val definitions =
                listOf(
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "crossDissolve",
                        requiredCapabilities = setOf("dualVideoSampling", "previewParity", "playbackParity"),
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "fadeBlack",
                        requiredCapabilities = setOf("dualVideoSampling", "previewParity", "playbackParity"),
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "zoomInCamera",
                        requiredCapabilities =
                            setOf(
                                "dualVideoSampling",
                                "temporalMotionBlur",
                                "mirrorEdgeTiling",
                                "previewParity",
                                "liveScrubParity",
                                "playbackParity",
                                "exportParity",
                            ),
                    ),
                ).associateBy { definition -> definition.definitionId }
            return ProfessionalVideoTransitionRendererRegistry(
                definitions = definitions,
                availableCapabilities = setOf("dualVideoSampling"),
            )
        }
    }
}
