// Glass shards

/obj/item/weapon/material/shard
	name = "shard"
	icon = 'icons/obj/shards.dmi'
	desc = "Made of nothing. How does this even exist?" // set based on material, if this desc is visible it's a bug (shards default to being made of glass)
	icon_state = "large"
	sharp = 1
	edge = 1
	w_class = 2
	force_divisor = 0.2 // 6 with hardness 30 (glass)
	thrown_force_divisor = 0.4 // 4 with weight 15 (glass)
	item_state = "shard-glass"
	attack_verb = list("stabbed", "slashed", "sliced", "cut")
	default_material = "glass"
	unbreakable = 1 //It's already broken.
	drops_debris = 0

/obj/item/weapon/material/shard/suicide_act(mob/user)
	viewers(user) << pick("\red <b>[user] is slitting \his wrists with \the [src]! It looks like \he's trying to commit suicide.</b>", \
						"\red <b>[user] is slitting \his throat with \the [src]! It looks like \he's trying to commit suicide.</b>")
	return (BRUTELOSS)

/obj/item/weapon/material/shard/set_material(var/new_material)
	..(new_material)
	if(!istype(material))
		return

	icon_state = "[material.shard_icon][pick("large", "medium", "small")]"
	pixel_x = rand(-8, 8)
	pixel_y = rand(-8, 8)
	update_icon()

	if(material.shard_type)
		name = "[material.display_name] [material.shard_type]"
		desc = "A small piece of [material.display_name]. It looks sharp, you wouldn't want to step on it barefoot. Could probably be used as ... a throwing weapon?"
		switch(material.shard_type)
			if(SHARD_SPLINTER, SHARD_SHRAPNEL)
				gender = PLURAL
			else
				gender = NEUTER
	else
		qdel(src)

/obj/item/weapon/material/shard/update_icon()
	if(material)
		color = material.icon_colour
		// 1-(1-x)^2, so that glass shards with 0.3 opacity end up somewhat visible at 0.51 opacity
		alpha = 255 * (1 - (1 - material.opacity)*(1 - material.opacity))
	else
		color = "#ffffff"
		alpha = 255

/obj/item/weapon/material/shard/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/weldingtool) && material.shard_can_repair)
		var/obj/item/weapon/weldingtool/WT = W
		if(WT.remove_fuel(0, user))
			material.place_sheet(loc)
			qdel(src)
			return
	return ..()

/obj/item/weapon/material/shard/Crossed(AM as mob|obj)
	if(ismob(AM))
		var/mob/M = AM
		M << "\red <B>You step on \the [src]!</B>"
		playsound(src.loc, 'sound/effects/glass_step.ogg', 50, 1) // not sure how to handle metal shards with sounds
		if(ishuman(M))
			var/mob/living/carbon/human/H = M

			if(H.species.flags & IS_SYNTHETIC || (H.species.siemens_coefficient<0.5)) //Thick skin.
				return

			if( !H.shoes && ( !H.wear_suit || !(H.wear_suit.body_parts_covered & FEET) ) )
				var/obj/item/organ/external/affecting = H.get_organ(pick("l_foot", "r_foot"))
				if(affecting.status & ORGAN_ROBOT)
					return
				if(affecting.take_damage(5, 0))
					H.UpdateDamageIcon()
				H.updatehealth()
				if(!(H.species && (H.species.flags & NO_PAIN)))
					H.Weaken(3)
	..()

// Preset types - left here for the code that uses them
/obj/item/weapon/material/shard/shrapnel/New(loc)
	..(loc, "steel")

/obj/item/weapon/material/shard/phoron/New(loc)
	..(loc, "phoron glass")
