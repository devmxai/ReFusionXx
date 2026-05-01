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
        val registryResult =
            rendererRegistry.prepare(
                definitionId = definitionId,
                requestedCapabilities = requestedCapabilities,
            )
        if (registryResult != null) {
            return registryResult
        }
        return mapOf(
            "status" to "unsupported",
            "reason" to "native_video_transition_renderer_not_implemented",
            "rendererVersion" to "foundation",
            "definitionId" to definitionId,
            "missingCapabilities" to requestedCapabilities,
        )
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
