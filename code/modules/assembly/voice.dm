/obj/item/device/assembly/voice
	name = "voice analyzer"
	desc = "A small electronic device able to record a voice sample, and send a signal when that sample is repeated."
	icon_state = "voice"
	matter = list(DEFAULT_WALL_MATERIAL = 500, "glass" = 50, "waste" = 10)
	origin_tech = "magnets=1"
	var/listening = 0
	var/recorded	//the activation message

/obj/item/device/assembly/voice/hear_talk(mob/living/M as mob, msg)
	if(listening)
		recorded = msg
		listening = 0
		var/turf/T = get_turf(src)	//otherwise it won't work in hand
		T.visible_message("\icon[src] beeps, \"Activation message is '[recorded]'.\"")
	else
		if(findtext(msg, recorded))
			pulse(0)

/obj/item/device/assembly/voice/activate()
	if(secured)
		if(!holder)
			listening = !listening
			var/turf/T = get_turf(src)
			T.visible_message("\icon[src] beeps, \"[listening ? "Now" : "No longer"] recording input.\"")


/obj/item/device/assembly/voice/attack_self(mob/user)
	if(!user)
		return 0
	activate()
	return 1


/obj/item/device/assembly/voice/toggle_secure()
	. = ..()
	listening = 0