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
