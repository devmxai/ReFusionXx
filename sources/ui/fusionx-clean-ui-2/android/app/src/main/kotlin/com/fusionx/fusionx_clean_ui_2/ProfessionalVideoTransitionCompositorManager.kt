package com.refusion.app

class ProfessionalVideoTransitionCompositorManager {
    private val rendererRegistry = ProfessionalVideoTransitionRendererRegistry.foundation()

    fun capabilities(): Map<String, Any> =
        mapOf(
            "dualVideoSampling" to false,
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
    val timelineStartMs: Long,
    val timelineEndMs: Long,
    val sourceStartMs: Long,
    val sourceDurationMs: Long,
) {
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

private fun issue(path: String, message: String): Map<String, Any> =
    mapOf(
        "path" to path,
        "message" to message,
    )

private fun Map<String, Any>.withSessionMetadata(
    session: ProfessionalVideoTransitionRenderSession,
): Map<String, Any> = this + session.metadata()

private data class ProfessionalVideoTransitionRendererDefinition(
    val definitionId: String,
    val requiredCapabilities: Set<String>,
    val implemented: Boolean = false,
)

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
                availableCapabilities = emptySet(),
            )
        }
    }
}
