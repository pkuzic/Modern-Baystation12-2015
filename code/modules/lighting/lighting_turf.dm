/turf
	var/list/affecting_lights
	var/atom/movable/lighting_overlay/lighting_overlay

/turf/proc/reconsider_lights()
	for(var/datum/light_source/L in affecting_lights)
		L.vis_update()

/turf/proc/lighting_clear_overlays()
	if(lighting_overlay)
		qdel(lighting_overlay)

/turf/proc/lighting_build_overlays()
	if(!lighting_overlay)
		var/area/A = loc
		if(A.lighting_use_dynamic)
			var/atom/movable/lighting_overlay/O = PoolOrNew(/atom/movable/lighting_overlay, src)
			lighting_overlay = O
