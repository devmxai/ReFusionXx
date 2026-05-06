package com.refusion.app

import android.app.ActivityManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Matrix
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.ImageReader
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.SystemClock
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.LinkedHashMap
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private object TransitionFrameExtractorCache {
    private val lock = Any()
    private const val frameCacheMaxEntries = 96
    private const val frameCacheTtlMs = 4_000L
    private const val frameRetrieverMaxEntries = 6
    private const val frameRetrieverIdleTtlMs = 8_000L

    private val frameCache =
        object : LinkedHashMap<String, CachedFrameEntry>(128, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CachedFrameEntry>?): Boolean {
                return size > frameCacheMaxEntries
            }
        }

    private val frameRetrieversBySourceUri =
        object : LinkedHashMap<String, CachedFrameRetriever>(16, 0.75f, true) {
            override fun removeEldestEntry(
                eldest: MutableMap.MutableEntry<String, CachedFrameRetriever>?,
            ): Boolean {
                if (size <= frameRetrieverMaxEntries) {
                    return false
                }
                eldest?.value?.retriever?.release()
                return true
            }
        }

    private data class CachedFrameEntry(
        val width: Int,
        val height: Int,
        val pixels: IntArray,
        val cachedAtUptimeMs: Long,
    )

    private data class CachedFrameRetriever(
        val retriever: MediaMetadataRetriever,
        var lastUsedUptimeMs: Long,
    )

    fun extract(
        appContext: Context,
        sourceUri: String?,
        sourceTimeMs: Long,
    ): Bitmap? {
        if (sourceUri.isNullOrBlank()) {
            return null
        }
        val safeSourceTimeUs = sourceTimeMs.coerceAtLeast(0L) * 1000L
        val cacheKey = buildFrameCacheKey(sourceUri, safeSourceTimeUs)
        frameBitmapFromCache(cacheKey)?.let { return it }
        val retriever = acquireFrameRetriever(appContext, sourceUri) ?: return null
        return try {
            val extracted =
                retriever.getFrameAtTime(
                    safeSourceTimeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                ) ?: return null
            val argbBitmap =
                if (extracted.config == Bitmap.Config.ARGB_8888) {
                    extracted
                } else {
                    extracted.copy(Bitmap.Config.ARGB_8888, false) ?: extracted
                }
            if (argbBitmap.width <= 0 || argbBitmap.height <= 0) {
                if (argbBitmap !== extracted) {
                    argbBitmap.recycle()
                }
                extracted.recycle()
                return null
            }
            val pixels = IntArray(argbBitmap.width * argbBitmap.height)
            argbBitmap.getPixels(
                pixels,
                0,
                argbBitmap.width,
                0,
                0,
                argbBitmap.width,
                argbBitmap.height,
            )
            synchronized(lock) {
                frameCache[cacheKey] =
                    CachedFrameEntry(
                        width = argbBitmap.width,
                        height = argbBitmap.height,
                        pixels = pixels,
                        cachedAtUptimeMs = SystemClock.uptimeMillis(),
                    )
            }
            if (argbBitmap !== extracted) {
                argbBitmap.recycle()
            }
            extracted.recycle()
            Bitmap.createBitmap(
                pixels,
                argbBitmap.width,
                argbBitmap.height,
                Bitmap.Config.ARGB_8888,
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun buildFrameCacheKey(
        sourceUri: String,
        sourceTimeUs: Long,
    ): String {
        val frameStepUs = 33_333L
        val quantizedTimeUs = ((sourceTimeUs + (frameStepUs / 2L)) / frameStepUs) * frameStepUs
        return "$sourceUri@$quantizedTimeUs"
    }

    private fun frameBitmapFromCache(cacheKey: String): Bitmap? {
        val entry =
            synchronized(lock) {
                val now = SystemClock.uptimeMillis()
                evictExpiredFrameEntries(now)
                frameCache[cacheKey]
            } ?: return null
        return runCatching {
            Bitmap.createBitmap(
                entry.pixels,
                entry.width,
                entry.height,
                Bitmap.Config.ARGB_8888,
            )
        }.getOrNull()
    }

    private fun acquireFrameRetriever(
        appContext: Context,
        sourceUri: String,
    ): MediaMetadataRetriever? {
        synchronized(lock) {
            val now = SystemClock.uptimeMillis()
            evictIdleFrameRetrievers(now)
            val cached = frameRetrieversBySourceUri[sourceUri]
            if (cached != null) {
                cached.lastUsedUptimeMs = now
                return cached.retriever
            }
            val retriever = MediaMetadataRetriever()
            return try {
                retriever.setDataSource(appContext, Uri.parse(sourceUri))
                frameRetrieversBySourceUri[sourceUri] =
                    CachedFrameRetriever(
                        retriever = retriever,
                        lastUsedUptimeMs = now,
                    )
                retriever
            } catch (_: Throwable) {
                retriever.release()
                null
            }
        }
    }

    private fun evictExpiredFrameEntries(nowUptimeMs: Long) {
        val iterator = frameCache.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next().value
            if ((nowUptimeMs - entry.cachedAtUptimeMs) > frameCacheTtlMs) {
                iterator.remove()
            }
        }
    }

    private fun evictIdleFrameRetrievers(nowUptimeMs: Long) {
        val iterator = frameRetrieversBySourceUri.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next().value
            if ((nowUptimeMs - entry.lastUsedUptimeMs) > frameRetrieverIdleTtlMs) {
                runCatching { entry.retriever.release() }
                iterator.remove()
            }
        }
    }
}

class ProfessionalVideoTransitionCompositorManager(
    private val appContext: Context,
) {
    private val rendererRegistry = ProfessionalVideoTransitionRendererRegistry.foundation()
    private val pixelFrameBufferStore = ProfessionalVideoTransitionPixelFrameBufferStore()
    private val nativeSurfaceEndpointStore =
        ProfessionalVideoTransitionNativeSurfaceEndpointStore()

    fun capabilities(): Map<String, Any> =
        mapOf(
            "dualVideoSampling" to true,
            "temporalMotionBlur" to true,
            "mirrorEdgeTiling" to true,
            "previewParity" to true,
            "liveScrubParity" to true,
            "playbackParity" to true,
            "exportParity" to false,
            "rendererVersion" to "interactive-surface-v1",
            "registeredDefinitions" to rendererRegistry.registeredDefinitionIds(),
        )

    fun registerInteractiveSurface(
        surfaceId: String?,
        width: Int,
        height: Int,
        surface: Surface?,
    ): Map<String, Any> {
        val safeSurfaceId = surfaceId?.trim().orEmpty()
        if (safeSurfaceId.isBlank() || surface == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "native_transition_interactive_surface_missing",
                "surfaceId" to safeSurfaceId,
                "registered" to false,
            )
        }
        val registration =
            nativeSurfaceEndpointStore.registerExternalEndpoint(
                endpointId = safeSurfaceId,
                width = width,
                height = height,
                surface = surface,
            )
        return mapOf(
            "status" to if (registration) "planned" else "invalidRequest",
            "reason" to if (registration) "" else "native_transition_interactive_surface_invalid",
            "surfaceId" to safeSurfaceId,
            "registered" to registration,
            "width" to width,
            "height" to height,
        )
    }

    fun unregisterInteractiveSurface(surfaceId: String?): Map<String, Any> {
        val safeSurfaceId = surfaceId?.trim().orEmpty()
        if (safeSurfaceId.isBlank()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "native_transition_interactive_surface_id_missing",
                "surfaceId" to "",
                "unregistered" to false,
            )
        }
        val removed = nativeSurfaceEndpointStore.unregisterExternalEndpoint(safeSurfaceId)
        return mapOf(
            "status" to "planned",
            "reason" to "",
            "surfaceId" to safeSurfaceId,
            "unregistered" to removed,
        )
    }

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
            endpointStore = nativeSurfaceEndpointStore,
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
            frameBufferStore = pixelFrameBufferStore,
            endpointStore = nativeSurfaceEndpointStore,
            interactiveSurfaceBindings =
                ProfessionalVideoTransitionInteractiveSurfaceBinding.fromPlan(plan),
        )
    }

    fun renderInteractiveFrame(
        plan: Map<String, Any?>?,
        timelineTimeMs: Long?,
        mode: String?,
        surfaceId: String?,
    ): Map<String, Any> {
        val missingFields = requiredRenderPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_video_transition_render_plan_fields",
                "rendererVersion" to "interactive-surface-v1",
                "missingFields" to missingFields,
                "frameDelivered" to false,
                "framePresented" to false,
                "canRenderFrame" to false,
            )
        }
        if (timelineTimeMs == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_timeline_time_for_video_transition_interactive_frame",
                "rendererVersion" to "interactive-surface-v1",
                "frameDelivered" to false,
                "framePresented" to false,
                "canRenderFrame" to false,
            )
        }
        val safeMode = mode?.trim().orEmpty()
        if (safeMode !in setOf("preview", "liveScrub", "playback")) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_interactive_mode",
                "rendererVersion" to "interactive-surface-v1",
                "mode" to safeMode,
                "frameDelivered" to false,
                "framePresented" to false,
                "canRenderFrame" to false,
            )
        }
        val safeSurfaceId = surfaceId?.trim().orEmpty()
        if (safeSurfaceId.isBlank()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "native_transition_interactive_surface_id_missing",
                "rendererVersion" to "interactive-surface-v1",
                "mode" to safeMode,
                "surfaceId" to safeSurfaceId,
                "frameDelivered" to false,
                "framePresented" to false,
                "canRenderFrame" to false,
            )
        }
        val definitionId = plan?.get("definitionId")?.toString() ?: ""
        val requestedCapabilities =
            (plan?.get("requiredCapabilities") as? List<*>)?.map { entry ->
                entry.toString()
            } ?: emptyList()
        val sessionResult = ProfessionalVideoTransitionRenderSession.fromPlan(plan)
        if (sessionResult.session == null) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "invalid_video_transition_render_session",
                "rendererVersion" to "interactive-surface-v1",
                "definitionId" to definitionId,
                "issues" to sessionResult.issues,
                "mode" to safeMode,
                "surfaceId" to safeSurfaceId,
                "frameDelivered" to false,
                "framePresented" to false,
                "canRenderFrame" to false,
            )
        }
        val session = sessionResult.session
        val registryResult =
            rendererRegistry.prepare(
                definitionId = definitionId,
                requestedCapabilities = requestedCapabilities,
            )
        if (registryResult != null) {
            return registryResult
                .withSessionMetadata(session)
                .plus(
                    mapOf(
                        "mode" to safeMode,
                        "surfaceId" to safeSurfaceId,
                        "frameDelivered" to false,
                        "framePresented" to false,
                        "canRenderFrame" to false,
                    ),
                )
        }
        val pixelRenderExecution =
            session.planTransitionPixelRenderExecution(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = plan?.get("motionBlurPolicy") as? Map<*, *>,
                edgePolicy = plan?.get("edgePolicy") as? Map<*, *>,
                parameters = plan?.get("parameters") as? Map<*, *>,
                appContext = appContext,
                frameBufferStore = pixelFrameBufferStore,
            )
        val sourceFrameBufferId =
            pixelRenderExecution["pixelOutputSourceFrameBufferId"]?.toString().orEmpty()
        val pixelOutputReady =
            pixelRenderExecution["pixelOutputWritten"] == true &&
                sourceFrameBufferId.isNotBlank()
        val upstreamBlockedReasons =
            (pixelRenderExecution["blockedReasons"] as? List<*>)?.map { reason ->
                reason.toString()
            } ?: emptyList()
        val upload =
            if (pixelOutputReady) {
                nativeSurfaceEndpointStore.uploadBoundInteractiveFrameBuffer(
                    endpointId = safeSurfaceId,
                    width = session.canvasWidth.toInt(),
                    height = session.canvasHeight.toInt(),
                    sourceFrameBufferId = sourceFrameBufferId,
                    frameBufferStore = pixelFrameBufferStore,
                )
            } else {
                ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                    endpointId = safeSurfaceId,
                    reason = "native_transition_interactive_surface_frame_source_missing",
                )
            }
        val blockedReasons =
            buildList {
                addAll(upstreamBlockedReasons)
                if (!pixelOutputReady) {
                    add("native_transition_interactive_pixel_output_missing")
                }
                if (!upload.endpointAttached) {
                    add("native_transition_${safeMode}_production_surface_missing")
                }
                if (!upload.uploaded) {
                    add("native_transition_${safeMode}_interactive_surface_frame_missing")
                }
                if (!upload.presented) {
                    add("native_transition_${safeMode}_interactive_surface_presentation_missing")
                }
                if (!upload.reason.isNullOrBlank()) {
                    add(upload.reason)
                }
                if (!upload.presentationReason.isNullOrBlank()) {
                    add(upload.presentationReason)
                }
            }.distinct()
        val canRenderFrame =
            pixelOutputReady &&
                upload.endpointAttached &&
                upload.uploaded &&
                upload.presented &&
                blockedReasons.isEmpty()
        val motionBlurEnabled =
            plan?.get("motionBlurPolicy")
                ?.let { policy -> policy as? Map<*, *> }
                ?.get("mode")
                ?.toString() == "temporalShutter"
        val sampleCount =
            (pixelRenderExecution["writerTemporalSampleCount"] as? Number)?.toInt() ?: 0
        val outgoingContributionCount =
            (pixelRenderExecution["writerOutgoingContributionCount"] as? Number)?.toInt() ?: 0
        val incomingContributionCount =
            (pixelRenderExecution["writerIncomingContributionCount"] as? Number)?.toInt() ?: 0
        val centerContributionCount =
            (pixelRenderExecution["writerCenterContributionCount"] as? Number)?.toInt() ?: 0
        val trailContributionCount =
            (pixelRenderExecution["writerTrailContributionCount"] as? Number)?.toInt() ?: 0
        val motionBlurAmount =
            (pixelRenderExecution["writerMotionBlurAmount"] as? Number)?.toDouble() ?: 0.0
        val forcedVisualTestPattern =
            pixelRenderExecution["writerForcedVisualTestPattern"] == true
        val forcedSyntheticMotionBlur =
            pixelRenderExecution["writerForcedSyntheticMotionBlur"] == true
        val sampleTransformDelta =
            (pixelRenderExecution["writerSampleTransformDelta"] as? Number)?.toDouble() ?: 0.0
        val rendererConsumedSamples =
            pixelRenderExecution["writerRendererConsumedSamples"] == true
        val renderPassIncludesTemporalMotionBlur =
            pixelRenderExecution["writerRenderPassIncludesTemporalMotionBlur"] == true
        val fallbackUsed =
            pixelRenderExecution["writerFallbackUsed"] == true
        val checksumBefore =
            (pixelRenderExecution["writerChecksumBefore"] as? Number)?.toLong() ?: 0L
        val checksumAfter =
            (pixelRenderExecution["writerChecksumAfter"] as? Number)?.toLong() ?: 0L
        val checksumDelta = checksumBefore != checksumAfter
        return mapOf(
            "status" to "planned",
            "reason" to "",
            "rendererVersion" to "interactive-surface-v1",
            "definitionId" to definitionId,
            "renderSessionId" to session.id,
            "mode" to safeMode,
            "surfaceId" to safeSurfaceId,
            "timelineTimeMs" to timelineTimeMs,
            "transitionStartMs" to session.transitionStartMs,
            "transitionEndMs" to session.transitionEndMs,
            "pixelOutputReady" to pixelOutputReady,
            "pixelOutputSourceFrameBufferId" to sourceFrameBufferId,
            "frameDelivered" to upload.uploaded,
            "framePresented" to upload.presented,
            "frameByteCount" to upload.byteCount,
            "frameChecksum" to upload.checksum,
            "presentedImageCount" to upload.presentedImageCount,
            "presentedByteCount" to upload.presentedByteCount,
            "presentedChecksum" to upload.presentedChecksum,
            "surfaceAttached" to upload.endpointAttached,
            "surfaceKind" to "interactiveNativeTransitionSurface",
            "renderOwner" to "professionalCompositor",
            "motionBlurEnabled" to motionBlurEnabled,
            "sampleCount" to sampleCount,
            "outgoingContributionCount" to outgoingContributionCount,
            "incomingContributionCount" to incomingContributionCount,
            "centerContributionCount" to centerContributionCount,
            "trailContributionCount" to trailContributionCount,
            "motionBlurAmount" to motionBlurAmount,
            "forcedVisualTestPattern" to forcedVisualTestPattern,
            "forcedSyntheticMotionBlur" to forcedSyntheticMotionBlur,
            "sampleTransformDelta" to sampleTransformDelta,
            "rendererConsumedSamples" to rendererConsumedSamples,
            "renderPassIncludesTemporalMotionBlur" to renderPassIncludesTemporalMotionBlur,
            "fallbackUsed" to fallbackUsed,
            "checksumBefore" to checksumBefore,
            "checksumAfter" to checksumAfter,
            "checksumDelta" to checksumDelta,
            "canRenderFrame" to canRenderFrame,
            "blockedReasons" to blockedReasons,
        ).withSessionMetadata(session)
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

private data class ProfessionalVideoTransitionInteractiveSurfaceBinding(
    val mode: String,
    val surfaceId: String,
    val surfaceKind: String,
    val attached: Boolean,
) {
    val isProductionTransitionSurface: Boolean
        get() =
            attached &&
                mode in parityModes &&
                surfaceId.isNotBlank() &&
                surfaceKind == "interactiveNativeTransitionSurface"

    companion object {
        private val parityModes = setOf("preview", "liveScrub", "playback")

        fun fromPlan(
            plan: Map<String, Any?>?,
        ): Map<String, ProfessionalVideoTransitionInteractiveSurfaceBinding> {
            val rawBindings = plan?.get("interactiveSurfaceBindings") as? List<*> ?: return emptyMap()
            return rawBindings
                .mapNotNull { rawBinding ->
                    val binding = rawBinding as? Map<*, *> ?: return@mapNotNull null
                    val mode = binding.stringValue("mode")
                    if (mode !in parityModes) {
                        return@mapNotNull null
                    }
                    ProfessionalVideoTransitionInteractiveSurfaceBinding(
                        mode = mode,
                        surfaceId = binding.stringValue("surfaceId"),
                        surfaceKind =
                            binding.stringValue("surfaceKind")
                                .ifBlank { "interactiveNativeTransitionSurface" },
                        attached = binding.booleanValue("attached", defaultValue = false),
                    )
                }
                .associateBy { binding -> binding.mode }
        }
    }
}

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

    private fun usesWriterBackedPixelOutput(): Boolean =
        definitionId == "manualTransform" ||
            definitionId == "manualTransformMotionBlur" ||
            definitionId == "distortionZoomInV1"

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
        val writerBackedDefinition = usesWriterBackedPixelOutput()
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
        val pixelOutputReady = pixelOutputWritten
        val rendererImplemented =
            if (writerBackedDefinition) {
                pixelOutputWritten
            } else {
                writerPlan["rendererImplemented"] == true
            }
        val upstreamBlockedReasons =
            (writerPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?.let { reasons ->
                    if (writerBackedDefinition) {
                        reasons.filter { reason ->
                            reason.startsWith("native_transition_pixel_frame_buffer_") ||
                                reason.startsWith("native_transition_temporal_")
                        }
                    } else {
                        reasons.filterNot { reason ->
                            reason == "native_transition_pixel_renderer_missing"
                        }
                    }
                }
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
        val canRenderPixels = pixelOutputWritten && rendererImplemented
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
                "canRenderPixels" to canRenderPixels,
                "rendersRealPixels" to canRenderPixels,
                "drawsPixels" to canRenderPixels,
                "canRenderFrame" to (canRenderPixels && blockedReasons.isEmpty()),
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
                    edgePolicy = edgePolicy,
                    parameters = parameters,
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
                ?.let { reasons ->
                    if (usesWriterBackedPixelOutput()) {
                        emptyList()
                    } else {
                        reasons.filterNot { reason ->
                            reason == "native_transition_pixel_frame_buffer_pixels_missing" ||
                                reason == "native_transition_pixel_frame_buffer_renderer_missing"
                        }
                    }
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
                "writerChecksumBefore" to writeResult.checksumBefore,
                "writerChecksumAfter" to writeResult.checksumAfter,
                "writerChecksumDelta" to (writeResult.checksumAfter != writeResult.checksumBefore),
                "writerSourceFrameExtractor" to "MediaMetadataRetriever.getFrameAtTime",
                "writerCanvasFillMode" to "centerCropFill",
                "writerOutgoingContributionCount" to writeResult.outgoingContributionCount,
                "writerIncomingContributionCount" to writeResult.incomingContributionCount,
                "writerCenterContributionCount" to writeResult.centerContributionCount,
                "writerTrailContributionCount" to writeResult.trailContributionCount,
                "writerMotionBlurAmount" to writeResult.motionBlurAmount,
                "writerForcedVisualTestPattern" to writeResult.forcedVisualTestPattern,
                "writerForcedSyntheticMotionBlur" to writeResult.forcedSyntheticMotionBlur,
                "writerSampleTransformDelta" to writeResult.sampleTransformDelta,
                "writerRendererConsumedSamples" to writeResult.rendererConsumedSamples,
                "writerRenderPassIncludesTemporalMotionBlur" to
                    writeResult.renderPassIncludesTemporalMotionBlur,
                "writerFallbackUsed" to writeResult.fallbackUsed,
                "writerReason" to (writeResult.reason ?: ""),
                "pixelRendererImplemented" to false,
                "pixelRendererReady" to false,
                "rendererImplemented" to writeResult.wrotePixels,
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
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
    ): ProfessionalVideoTransitionPixelFrameBufferWriteResult {
        if (definitionId == "distortionZoomInV1") {
            return writeDistortionZoomInV1PixelsToFrameBuffer(
                appContext = appContext,
                frameBufferStore = frameBufferStore,
                frameBufferId = frameBufferId,
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
            )
        }
        if (definitionId == "manualTransform" || definitionId == "manualTransformMotionBlur") {
            return writeManualTransformPixelsToFrameBuffer(
                appContext = appContext,
                frameBufferStore = frameBufferStore,
                frameBufferId = frameBufferId,
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                parameters = parameters,
            )
        }
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

    private fun writeManualTransformPixelsToFrameBuffer(
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
        frameBufferId: String,
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        parameters: Map<*, *>?,
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
        val visibilityGate =
            parameters?.get("motionBlurVisibilityGate") as? Map<*, *>
        val forcedVisualTestPattern =
            visibilityGate?.booleanValue("forcedVisualTestPattern") == true
        val forcedSyntheticMotionBlur =
            visibilityGate?.booleanValue("forcedSyntheticMotionBlur") == true
        val renderPassIncludesTemporalMotionBlur =
            motionBlurPolicy?.stringValue("mode") == "temporalShutter"
        val manualTemporalSamples =
            readManualTemporalMotionBlurSamples(
                parameters = parameters,
                fallbackTimelineSamples = timelineSamples,
                timelineTimeMs = timelineTimeMs,
            )
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
        try {
            val canvas = Canvas(canvasBitmap)
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            val validSamples =
                manualTemporalSamples.filter { sample ->
                    sample.transformMatrix3x3.size == 9 &&
                        sample.weight.isFinite() &&
                        sample.weight > 0.0 &&
                        sample.opacity.isFinite() &&
                        sample.opacity > 0.0
                }
            val sampleTransformDelta = manualMotionBlurSampleTransformDelta(validSamples)
            if (validSamples.isEmpty()) {
                if (forcedVisualTestPattern) {
                    drawMotionBlurVisibilityGateMarker(
                        canvas = canvas,
                        canvasWidth = width,
                        canvasHeight = height,
                        amount = 0.0,
                        sampleCount = 0,
                        sampleTransformDelta = 0.0,
                    )
                    val checksumBefore = frameBufferStore.checksum(frameBufferId)
                    val writeResult = frameBufferStore.writeBitmap(
                        frameBufferId = frameBufferId,
                        bitmap = canvasBitmap,
                        sampleCount = timelineSamples.size,
                        extractedFrameCount = 0,
                    )
                    return writeResult.copy(
                        forcedVisualTestPattern = true,
                        forcedSyntheticMotionBlur = false,
                        sampleTransformDelta = 0.0,
                        rendererConsumedSamples = false,
                        renderPassIncludesTemporalMotionBlur = renderPassIncludesTemporalMotionBlur,
                        fallbackUsed = true,
                        checksumBefore = checksumBefore,
                        checksumAfter = writeResult.checksum,
                    )
                }
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = 0,
                    reason = "native_transition_manual_temporal_samples_missing",
                )
            }
            val motionBlurAmount =
                validSamples.maxOf { sample -> sample.amount.coerceIn(0.0, 1.0) }
            val centerDistance =
                validSamples.minOf { sample -> abs(sample.timelineTimeMs - timelineTimeMs) }
            val centerSamples =
                validSamples.filter { sample ->
                    abs(sample.timelineTimeMs - timelineTimeMs) == centerDistance
                }.ifEmpty {
                    listOf(
                        validSamples.minByOrNull { sample ->
                            abs(sample.timelineTimeMs - timelineTimeMs)
                        } ?: validSamples.first(),
                    )
                }
            val centerBySource =
                centerSamples.associateBy { sample ->
                    sample.sourceRole.takeIf { it.isNotBlank() } ?: sample.sourceClipId
                }
            val trailSamples =
                if (motionBlurAmount <= 0.0001) {
                    emptyList()
                } else {
                    validSamples.filter { sample ->
                        val sourceKey = sample.sourceRole.takeIf { it.isNotBlank() } ?: sample.sourceClipId
                        val centerSample = centerBySource[sourceKey] ?: centerSamples.firstOrNull()
                        centerSample == null ||
                            sample !== centerSample &&
                            manualMotionBlurSampleHasVisibleTrailDelta(sample, centerSample)
                    }
                }
            val trailWeightTotal =
                trailSamples.sumOf { sample -> sample.weight.coerceAtLeast(0.0) }
                    .takeIf { weight -> weight.isFinite() && weight > 0.0 } ?: 1.0
            var outgoingContributionCount = 0
            var incomingContributionCount = 0
            var centerContributionCount = 0
            var trailContributionCount = 0
            centerSamples.forEach { sample ->
                val source = sourceForManualTemporalSample(sample) ?: return@forEach
                if (!source.coversTimelineTime(sample.timelineTimeMs)) {
                    return@forEach
                }
                val frame =
                    extractVideoFrameBitmap(
                        appContext,
                        source.sourceUri,
                        sample.sourcePositionMs
                            ?: source.sourceTimeForTimelineTime(sample.timelineTimeMs),
                    )
                if (frame != null) {
                    val sampleAlpha =
                        (sample.opacity * 255.0).roundToInt().coerceIn(0, 255)
                    if (sampleAlpha > 0) {
                        drawBitmapCenterCropMatrixTransform(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = sampleAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                            transformMatrix3x3 = sample.transformMatrix3x3,
                        )
                    }
                    when (sample.sourceRole) {
                        "outgoing" -> outgoingContributionCount += 1
                        "incoming" -> incomingContributionCount += 1
                    }
                    centerContributionCount += 1
                    extractedFrameCount += 1
                    frame.recycle()
                }
            }
            trailSamples.forEach { sample ->
                val source = sourceForManualTemporalSample(sample) ?: return@forEach
                if (!source.coversTimelineTime(sample.timelineTimeMs)) {
                    return@forEach
                }
                val frame =
                    extractVideoFrameBitmap(
                        appContext,
                        source.sourceUri,
                        sample.sourcePositionMs
                            ?: source.sourceTimeForTimelineTime(sample.timelineTimeMs),
                    )
                if (frame != null) {
                    val normalizedTrailWeight = sample.weight.coerceAtLeast(0.0) / trailWeightTotal
                    val sampleAlpha =
                        (sample.opacity * motionBlurAmount * normalizedTrailWeight * 255.0)
                            .roundToInt()
                            .coerceIn(0, 255)
                    if (sampleAlpha > 0) {
                        drawBitmapCenterCropMatrixTransform(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = sampleAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                            transformMatrix3x3 = sample.transformMatrix3x3,
                        )
                        trailContributionCount += 1
                    }
                    when (sample.sourceRole) {
                        "outgoing" -> outgoingContributionCount += 1
                        "incoming" -> incomingContributionCount += 1
                    }
                    extractedFrameCount += 1
                    frame.recycle()
                }
            }
            var syntheticMotionBlurRendered = false
            if (
                forcedSyntheticMotionBlur &&
                    motionBlurAmount > 0.0001 &&
                    validSamples.size > 1 &&
                    sampleTransformDelta > 0.0001
            ) {
                drawForcedSyntheticMotionBlurGate(
                    canvas = canvas,
                    canvasWidth = width,
                    canvasHeight = height,
                    amount = motionBlurAmount,
                    sampleCount = validSamples.size,
                    sampleTransformDelta = sampleTransformDelta,
                )
                syntheticMotionBlurRendered = true
            }
            if (forcedVisualTestPattern) {
                drawMotionBlurVisibilityGateMarker(
                    canvas = canvas,
                    canvasWidth = width,
                    canvasHeight = height,
                    amount = motionBlurAmount,
                    sampleCount = validSamples.size,
                    sampleTransformDelta = sampleTransformDelta,
                )
            }
            if (extractedFrameCount <= 0) {
                if (forcedVisualTestPattern || syntheticMotionBlurRendered) {
                    val checksumBefore = frameBufferStore.checksum(frameBufferId)
                    val writeResult = frameBufferStore.writeBitmap(
                        frameBufferId = frameBufferId,
                        bitmap = canvasBitmap,
                        sampleCount = validSamples.size,
                        extractedFrameCount = 0,
                    )
                    return writeResult.copy(
                        outgoingContributionCount = outgoingContributionCount,
                        incomingContributionCount = incomingContributionCount,
                        centerContributionCount = centerContributionCount,
                        trailContributionCount = trailContributionCount,
                        motionBlurAmount = motionBlurAmount,
                        forcedVisualTestPattern = forcedVisualTestPattern,
                        forcedSyntheticMotionBlur = syntheticMotionBlurRendered,
                        sampleTransformDelta = sampleTransformDelta,
                        rendererConsumedSamples = validSamples.size > 1,
                        renderPassIncludesTemporalMotionBlur =
                            renderPassIncludesTemporalMotionBlur,
                        fallbackUsed = true,
                        checksumBefore = checksumBefore,
                        checksumAfter = writeResult.checksum,
                    )
                }
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = 0,
                    reason = "native_transition_manual_video_pixels_missing",
                    outgoingContributionCount = outgoingContributionCount,
                    incomingContributionCount = incomingContributionCount,
                    centerContributionCount = centerContributionCount,
                    trailContributionCount = trailContributionCount,
                    motionBlurAmount = motionBlurAmount,
                )
            }
            val checksumBefore = frameBufferStore.checksum(frameBufferId)
            val writeResult = frameBufferStore.writeBitmap(
                frameBufferId = frameBufferId,
                bitmap = canvasBitmap,
                sampleCount = manualTemporalSamples.size,
                extractedFrameCount = extractedFrameCount,
            )
            return writeResult.copy(
                outgoingContributionCount = outgoingContributionCount,
                incomingContributionCount = incomingContributionCount,
                centerContributionCount = centerContributionCount,
                trailContributionCount = trailContributionCount,
                motionBlurAmount = motionBlurAmount,
                forcedVisualTestPattern = forcedVisualTestPattern,
                forcedSyntheticMotionBlur = syntheticMotionBlurRendered,
                sampleTransformDelta = sampleTransformDelta,
                rendererConsumedSamples = validSamples.size > 1,
                renderPassIncludesTemporalMotionBlur =
                    renderPassIncludesTemporalMotionBlur,
                fallbackUsed = false,
                checksumBefore = checksumBefore,
                checksumAfter = writeResult.checksum,
            )
        } finally {
            canvasBitmap.recycle()
        }
    }

    private data class ManualTemporalMotionBlurSample(
        val timelineTimeMs: Long,
        val sourceRole: String,
        val sourceClipId: String,
        val sourcePositionMs: Long?,
        val transformMatrix3x3: List<Double>,
        val opacity: Double,
        val weight: Double,
        val amount: Double,
        val transitionProgress: Double,
    )

    private fun sourceForManualTemporalSample(
        sample: ManualTemporalMotionBlurSample,
    ): ProfessionalVideoTransitionRenderSource? {
        if (sample.sourceRole == "outgoing") {
            return outgoing
        }
        if (sample.sourceRole == "incoming") {
            return incoming
        }
        return when (sample.sourceClipId) {
            outgoing.clipId -> outgoing
            incoming.clipId -> incoming
            else ->
                if (sample.timelineTimeMs < boundaryTimeMs) {
                    outgoing
                } else {
                    incoming
                }
        }
    }

    private fun manualMotionBlurSampleHasVisibleTrailDelta(
        sample: ManualTemporalMotionBlurSample,
        centerSample: ManualTemporalMotionBlurSample,
    ): Boolean {
        if (sample.sourceRole != centerSample.sourceRole || sample.sourceClipId != centerSample.sourceClipId) {
            return true
        }
        val matrixDelta =
            sample.transformMatrix3x3.zip(centerSample.transformMatrix3x3)
                .sumOf { (sampleValue, centerValue) -> abs(sampleValue - centerValue) }
        return matrixDelta > 0.0001
    }

    private fun manualMotionBlurSampleTransformDelta(
        samples: List<ManualTemporalMotionBlurSample>,
    ): Double {
        if (samples.size <= 1) {
            return 0.0
        }
        val first = samples.first().transformMatrix3x3
        return samples.drop(1).maxOf { sample ->
            sample.transformMatrix3x3.zip(first)
                .sumOf { (sampleValue, firstValue) -> abs(sampleValue - firstValue) }
        }
    }

    private fun drawMotionBlurVisibilityGateMarker(
        canvas: Canvas,
        canvasWidth: Int,
        canvasHeight: Int,
        amount: Double,
        sampleCount: Int,
        sampleTransformDelta: Double,
    ) {
        val markerWidth = min(canvasWidth, max(96, canvasWidth / 5))
        val markerHeight = min(canvasHeight, max(48, canvasHeight / 16))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.style = Paint.Style.FILL
        paint.color = Color.argb(230, 0, 220, 90)
        canvas.drawRect(
            0f,
            0f,
            markerWidth.toFloat(),
            markerHeight.toFloat(),
            paint,
        )
        paint.color = Color.argb(245, 255, 40, 120)
        val amountWidth =
            (markerWidth * amount.coerceIn(0.0, 1.0)).toFloat().coerceAtLeast(8f)
        canvas.drawRect(
            0f,
            markerHeight * 0.68f,
            amountWidth,
            markerHeight.toFloat(),
            paint,
        )
        paint.color = Color.argb(245, 255, 255, 255)
        val sampleRadius = (min(markerWidth, markerHeight) * 0.12f)
            .coerceAtLeast(5f)
        val sampleDots = sampleCount.coerceIn(1, 12)
        for (index in 0 until sampleDots) {
            canvas.drawCircle(
                markerWidth - sampleRadius - index * sampleRadius * 2.2f,
                markerHeight * 0.35f,
                sampleRadius,
                paint,
            )
        }
        if (sampleTransformDelta > 0.0001) {
            paint.color = Color.argb(245, 60, 120, 255)
            canvas.drawCircle(
                markerWidth * 0.18f,
                markerHeight * 0.35f,
                markerHeight * 0.22f,
                paint,
            )
        }
    }

    private fun drawForcedSyntheticMotionBlurGate(
        canvas: Canvas,
        canvasWidth: Int,
        canvasHeight: Int,
        amount: Double,
        sampleCount: Int,
        sampleTransformDelta: Double,
    ) {
        val centerX = canvasWidth * 0.5f
        val centerY = canvasHeight * 0.5f
        val radius = min(canvasWidth, canvasHeight) * 0.28f
        val normalizedAmount = amount.coerceIn(0.0, 1.0).toFloat()
        val normalizedDelta = sampleTransformDelta.coerceIn(0.0, 8.0).toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.style = Paint.Style.STROKE
        paint.strokeCap = Paint.Cap.ROUND
        val strokeWidth = (6f + normalizedAmount * 22f).coerceAtMost(32f)
        paint.strokeWidth = strokeWidth
        val arcBounds = RectF(
            centerX - radius,
            centerY - radius,
            centerX + radius,
            centerY + radius,
        )
        val rings = sampleCount.coerceIn(3, 14)
        for (index in 0 until rings) {
            val fraction = index / max(1f, (rings - 1).toFloat())
            paint.color = Color.argb(
                (42 + normalizedAmount * 120f).roundToInt().coerceIn(32, 190),
                70,
                (180 + 60 * fraction).roundToInt().coerceIn(0, 255),
                255,
            )
            val sweep = 16f + normalizedAmount * 110f + normalizedDelta * 4f
            canvas.drawArc(
                arcBounds,
                -80f + fraction * 210f,
                sweep,
                false,
                paint,
            )
        }
        paint.style = Paint.Style.FILL
        paint.color = Color.argb(210, 255, 255, 255)
        canvas.drawCircle(centerX, centerY, 8f + normalizedAmount * 12f, paint)
    }

    private fun readManualTemporalMotionBlurSamples(
        parameters: Map<*, *>?,
        fallbackTimelineSamples: List<Long>,
        timelineTimeMs: Long,
    ): List<ManualTemporalMotionBlurSample> {
        val plans =
            (parameters?.get("temporalMotionBlurSamplePlans") as? List<*>)
                ?.mapNotNull { entry -> entry as? Map<*, *> }
                ?: emptyList()
        if (plans.isEmpty()) {
            return fallbackTimelineSamples.map { sampleTimeMs ->
                val source =
                    if (sampleTimeMs < boundaryTimeMs) {
                        outgoing
                    } else {
                        incoming
                    }
                ManualTemporalMotionBlurSample(
                    timelineTimeMs = sampleTimeMs,
                    sourceRole = if (sampleTimeMs < boundaryTimeMs) "outgoing" else "incoming",
                    sourceClipId = source.clipId,
                    sourcePositionMs = source.sourceTimeForTimelineTime(sampleTimeMs),
                    transformMatrix3x3 = identityMatrix3x3(),
                    opacity = 1.0,
                    weight = 1.0,
                    amount = 0.0,
                    transitionProgress = transitionProgressAt(sampleTimeMs),
                )
            }
        }
        val aggregated = mutableListOf<ManualTemporalMotionBlurSample>()
        plans.forEach { plan ->
            val amount = plan.doubleValue("amount", defaultValue = 1.0).coerceIn(0.0, 1.0)
            val sampleWeights =
                (plan["sampleWeights"] as? List<*>)?.mapNotNull { value ->
                    when (value) {
                        is Number -> value.toDouble()
                        is String -> value.toDoubleOrNull()
                        else -> null
                    }
                } ?: emptyList()
            val contributionMaps =
                (plan["sampleContributions"] as? List<*>)?.mapNotNull { entry ->
                    entry as? Map<*, *>
                } ?: emptyList()
            if (contributionMaps.isNotEmpty()) {
                contributionMaps.forEach { contribution ->
                    val sampleIndex =
                        contribution.intValue("sampleIndex", defaultValue = 0).coerceAtLeast(0)
                    val timelineSampleMs =
                        when (val value = contribution["timelineTimeMs"]) {
                            is Number -> value.toLong()
                            is String -> value.toLongOrNull() ?: timelineTimeMs
                            else -> timelineTimeMs
                        }
                    val sourceRole = contribution.stringValue("sourceRole")
                    val sourceClipId = contribution.stringValue("sourceClipId")
                    val sourcePositionMs =
                        if (contribution.containsKey("sourcePositionMs")) {
                            contribution.longValue("sourcePositionMs")
                        } else {
                            null
                        }
                    val transform =
                        (contribution["transformMatrix3x3"] as? List<*>)
                            ?.mapNotNull { value ->
                                when (value) {
                                    is Number -> value.toDouble()
                                    is String -> value.toDoubleOrNull()
                                    else -> null
                                }
                            }?.takeIf { values -> values.size == 9 } ?: identityMatrix3x3()
                    val opacity =
                        contribution.doubleValue("opacity", defaultValue = 1.0).coerceIn(0.0, 1.0)
                    val transitionProgress =
                        contribution.doubleValue(
                            "transitionProgress",
                            defaultValue = transitionProgressAt(timelineSampleMs),
                        ).coerceIn(0.0, 1.0)
                    val baseWeight =
                        sampleWeights.getOrNull(sampleIndex)?.coerceAtLeast(0.0)
                            ?: if (sampleWeights.isEmpty()) 1.0 else 0.0
                    val finalWeight = baseWeight.coerceAtLeast(0.0001)
                    aggregated.add(
                        ManualTemporalMotionBlurSample(
                            timelineTimeMs = timelineSampleMs,
                            sourceRole = sourceRole,
                            sourceClipId = sourceClipId,
                            sourcePositionMs = sourcePositionMs,
                            transformMatrix3x3 = transform,
                            opacity = opacity,
                            weight = finalWeight,
                            amount = amount,
                            transitionProgress = transitionProgress,
                        ),
                    )
                }
                return@forEach
            }
            val targetId = plan.stringValue("targetId")
            val sampleTimes =
                (plan["sampleTimesMs"] as? List<*>)?.mapNotNull { sample ->
                    when (sample) {
                        is Number -> sample.toLong()
                        is String -> sample.toLongOrNull()
                        else -> null
                    }
                } ?: emptyList()
            if (sampleTimes.isEmpty()) {
                return@forEach
            }
            val sampleTransforms =
                (plan["sampleTransforms"] as? List<*>)?.mapNotNull { entry ->
                    (entry as? List<*>)?.mapNotNull { value ->
                        when (value) {
                            is Number -> value.toDouble()
                            is String -> value.toDoubleOrNull()
                            else -> null
                        }
                    }?.takeIf { values -> values.size == 9 }
                } ?: emptyList()
            val sourceIds =
                (plan["sourceIdsBySample"] as? List<*>)?.map { source ->
                    source?.toString().orEmpty()
                } ?: emptyList()
            val sampleOpacities =
                (plan["sampleOpacities"] as? List<*>)?.map { value ->
                    when (value) {
                        is Number -> value.toDouble()
                        is String -> value.toDoubleOrNull() ?: 1.0
                        else -> 1.0
                    }
                } ?: emptyList()
            if (sampleTransforms.isEmpty()) {
                return@forEach
            }
            sampleTimes.forEachIndexed { index, sampleTime ->
                val transform =
                    sampleTransforms.getOrElse(index) {
                        sampleTransforms.last()
                    }
                val sourceId =
                    sourceIds.getOrNull(index)
                        ?.takeIf { value -> value.isNotBlank() } ?: targetId
                val opacity = sampleOpacities.getOrNull(index) ?: 1.0
                val resolvedSource =
                    if (sourceId == outgoing.clipId) {
                        outgoing
                    } else if (sourceId == incoming.clipId) {
                        incoming
                    } else if (sampleTime < boundaryTimeMs) {
                        outgoing
                    } else {
                        incoming
                    }
                aggregated.add(
                    ManualTemporalMotionBlurSample(
                        timelineTimeMs = sampleTime,
                        sourceRole =
                            if (resolvedSource.clipId == outgoing.clipId) {
                                "outgoing"
                            } else {
                                "incoming"
                            },
                        sourceClipId = sourceId,
                        sourcePositionMs =
                            resolvedSource.sourceTimeForTimelineTime(sampleTime),
                        transformMatrix3x3 = transform,
                        opacity = opacity.coerceIn(0.0, 1.0),
                        weight = 1.0,
                        amount = amount,
                        transitionProgress = transitionProgressAt(sampleTime),
                    ),
                )
            }
        }
        if (aggregated.isEmpty()) {
            return listOf(
                ManualTemporalMotionBlurSample(
                    timelineTimeMs = timelineTimeMs,
                    sourceRole = if (timelineTimeMs < boundaryTimeMs) "outgoing" else "incoming",
                    sourceClipId = if (timelineTimeMs < boundaryTimeMs) outgoing.clipId else incoming.clipId,
                    sourcePositionMs =
                        if (timelineTimeMs < boundaryTimeMs) {
                            outgoing.sourceTimeForTimelineTime(timelineTimeMs)
                        } else {
                            incoming.sourceTimeForTimelineTime(timelineTimeMs)
                        },
                    transformMatrix3x3 = identityMatrix3x3(),
                    opacity = 1.0,
                    weight = 1.0,
                    amount = 0.0,
                    transitionProgress = transitionProgressAt(timelineTimeMs),
                ),
            )
        }
        return aggregated.sortedBy { sample -> sample.timelineTimeMs }
    }

    private fun writeDistortionZoomInV1PixelsToFrameBuffer(
        appContext: Context,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
        frameBufferId: String,
        timelineTimeMs: Long,
        motionBlurPolicy: Map<*, *>?,
        edgePolicy: Map<*, *>?,
        parameters: Map<*, *>?,
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
        val outgoingBoostScale =
            parameters
                ?.doubleValue("outgoingBoostScale", defaultValue = 3.0)
                ?.coerceIn(1.0, 4.0) ?: 3.0
        val incomingStartScale =
            parameters
                ?.doubleValue("incomingStartScale", defaultValue = 0.25)
                ?.coerceIn(0.12, 1.0) ?: 0.25
        val lensDistortionPeak =
            parameters
                ?.doubleValue("lensDistortionPeak", defaultValue = 0.32)
                ?.coerceIn(0.0, 0.85) ?: 0.32
        val chromaticAberrationPeak =
            parameters
                ?.doubleValue("chromaticAberrationPeak", defaultValue = 0.08)
                ?.coerceIn(0.0, 0.22) ?: 0.08
        val tileOutputScaleX =
            (edgePolicy?.doubleValue("outputScaleX", defaultValue = 4.0)
                ?: parameters?.doubleValue("motionTileOutputScaleX", defaultValue = 4.0)
                ?: 4.0).coerceIn(1.0, 6.0)
        val tileOutputScaleY =
            (edgePolicy?.doubleValue("outputScaleY", defaultValue = 4.0)
                ?: parameters?.doubleValue("motionTileOutputScaleY", defaultValue = 4.0)
                ?: 4.0).coerceIn(1.0, 6.0)
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
            val sampleAlpha = temporalSampleAlpha(255, timelineSamples.size.coerceAtLeast(1))
            timelineSamples.forEach { sampleTimelineMs ->
                val sampleProgress = transitionProgressAt(sampleTimelineMs)
                val seamPeak = seamPeakProgress(sampleTimelineMs)
                if (sampleTimelineMs <= boundaryTimeMs && outgoing.coversTimelineTime(sampleTimelineMs)) {
                    val phase =
                        phaseProgress(
                            timeMs = sampleTimelineMs,
                            startMs = transitionStartMs,
                            endMs = boundaryTimeMs,
                        )
                    val scale = lerp(1.0, outgoingBoostScale, easeInCubic(phase))
                    val frame =
                        extractVideoFrameBitmap(
                            appContext,
                            outgoing.sourceUri,
                            outgoing.sourceTimeForTimelineTime(sampleTimelineMs),
                        )
                    if (frame != null) {
                        drawDistortionZoomFrame(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = sampleAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                            scale = scale,
                            lensDistortion = lensDistortionPeak * seamPeak,
                            chromaticAberration = chromaticAberrationPeak * seamPeak,
                            tileOutputScaleX = tileOutputScaleX,
                            tileOutputScaleY = tileOutputScaleY,
                        )
                        extractedFrameCount += 1
                        outgoingFrameCount += 1
                        frame.recycle()
                    }
                }
                if (sampleTimelineMs >= boundaryTimeMs && incoming.coversTimelineTime(sampleTimelineMs)) {
                    val phase =
                        phaseProgress(
                            timeMs = sampleTimelineMs,
                            startMs = boundaryTimeMs,
                            endMs = transitionEndMs,
                        )
                    val scale = lerp(incomingStartScale, 1.0, easeOutCubic(phase))
                    val frame =
                        extractVideoFrameBitmap(
                            appContext,
                            incoming.sourceUri,
                            incoming.sourceTimeForTimelineTime(sampleTimelineMs),
                        )
                    if (frame != null) {
                        drawDistortionZoomFrame(
                            canvas = canvas,
                            bitmap = frame,
                            alpha = sampleAlpha,
                            canvasWidth = width,
                            canvasHeight = height,
                            scale = scale,
                            lensDistortion = lensDistortionPeak * seamPeak,
                            chromaticAberration = chromaticAberrationPeak * seamPeak,
                            tileOutputScaleX = tileOutputScaleX,
                            tileOutputScaleY = tileOutputScaleY,
                        )
                        extractedFrameCount += 1
                        incomingFrameCount += 1
                        frame.recycle()
                    }
                }
            }
            if (outgoingFrameCount <= 0 && timelineTimeMs < boundaryTimeMs) {
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = extractedFrameCount,
                    reason = "native_transition_outgoing_video_pixels_missing",
                )
            }
            if (incomingFrameCount <= 0 && timelineTimeMs > boundaryTimeMs) {
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = extractedFrameCount,
                    reason = "native_transition_incoming_video_pixels_missing",
                )
            }
            if (extractedFrameCount <= 0) {
                return ProfessionalVideoTransitionPixelFrameBufferWriteResult(
                    wrotePixels = false,
                    byteCount = 0,
                    checksum = 0L,
                    sampleCount = timelineSamples.size,
                    extractedFrameCount = 0,
                    reason = "native_transition_temporal_video_pixels_missing",
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

    private fun transitionProgressAt(timeMs: Long): Double =
        ((timeMs - transitionStartMs).toDouble() /
            (transitionEndMs - transitionStartMs).coerceAtLeast(1L).toDouble())
            .coerceIn(0.0, 1.0)

    private fun phaseProgress(
        timeMs: Long,
        startMs: Long,
        endMs: Long,
    ): Double =
        ((timeMs - startMs).toDouble() / (endMs - startMs).coerceAtLeast(1L).toDouble())
            .coerceIn(0.0, 1.0)

    private fun seamPeakProgress(timeMs: Long): Double {
        val leading = leadingDurationMs.coerceAtLeast(1L).toDouble()
        val trailing = trailingDurationMs.coerceAtLeast(1L).toDouble()
        return if (timeMs <= boundaryTimeMs) {
            (1.0 - ((boundaryTimeMs - timeMs).toDouble() / leading)).coerceIn(0.0, 1.0)
        } else {
            (1.0 - ((timeMs - boundaryTimeMs).toDouble() / trailing)).coerceIn(0.0, 1.0)
        }
    }

    private fun easeInCubic(t: Double): Double = t.coerceIn(0.0, 1.0).let { it * it * it }

    private fun easeOutCubic(t: Double): Double =
        t.coerceIn(0.0, 1.0).let { 1.0 - ((1.0 - it) * (1.0 - it) * (1.0 - it)) }

    private fun lerp(start: Double, end: Double, progress: Double): Double =
        start + ((end - start) * progress.coerceIn(0.0, 1.0))

    private fun drawDistortionZoomFrame(
        canvas: Canvas,
        bitmap: Bitmap,
        alpha: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        scale: Double,
        lensDistortion: Double,
        chromaticAberration: Double,
        tileOutputScaleX: Double,
        tileOutputScaleY: Double,
    ) {
        if (alpha <= 0 || bitmap.width <= 0 || bitmap.height <= 0) {
            return
        }
        val baseTile =
            runCatching {
                Bitmap.createBitmap(canvasWidth, canvasHeight, Bitmap.Config.ARGB_8888)
            }.getOrNull() ?: return
        val layer =
            runCatching {
                Bitmap.createBitmap(canvasWidth, canvasHeight, Bitmap.Config.ARGB_8888)
            }.getOrNull()
        if (layer == null) {
            baseTile.recycle()
            return
        }
        try {
            drawBitmapCenterCrop(
                canvas = Canvas(baseTile),
                bitmap = bitmap,
                alpha = 255,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
            )
            val layerCanvas = Canvas(layer)
            drawMirroredScaledTile(
                canvas = layerCanvas,
                tile = baseTile,
                alpha = 255,
                canvasWidth = canvasWidth,
                canvasHeight = canvasHeight,
                scale = scale,
                outputScaleX = tileOutputScaleX,
                outputScaleY = tileOutputScaleY,
            )
            drawLayerWithLensDistortion(
                canvas = canvas,
                layer = layer,
                alpha = alpha,
                lensDistortion = lensDistortion,
                chromaticAberration = chromaticAberration,
            )
        } finally {
            baseTile.recycle()
            layer.recycle()
        }
    }

    private fun drawMirroredScaledTile(
        canvas: Canvas,
        tile: Bitmap,
        alpha: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        scale: Double,
        outputScaleX: Double,
        outputScaleY: Double,
    ) {
        val safeScale = scale.coerceIn(0.05, 8.0).toFloat()
        val tileWidth = canvasWidth * safeScale
        val tileHeight = canvasHeight * safeScale
        val repeatX =
            max(
                1,
                ceil((canvasWidth * outputScaleX) / max(1.0, tileWidth.toDouble())).toInt(),
            )
        val repeatY =
            max(
                1,
                ceil((canvasHeight * outputScaleY) / max(1.0, tileHeight.toDouble())).toInt(),
            )
        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
                this.alpha = alpha.coerceIn(0, 255)
            }
        val centerX = canvasWidth / 2f
        val centerY = canvasHeight / 2f
        for (xIndex in -repeatX..repeatX) {
            for (yIndex in -repeatY..repeatY) {
                val tileCenterX = centerX + (xIndex * tileWidth)
                val tileCenterY = centerY + (yIndex * tileHeight)
                canvas.save()
                canvas.translate(tileCenterX, tileCenterY)
                canvas.scale(
                    if (abs(xIndex) % 2 == 0) 1f else -1f,
                    if (abs(yIndex) % 2 == 0) 1f else -1f,
                )
                canvas.drawBitmap(
                    tile,
                    Rect(0, 0, tile.width, tile.height),
                    RectF(-tileWidth / 2f, -tileHeight / 2f, tileWidth / 2f, tileHeight / 2f),
                    paint,
                )
                canvas.restore()
            }
        }
    }

    private fun drawLayerWithLensDistortion(
        canvas: Canvas,
        layer: Bitmap,
        alpha: Int,
        lensDistortion: Double,
        chromaticAberration: Double,
    ) {
        val meshWidth = 24
        val meshHeight = 24
        val baseVerts =
            distortionMeshVertices(
                bitmapWidth = layer.width,
                bitmapHeight = layer.height,
                meshWidth = meshWidth,
                meshHeight = meshHeight,
                lensDistortion = lensDistortion,
                xOffset = 0f,
                yOffset = 0f,
            )
        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
                this.alpha = alpha.coerceIn(0, 255)
            }
        val chromaticShift =
            (min(layer.width, layer.height) * chromaticAberration.coerceIn(0.0, 0.25) * 0.018)
                .toFloat()
        if (chromaticShift > 0.25f) {
            canvas.drawBitmapMesh(
                layer,
                meshWidth,
                meshHeight,
                distortionMeshVertices(
                    bitmapWidth = layer.width,
                    bitmapHeight = layer.height,
                    meshWidth = meshWidth,
                    meshHeight = meshHeight,
                    lensDistortion = lensDistortion,
                    xOffset = -chromaticShift,
                    yOffset = 0f,
                ),
                0,
                null,
                0,
                redChannelPaint(alpha),
            )
            canvas.drawBitmapMesh(
                layer,
                meshWidth,
                meshHeight,
                distortionMeshVertices(
                    bitmapWidth = layer.width,
                    bitmapHeight = layer.height,
                    meshWidth = meshWidth,
                    meshHeight = meshHeight,
                    lensDistortion = lensDistortion,
                    xOffset = chromaticShift,
                    yOffset = 0f,
                ),
                0,
                null,
                0,
                blueChannelPaint(alpha),
            )
        }
        canvas.drawBitmapMesh(layer, meshWidth, meshHeight, baseVerts, 0, null, 0, paint)
    }

    private fun distortionMeshVertices(
        bitmapWidth: Int,
        bitmapHeight: Int,
        meshWidth: Int,
        meshHeight: Int,
        lensDistortion: Double,
        xOffset: Float,
        yOffset: Float,
    ): FloatArray {
        val verts = FloatArray((meshWidth + 1) * (meshHeight + 1) * 2)
        val centerX = bitmapWidth / 2f
        val centerY = bitmapHeight / 2f
        val distortion = lensDistortion.coerceIn(0.0, 0.85).toFloat()
        var index = 0
        for (y in 0..meshHeight) {
            val fy = y / meshHeight.toFloat()
            val sourceY = fy * bitmapHeight
            for (x in 0..meshWidth) {
                val fx = x / meshWidth.toFloat()
                val sourceX = fx * bitmapWidth
                val nx = ((sourceX - centerX) / centerX).coerceIn(-1f, 1f)
                val ny = ((sourceY - centerY) / centerY).coerceIn(-1f, 1f)
                val radiusSquared = ((nx * nx) + (ny * ny)).coerceIn(0f, 2f)
                val factor = 1f + (distortion * radiusSquared * 0.22f)
                verts[index++] = centerX + ((sourceX - centerX) * factor) + xOffset
                verts[index++] = centerY + ((sourceY - centerY) * factor) + yOffset
            }
        }
        return verts
    }

    private fun redChannelPaint(alpha: Int): Paint =
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
            this.alpha = (alpha * 0.45).roundToInt().coerceIn(0, 255)
            colorFilter =
                ColorMatrixColorFilter(
                    ColorMatrix(
                        floatArrayOf(
                            1f, 0f, 0f, 0f, 0f,
                            0f, 0f, 0f, 0f, 0f,
                            0f, 0f, 0f, 0f, 0f,
                            0f, 0f, 0f, 1f, 0f,
                        ),
                    ),
                )
        }

    private fun blueChannelPaint(alpha: Int): Paint =
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
            this.alpha = (alpha * 0.45).roundToInt().coerceIn(0, 255)
            colorFilter =
                ColorMatrixColorFilter(
                    ColorMatrix(
                        floatArrayOf(
                            0f, 0f, 0f, 0f, 0f,
                            0f, 0f, 0f, 0f, 0f,
                            0f, 0f, 1f, 0f, 0f,
                            0f, 0f, 0f, 1f, 0f,
                        ),
                    ),
                )
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
        return TransitionFrameExtractorCache.extract(
            appContext = appContext,
            sourceUri = sourceUri,
            sourceTimeMs = sourceTimeMs,
        )
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

    private fun drawBitmapCenterCropTransform(
        canvas: Canvas,
        bitmap: Bitmap,
        alpha: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        scale: Double,
    ) {
        val safeScale = scale.coerceIn(0.1, 4.0)
        drawBitmapCenterCropMatrixTransform(
            canvas = canvas,
            bitmap = bitmap,
            alpha = alpha,
            canvasWidth = canvasWidth,
            canvasHeight = canvasHeight,
            transformMatrix3x3 =
                listOf(
                    safeScale,
                    0.0,
                    0.0,
                    0.0,
                    safeScale,
                    0.0,
                    0.0,
                    0.0,
                    1.0,
                ),
        )
    }

    private fun drawBitmapCenterCropMatrixTransform(
        canvas: Canvas,
        bitmap: Bitmap,
        alpha: Int,
        canvasWidth: Int,
        canvasHeight: Int,
        transformMatrix3x3: List<Double>,
    ) {
        if (alpha <= 0 || bitmap.width <= 0 || bitmap.height <= 0 || transformMatrix3x3.size != 9) {
            return
        }
        val sourceRect = centerCropSourceRect(bitmap = bitmap, canvasWidth = canvasWidth, canvasHeight = canvasHeight)
        val m00 = transformMatrix3x3[0].toFloat()
        val m01 = transformMatrix3x3[1].toFloat()
        val tx = transformMatrix3x3[2].toFloat()
        val m10 = transformMatrix3x3[3].toFloat()
        val m11 = transformMatrix3x3[4].toFloat()
        val ty = transformMatrix3x3[5].toFloat()
        if (!m00.isFinite() || !m01.isFinite() || !tx.isFinite() ||
            !m10.isFinite() || !m11.isFinite() || !ty.isFinite()
        ) {
            return
        }
        val paint =
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG).apply {
                this.alpha = alpha.coerceIn(0, 255)
            }
        val centerX = canvasWidth / 2f
        val centerY = canvasHeight / 2f
        val matrix =
            Matrix().apply {
                setValues(
                    floatArrayOf(
                        m00,
                        m01,
                        tx,
                        m10,
                        m11,
                        ty,
                        0f,
                        0f,
                        1f,
                    ),
                )
                postTranslate(
                    centerX - (m00 * centerX + m01 * centerY),
                    centerY - (m10 * centerX + m11 * centerY),
                )
            }
        canvas.save()
        canvas.concat(matrix)
        canvas.drawBitmap(
            bitmap,
            sourceRect,
            RectF(0f, 0f, canvasWidth.toFloat(), canvasHeight.toFloat()),
            paint,
        )
        canvas.restore()
    }

    private fun centerCropSourceRect(
        bitmap: Bitmap,
        canvasWidth: Int,
        canvasHeight: Int,
    ): Rect {
        val bitmapRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        val canvasRatio = canvasWidth.toFloat() / canvasHeight.toFloat()
        return if (bitmapRatio > canvasRatio) {
            val cropWidth = (bitmap.height * canvasRatio).roundToInt().coerceAtLeast(1)
            val left = ((bitmap.width - cropWidth) / 2).coerceAtLeast(0)
            Rect(left, 0, (left + cropWidth).coerceAtMost(bitmap.width), bitmap.height)
        } else {
            val cropHeight = (bitmap.width / canvasRatio).roundToInt().coerceAtLeast(1)
            val top = ((bitmap.height - cropHeight) / 2).coerceAtLeast(0)
            Rect(0, top, bitmap.width, (top + cropHeight).coerceAtMost(bitmap.height))
        }
    }

    private fun identityMatrix3x3(): List<Double> =
        listOf(
            1.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            0.0,
            0.0,
            1.0,
        )

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
        endpointStore: ProfessionalVideoTransitionNativeSurfaceEndpointStore,
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
        val surfaceUploadRendererImplemented = outputSurfaceUploadPacketReady
        val endpointUpload =
            if (outputSurfaceUploadPacketReady) {
                endpointStore.uploadFrameBuffer(
                    renderSessionId = id,
                    timelineTimeMs = timelineTimeMs,
                    width = canvasWidth.toInt(),
                    height = canvasHeight.toInt(),
                    sourceFrameBufferId = pixelOutputSourceFrameBufferId,
                    frameBufferStore = frameBufferStore,
                )
            } else {
                ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                    endpointId = "",
                    reason = "native_transition_surface_upload_packet_missing",
                )
            }
        val surfaceUploadRendererReady =
            surfaceUploadRendererImplemented && endpointUpload.uploaded
        val outputSurfaceEndpointAttached = endpointUpload.endpointAttached
        val outputSurfaceEndpointId = endpointUpload.endpointId
        val outputSurfaceEndpointKind =
            if (outputSurfaceEndpointAttached) {
                "offscreenNativeProofSurface"
            } else {
                "unboundNativeSurface"
            }
        val outputSurfaceUploadReason =
            when {
                !outputSurfaceUploadPacketReady ->
                    "native_transition_surface_upload_packet_missing"
                !endpointUpload.reason.isNullOrBlank() ->
                    endpointUpload.reason
                !surfaceUploadRendererReady ->
                    "native_transition_surface_upload_renderer_not_ready"
                !outputSurfaceEndpointAttached ->
                    "native_transition_surface_endpoint_missing"
                else -> ""
            }
        val pixelRenderExecutionReady =
            executionPlan["pixelRenderExecutionReady"] == true &&
                pixelOutputWritten &&
                endpointUpload.uploaded &&
                endpointUpload.endpointAttached
        val outputProofReady =
            pixelRenderExecutionReady &&
                pixelOutputWritten &&
                endpointUpload.uploaded &&
                outputSurfaceIsNative &&
                writesOnlyToNativeSurface &&
                outputSurfaceEndpointAttached
        val upstreamBlockedReasons =
            (executionPlan["blockedReasons"] as? List<*>)
                ?.map { reason -> reason.toString() }
                ?.filterNot { reason ->
                    endpointUpload.uploaded &&
                        (reason == "native_transition_pixel_output_not_ready" ||
                            reason == "native_transition_renderer_pixels_missing")
                }
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
                    if (!endpointUpload.uploaded) {
                        add("native_transition_pixel_output_not_ready")
                    }
                }
                if (!outputSurfaceUploadPacketReady) {
                    add("native_transition_surface_upload_packet_missing")
                }
                if (!surfaceUploadRendererImplemented) {
                    add("native_transition_surface_upload_renderer_missing")
                }
                if (!surfaceUploadRendererReady) {
                    add("native_transition_surface_upload_renderer_not_ready")
                }
                if (!endpointUpload.reason.isNullOrBlank()) {
                    add(endpointUpload.reason)
                }
                if (!outputSurfaceEndpointAttached) {
                    add("native_transition_surface_endpoint_missing")
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
                "outputSurfaceUploadPosted" to endpointUpload.uploaded,
                "outputSurfaceUploadEndpointByteCount" to endpointUpload.byteCount,
                "outputSurfaceUploadEndpointChecksum" to endpointUpload.checksum,
                "surfaceUploadRendererImplemented" to surfaceUploadRendererImplemented,
                "surfaceUploadRendererReady" to surfaceUploadRendererReady,
                "outputSurfaceEndpointAttached" to outputSurfaceEndpointAttached,
                "outputSurfaceEndpointId" to outputSurfaceEndpointId,
                "outputSurfaceEndpointKind" to outputSurfaceEndpointKind,
                "outputSurfaceUploadReason" to outputSurfaceUploadReason,
                "pixelRenderExecutionReady" to pixelRenderExecutionReady,
                "pixelOutputWritten" to pixelOutputWritten,
                "pixelOutputReady" to endpointUpload.uploaded,
                "outputProofReady" to outputProofReady,
                "rendererImplemented" to outputProofReady,
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
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
        endpointStore: ProfessionalVideoTransitionNativeSurfaceEndpointStore,
        interactiveSurfaceBindings: Map<String, ProfessionalVideoTransitionInteractiveSurfaceBinding>,
    ): Map<String, Any> {
        val outputProofPlan =
            planTransitionPixelOutputProof(
                timelineTimeMs = timelineTimeMs,
                motionBlurPolicy = motionBlurPolicy,
                edgePolicy = edgePolicy,
                parameters = parameters,
                appContext = appContext,
                frameBufferStore = frameBufferStore,
                endpointStore = endpointStore,
            )
        if (outputProofPlan["status"] != "planned") {
            return outputProofPlan
        }
        val rendererImplemented = outputProofPlan["rendererImplemented"] == true
        val outputSurfaceId = outputProofPlan["outputSurfaceId"]?.toString() ?: ""
        val outputTarget = outputProofPlan["outputTarget"]?.toString() ?: ""
        val outputPassId = outputProofPlan["outputPassId"]?.toString() ?: ""
        val outputPassType = outputProofPlan["outputPassType"]?.toString() ?: ""
        val outputPassInputs =
            (outputProofPlan["outputPassInputs"] as? List<*>)?.map { input ->
                input.toString()
            } ?: emptyList()
        val outputPassBound = outputProofPlan["outputPassBound"] == true
        val renderGraphOutputReady = outputProofPlan["renderGraphOutputReady"] == true
        val transitionPixelOutputProofId =
            outputProofPlan["transitionPixelOutputProofId"]?.toString() ?: ""
        val outputProofReady = outputProofPlan["outputProofReady"] == true
        val outputSurfaceUploadPacketReady =
            outputProofPlan["outputSurfaceUploadPacketReady"] == true
        val surfaceUploadRendererReady =
            outputProofPlan["surfaceUploadRendererReady"] == true
        val outputSurfaceEndpointAttached =
            outputProofPlan["outputSurfaceEndpointAttached"] == true
        val outputSurfaceEndpointId =
            outputProofPlan["outputSurfaceEndpointId"]?.toString() ?: ""
        val outputSurfaceEndpointKind =
            outputProofPlan["outputSurfaceEndpointKind"]?.toString() ?: ""
        val outputSurfaceUploadSourceFrameBufferId =
            outputProofPlan["outputSurfaceUploadSourceFrameBufferId"]?.toString() ?: ""
        val upstreamBlockedReasons =
            (outputProofPlan["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                ?: emptyList()
        val parityModes = listOf("preview", "liveScrub", "playback")
        val outputs =
            parityModes.map { mode ->
                val interactiveBinding = interactiveSurfaceBindings[mode]
                val productionBindingReady =
                    interactiveBinding?.isProductionTransitionSurface == true
                val interactiveUpload =
                    if (
                        outputProofReady &&
                        outputSurfaceUploadSourceFrameBufferId.isNotBlank() &&
                        productionBindingReady
                    ) {
                        endpointStore.uploadBoundInteractiveFrameBuffer(
                            endpointId = requireNotNull(interactiveBinding).surfaceId,
                            width = canvasWidth.toInt(),
                            height = canvasHeight.toInt(),
                            sourceFrameBufferId = outputSurfaceUploadSourceFrameBufferId,
                            frameBufferStore = frameBufferStore,
                        )
                    } else if (outputProofReady && outputSurfaceUploadSourceFrameBufferId.isNotBlank()) {
                        endpointStore.uploadInteractiveFrameBuffer(
                            renderSessionId = id,
                            mode = mode,
                            timelineTimeMs = timelineTimeMs,
                            width = canvasWidth.toInt(),
                            height = canvasHeight.toInt(),
                            sourceFrameBufferId = outputSurfaceUploadSourceFrameBufferId,
                            frameBufferStore = frameBufferStore,
                        )
                    } else {
                        ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                            endpointId = "$id:interactive-transition-$mode:$timelineTimeMs",
                            reason = "native_transition_${mode}_interactive_surface_frame_source_missing",
                        )
                    }
                val interactiveSurfaceId = interactiveUpload.endpointId
                val interactiveSurfaceKind =
                    if (interactiveUpload.endpointAttached && productionBindingReady) {
                        "interactiveNativeTransitionSurface"
                    } else if (interactiveUpload.endpointAttached) {
                        "interactiveNativePresentationProofSurface"
                    } else {
                        "unboundInteractiveSurface"
                    }
                val interactiveSurfaceBound = interactiveUpload.endpointAttached
                val interactiveSurfaceFrameDelivered = interactiveUpload.uploaded
                val interactiveSurfaceFramePresented = interactiveUpload.presented
                val interactiveSurfaceProductionBound =
                    productionBindingReady &&
                        interactiveSurfaceKind == "interactiveNativeTransitionSurface"
                val interactiveSurfaceProductionReady =
                    interactiveSurfaceProductionBound &&
                        interactiveSurfaceFrameDelivered &&
                        interactiveSurfaceFramePresented
                val interactiveSurfaceProductionReason =
                    if (interactiveSurfaceProductionReady) {
                        ""
                    } else {
                        "native_transition_${mode}_production_surface_missing"
                    }
                val blockedReasons =
                    buildList {
                        if (!outputPassBound) {
                            add("native_transition_${mode}_output_pass_missing")
                        }
                        if (!rendererImplemented) {
                            add("native_transition_${mode}_renderer_missing")
                        }
                        if (!outputProofReady) {
                            add("native_transition_${mode}_pixel_output_proof_missing")
                        }
                        if (!outputSurfaceEndpointAttached) {
                            add("native_transition_${mode}_surface_endpoint_missing")
                        }
                        if (!interactiveSurfaceBound) {
                            add("native_transition_${mode}_interactive_surface_missing")
                        }
                        if (!interactiveSurfaceFrameDelivered) {
                            add("native_transition_${mode}_interactive_surface_frame_missing")
                        }
                        if (!interactiveSurfaceFramePresented) {
                            add("native_transition_${mode}_interactive_surface_presentation_missing")
                        }
                        if (!interactiveSurfaceProductionReady) {
                            add(interactiveSurfaceProductionReason)
                        }
                        if (!interactiveUpload.reason.isNullOrBlank()) {
                            add(interactiveUpload.reason)
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
                    "transitionPixelOutputProofId" to transitionPixelOutputProofId,
                    "outputProofReady" to outputProofReady,
                    "outputSurfaceUploadPacketReady" to outputSurfaceUploadPacketReady,
                    "surfaceUploadRendererReady" to surfaceUploadRendererReady,
                    "outputSurfaceEndpointAttached" to outputSurfaceEndpointAttached,
                    "outputSurfaceEndpointId" to outputSurfaceEndpointId,
                    "outputSurfaceEndpointKind" to outputSurfaceEndpointKind,
                    "interactiveSurfaceId" to interactiveSurfaceId,
                    "interactiveSurfaceKind" to interactiveSurfaceKind,
                    "interactiveSurfaceBound" to interactiveSurfaceBound,
                    "interactiveSurfaceFrameDelivered" to interactiveSurfaceFrameDelivered,
                    "interactiveSurfaceFrameByteCount" to interactiveUpload.byteCount,
                    "interactiveSurfaceFrameChecksum" to interactiveUpload.checksum,
                    "interactiveSurfaceFrameReason" to (interactiveUpload.reason ?: ""),
                    "interactiveSurfaceFramePresented" to interactiveSurfaceFramePresented,
                    "interactiveSurfacePresentedImageCount" to interactiveUpload.presentedImageCount,
                    "interactiveSurfacePresentedByteCount" to interactiveUpload.presentedByteCount,
                    "interactiveSurfacePresentedChecksum" to interactiveUpload.presentedChecksum,
                    "interactiveSurfacePresentationReason" to (interactiveUpload.presentationReason ?: ""),
                    "interactiveSurfaceProductionBound" to interactiveSurfaceProductionBound,
                    "interactiveSurfaceProductionReady" to interactiveSurfaceProductionReady,
                    "interactiveSurfaceProductionReason" to interactiveSurfaceProductionReason,
                    "rendererImplemented" to rendererImplemented,
                    "canRender" to
                        (rendererImplemented &&
                            outputPassBound &&
                            renderGraphOutputReady &&
                            outputProofReady &&
                            outputSurfaceEndpointAttached &&
                            interactiveSurfaceBound &&
                            interactiveSurfaceFrameDelivered &&
                            interactiveSurfaceFramePresented &&
                            interactiveSurfaceProductionReady &&
                            blockedReasons.isEmpty()),
                    "blockedReasons" to blockedReasons,
                )
            }
        val interactiveSurfaceContractReady =
            outputs.isNotEmpty() &&
                outputs.all { output -> output["interactiveSurfaceBound"] == true } &&
                outputs.all { output -> output["interactiveSurfaceFrameDelivered"] == true } &&
                outputs.all { output -> output["interactiveSurfaceFramePresented"] == true } &&
                outputs.all { output -> output["interactiveSurfaceProductionReady"] == true } &&
                outputs.map { output -> output["interactiveSurfaceId"] }.distinct().size ==
                    outputs.size &&
                outputs.all { output ->
                    output["interactiveSurfaceKind"] == "interactiveNativeTransitionSurface"
                }
        val interactiveSurfaceFrameDeliveryReady =
            outputs.isNotEmpty() &&
                outputs.all { output -> output["interactiveSurfaceFrameDelivered"] == true } &&
                outputs.all { output ->
                    ((output["interactiveSurfaceFrameByteCount"] as? Number)?.toLong() ?: 0L) > 0L
                }
        val interactiveSurfacePresentationReady =
            outputs.isNotEmpty() &&
                outputs.all { output -> output["interactiveSurfaceFramePresented"] == true } &&
                outputs.all { output ->
                    ((output["interactiveSurfacePresentedByteCount"] as? Number)?.toLong() ?: 0L) > 0L
                }
        val interactiveProductionSurfaceReady =
            outputs.isNotEmpty() &&
                outputs.all { output -> output["interactiveSurfaceProductionReady"] == true }
        val blockedReasons =
            (upstreamBlockedReasons +
                outputs.flatMap { output ->
                    (output["blockedReasons"] as? List<*>)?.map { reason -> reason.toString() }
                        ?: emptyList()
                }).distinct()
        return outputProofPlan +
            mapOf(
                "transitionPixelOutputProofId" to transitionPixelOutputProofId,
                "outputProofReady" to outputProofReady,
                "outputSurfaceUploadPacketReady" to outputSurfaceUploadPacketReady,
                "surfaceUploadRendererReady" to surfaceUploadRendererReady,
                "outputSurfaceEndpointAttached" to outputSurfaceEndpointAttached,
                "outputSurfaceEndpointId" to outputSurfaceEndpointId,
                "outputSurfaceEndpointKind" to outputSurfaceEndpointKind,
                "interactiveSurfaceContractReady" to interactiveSurfaceContractReady,
                "interactiveSurfaceFrameDeliveryReady" to interactiveSurfaceFrameDeliveryReady,
                "interactiveSurfaceFrameDeliveryCount" to
                    outputs.count { output -> output["interactiveSurfaceFrameDelivered"] == true },
                "interactiveSurfacePresentationReady" to interactiveSurfacePresentationReady,
                "interactiveSurfacePresentationCount" to
                    outputs.count { output -> output["interactiveSurfaceFramePresented"] == true },
                "interactiveProductionSurfaceReady" to interactiveProductionSurfaceReady,
                "interactiveProductionSurfaceCount" to
                    outputs.count { output -> output["interactiveSurfaceProductionReady"] == true },
                "sameOutputContractForAllModes" to
                    (outputSurfaceId.isNotBlank() &&
                        outputPassBound &&
                        outputSurfaceEndpointAttached &&
                        outputs.map { output -> output["outputPassId"] }.distinct().size == 1),
                "exportDeferred" to true,
                "allModesRenderable" to
                    (rendererImplemented &&
                        outputPassBound &&
                        renderGraphOutputReady &&
                        outputProofReady &&
                        outputSurfaceEndpointAttached &&
                        interactiveSurfaceContractReady &&
                        interactiveSurfaceFrameDeliveryReady &&
                        interactiveSurfacePresentationReady &&
                        interactiveProductionSurfaceReady &&
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

private fun Map<*, *>.booleanValue(
    key: String,
    defaultValue: Boolean = false,
): Boolean =
    when (val value = this[key]) {
        is Boolean -> value
        is String -> value.equals("true", ignoreCase = true)
        is Number -> value.toInt() != 0
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
    val outgoingContributionCount: Int = 0,
    val incomingContributionCount: Int = 0,
    val centerContributionCount: Int = 0,
    val trailContributionCount: Int = 0,
    val motionBlurAmount: Double = 0.0,
    val forcedVisualTestPattern: Boolean = false,
    val forcedSyntheticMotionBlur: Boolean = false,
    val sampleTransformDelta: Double = 0.0,
    val rendererConsumedSamples: Boolean = false,
    val renderPassIncludesTemporalMotionBlur: Boolean = false,
    val fallbackUsed: Boolean = false,
    val checksumBefore: Long = 0L,
    val checksumAfter: Long = 0L,
)

private data class ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult(
    val endpointId: String,
    val endpointAttached: Boolean,
    val uploaded: Boolean,
    val byteCount: Int,
    val checksum: Long,
    val presented: Boolean,
    val presentedImageCount: Int,
    val presentedByteCount: Int,
    val presentedChecksum: Long,
    val presentationReason: String?,
    val reason: String?,
) {
    companion object {
        fun invalid(
            endpointId: String,
            reason: String,
        ): ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult =
            ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult(
                endpointId = endpointId,
                endpointAttached = false,
                uploaded = false,
                byteCount = 0,
                checksum = 0L,
                presented = false,
                presentedImageCount = 0,
                presentedByteCount = 0,
                presentedChecksum = 0L,
                presentationReason = reason,
                reason = reason,
            )
    }
}

private data class ProfessionalVideoTransitionNativeSurfaceEndpointPresentationResult(
    val presented: Boolean,
    val imageCount: Int,
    val byteCount: Int,
    val checksum: Long,
    val reason: String?,
)

private data class ProfessionalVideoTransitionNativeSurfaceEndpoint(
    val id: String,
    val width: Int,
    val height: Int,
    val imageReader: ImageReader?,
    val surface: Surface,
    val ownsSurface: Boolean,
    val kind: String,
) {
    fun close() {
        if (ownsSurface) {
            runCatching { surface.release() }
        }
        runCatching { imageReader?.close() }
    }
}

private class ProfessionalVideoTransitionNativeSurfaceEndpointStore(
    private val maxEndpoints: Int = 8,
) {
    private val endpoints =
        object : LinkedHashMap<String, ProfessionalVideoTransitionNativeSurfaceEndpoint>(
            maxEndpoints,
            0.75f,
            true,
        ) {
            override fun removeEldestEntry(
                eldest: MutableMap.MutableEntry<String, ProfessionalVideoTransitionNativeSurfaceEndpoint>?,
            ): Boolean {
                val shouldRemove = size > maxEndpoints
                if (shouldRemove) {
                    eldest?.value?.close()
                }
                return shouldRemove
            }
        }

    @Synchronized
    fun registerExternalEndpoint(
        endpointId: String,
        width: Int,
        height: Int,
        surface: Surface,
    ): Boolean {
        val safeEndpointId = endpointId.trim()
        if (
            safeEndpointId.isBlank() ||
                width <= 0 ||
                height <= 0 ||
                !surface.isValid
        ) {
            return false
        }
        endpoints[safeEndpointId]?.close()
        endpoints[safeEndpointId] =
            ProfessionalVideoTransitionNativeSurfaceEndpoint(
                id = safeEndpointId,
                width = width,
                height = height,
                imageReader = null,
                surface = surface,
                ownsSurface = false,
                kind = "interactiveNativeTransitionSurface",
            )
        return true
    }

    @Synchronized
    fun unregisterExternalEndpoint(endpointId: String): Boolean {
        val safeEndpointId = endpointId.trim()
        if (safeEndpointId.isBlank()) {
            return false
        }
        val removed = endpoints.remove(safeEndpointId) ?: return false
        removed.close()
        return true
    }

    @Synchronized
    fun uploadFrameBuffer(
        renderSessionId: String,
        timelineTimeMs: Long,
        width: Int,
        height: Int,
        sourceFrameBufferId: String,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult {
        val endpointId = "$renderSessionId:native-transition-endpoint:$timelineTimeMs"
        return uploadFrameBufferToEndpoint(
            endpointId = endpointId,
            width = width,
            height = height,
            sourceFrameBufferId = sourceFrameBufferId,
            frameBufferStore = frameBufferStore,
            allowAllocate = true,
        )
    }

    @Synchronized
    fun uploadInteractiveFrameBuffer(
        renderSessionId: String,
        mode: String,
        timelineTimeMs: Long,
        width: Int,
        height: Int,
        sourceFrameBufferId: String,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult {
        val safeMode = mode.filter { character ->
            character.isLetterOrDigit()
        }.ifBlank { "unknown" }
        val endpointId = "$renderSessionId:interactive-transition-$safeMode:$timelineTimeMs"
        return uploadFrameBufferToEndpoint(
            endpointId = endpointId,
            width = width,
            height = height,
            sourceFrameBufferId = sourceFrameBufferId,
            frameBufferStore = frameBufferStore,
            allowAllocate = true,
        )
    }

    @Synchronized
    fun uploadBoundInteractiveFrameBuffer(
        endpointId: String,
        width: Int,
        height: Int,
        sourceFrameBufferId: String,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
    ): ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult {
        val safeEndpointId = endpointId.trim()
        if (safeEndpointId.isBlank()) {
            return ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                endpointId = "",
                reason = "native_transition_interactive_surface_id_missing",
            )
        }
        return uploadFrameBufferToEndpoint(
            endpointId = safeEndpointId,
            width = width,
            height = height,
            sourceFrameBufferId = sourceFrameBufferId,
            frameBufferStore = frameBufferStore,
            allowAllocate = false,
        )
    }

    private fun uploadFrameBufferToEndpoint(
        endpointId: String,
        width: Int,
        height: Int,
        sourceFrameBufferId: String,
        frameBufferStore: ProfessionalVideoTransitionPixelFrameBufferStore,
        allowAllocate: Boolean,
    ): ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult {
        if (width <= 0 || height <= 0) {
            return ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                endpointId = endpointId,
                reason = "native_transition_surface_endpoint_invalid_size",
            )
        }
        if (sourceFrameBufferId.isBlank()) {
            return ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                endpointId = endpointId,
                reason = "native_transition_surface_upload_source_frame_buffer_missing",
            )
        }
        val bitmap =
            frameBufferStore.copyToBitmap(sourceFrameBufferId)
                ?: return ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                    endpointId = endpointId,
                    reason = "native_transition_surface_upload_source_frame_buffer_missing",
                )
        val endpoint =
            endpointFor(
                endpointId = endpointId,
                width = width,
                height = height,
                allowAllocate = allowAllocate,
            )
                ?: run {
                    bitmap.recycle()
                    return ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                        endpointId = endpointId,
                        reason =
                            if (allowAllocate) {
                                "native_transition_surface_endpoint_allocation_failed"
                            } else {
                                "native_transition_interactive_surface_not_registered"
                            },
                    )
                }
        val checksum = frameBufferStore.checksum(sourceFrameBufferId)
        return try {
            val canvas = endpoint.surface.lockCanvas(null)
            try {
                canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
                canvas.drawBitmap(
                    bitmap,
                    0f,
                    0f,
                    Paint(Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG),
                )
            } finally {
                endpoint.surface.unlockCanvasAndPost(canvas)
            }
            val presentation = drainEndpoint(endpoint, bitmap.byteCount, checksum)
            ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult(
                endpointId = endpoint.id,
                endpointAttached = endpoint.surface.isValid,
                uploaded = endpoint.surface.isValid,
                byteCount = bitmap.byteCount,
                checksum = checksum,
                presented = endpoint.surface.isValid && presentation.presented,
                presentedImageCount = presentation.imageCount,
                presentedByteCount = presentation.byteCount,
                presentedChecksum = presentation.checksum,
                presentationReason = presentation.reason,
                reason = null,
            )
        } catch (_: Throwable) {
            ProfessionalVideoTransitionNativeSurfaceEndpointUploadResult.invalid(
                endpointId = endpointId,
                reason = "native_transition_surface_upload_failed",
            )
        } finally {
            bitmap.recycle()
        }
    }

    private fun endpointFor(
        endpointId: String,
        width: Int,
        height: Int,
        allowAllocate: Boolean,
    ): ProfessionalVideoTransitionNativeSurfaceEndpoint? {
        val existing = endpoints[endpointId]
        if (existing != null && existing.width == width && existing.height == height) {
            return existing
        }
        if (!allowAllocate) {
            return null
        }
        existing?.close()
        return runCatching {
            val imageReader =
                ImageReader.newInstance(
                    width,
                    height,
                    PixelFormat.RGBA_8888,
                    2,
                )
            ProfessionalVideoTransitionNativeSurfaceEndpoint(
                id = endpointId,
                width = width,
                height = height,
                imageReader = imageReader,
                surface = imageReader.surface,
                ownsSurface = true,
                kind = "offscreenNativeProofSurface",
            )
        }.onSuccess { endpoint ->
            endpoints[endpointId] = endpoint
        }.getOrNull()
    }

    private fun drainEndpoint(
        endpoint: ProfessionalVideoTransitionNativeSurfaceEndpoint,
        postedByteCount: Int,
        postedChecksum: Long,
    ): ProfessionalVideoTransitionNativeSurfaceEndpointPresentationResult {
        if (endpoint.kind == "interactiveNativeTransitionSurface") {
            val presented = endpoint.surface.isValid
            return ProfessionalVideoTransitionNativeSurfaceEndpointPresentationResult(
                presented = presented,
                imageCount = if (presented) 1 else 0,
                byteCount = if (presented) postedByteCount else 0,
                checksum = if (presented) postedChecksum else 0L,
                reason =
                    if (presented) {
                        null
                    } else {
                        "native_transition_surface_presentation_missing"
                    },
            )
        }
        var imageCount = 0
        var byteCount = 0
        var checksum = 1469598103934665603L
        while (true) {
            val image =
                runCatching { endpoint.imageReader?.acquireLatestImage() }.getOrNull()
                ?: break
            try {
                imageCount += 1
                image.planes.forEach { plane ->
                    val buffer = plane.buffer.duplicate()
                    while (buffer.hasRemaining()) {
                        checksum = (checksum xor (buffer.get().toLong() and 0xffL)) * 1099511628211L
                        byteCount += 1
                    }
                }
            } finally {
                image.close()
            }
        }
        return ProfessionalVideoTransitionNativeSurfaceEndpointPresentationResult(
            presented = imageCount > 0 && byteCount > 0,
            imageCount = imageCount,
            byteCount = byteCount,
            checksum = if (byteCount > 0) checksum else 0L,
            reason = if (imageCount > 0 && byteCount > 0) {
                null
            } else {
                "native_transition_surface_presentation_missing"
            },
        )
    }
}

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

    @Synchronized
    fun copyToBitmap(frameBufferId: String): Bitmap? {
        val allocation = buffers[frameBufferId] ?: return null
        return try {
            val bitmap =
                Bitmap.createBitmap(
                    allocation.width,
                    allocation.height,
                    Bitmap.Config.ARGB_8888,
                )
            val duplicate = allocation.buffer.duplicate()
            duplicate.position(0)
            duplicate.limit(allocation.byteCount.coerceAtMost(duplicate.capacity()))
            bitmap.copyPixelsFromBuffer(duplicate)
            allocation.buffer.rewind()
            bitmap
        } catch (_: Throwable) {
            null
        }
    }

    @Synchronized
    fun checksum(frameBufferId: String): Long {
        val allocation = buffers[frameBufferId] ?: return 0L
        return checksumFrameBuffer(allocation.buffer, allocation.byteCount)
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
                        implemented = true,
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "fadeBlack",
                        requiredCapabilities = setOf("dualVideoSampling", "previewParity", "playbackParity"),
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "manualTransform",
                        requiredCapabilities =
                            setOf(
                                "dualVideoSampling",
                                "temporalMotionBlur",
                                "mirrorEdgeTiling",
                                "previewParity",
                            ),
                        implemented = true,
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "manualTransformMotionBlur",
                        requiredCapabilities =
                            setOf(
                                "dualVideoSampling",
                                "temporalMotionBlur",
                                "mirrorEdgeTiling",
                                "previewParity",
                                "liveScrubParity",
                                "playbackParity",
                            ),
                        implemented = true,
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
                            ),
                    ),
                    ProfessionalVideoTransitionRendererDefinition(
                        definitionId = "distortionZoomInV1",
                        requiredCapabilities =
                            setOf(
                                "dualVideoSampling",
                                "temporalMotionBlur",
                                "mirrorEdgeTiling",
                                "previewParity",
                                "liveScrubParity",
                                "playbackParity",
                            ),
                        implemented = true,
                    ),
                ).associateBy { definition -> definition.definitionId }
            return ProfessionalVideoTransitionRendererRegistry(
                definitions = definitions,
                availableCapabilities =
                    setOf(
                        "dualVideoSampling",
                        "temporalMotionBlur",
                        "mirrorEdgeTiling",
                        "previewParity",
                        "liveScrubParity",
                        "playbackParity",
                    ),
            )
        }
    }
}
