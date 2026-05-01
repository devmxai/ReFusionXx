package com.refusion.app

class ProfessionalVideoTransitionCompositorManager {
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
        )

    fun prepareZoomInCameraRenderPlan(plan: Map<String, Any?>?): Map<String, Any> {
        val missingFields = requiredZoomPlanFields.filter { field ->
            !hasRequiredField(plan, field)
        }
        if (missingFields.isNotEmpty()) {
            return mapOf(
                "status" to "invalidRequest",
                "reason" to "missing_required_zoom_camera_render_plan_fields",
                "rendererVersion" to "foundation",
                "missingFields" to missingFields,
            )
        }
        return mapOf(
            "status" to "unsupported",
            "reason" to "native_zoom_camera_renderer_not_implemented",
            "rendererVersion" to "foundation",
            "missingCapabilities" to
                listOf(
                    "dualVideoSampling",
                    "temporalMotionBlur",
                    "mirrorEdgeTiling",
                    "previewParity",
                    "liveScrubParity",
                    "playbackParity",
                    "exportParity",
                ),
        )
    }

    private fun hasRequiredField(plan: Map<String, Any?>?, field: String): Boolean {
        if (plan == null) {
            return false
        }
        val value = plan[field]
        return when (field) {
            "outgoing", "incoming" -> value is Map<*, *>
            "transitionId", "kind" -> value is String && value.isNotBlank()
            else -> value is Number
        }
    }

    private companion object {
        val requiredZoomPlanFields =
            listOf(
                "kind",
                "transitionId",
                "canvasWidth",
                "canvasHeight",
                "boundaryTimeMs",
                "leadingDurationMs",
                "trailingDurationMs",
                "outgoing",
                "incoming",
                "outgoingBoostScale",
                "incomingStartScale",
                "shutterAngleDegrees",
                "frameRate",
                "shutterSampleCount",
                "motionTileOutputScaleX",
                "motionTileOutputScaleY",
            )
    }
}
