/obj/item/weapon/reagent_containers/borghypo
	name = "Cyborg Hypospray"
	desc = "An advanced chemical synthesizer and injection system, designed for heavy-duty medical equipment."
	icon = 'icons/obj/syringe.dmi'
	item_state = "hypo"
	icon_state = "borghypo"
	amount_per_transfer_from_this = 5
	volume = 30
	possible_transfer_amounts = null
	var/mode = 1
	var/charge_cost = 50
	var/charge_tick = 0
	var/recharge_time = 5 //Time it takes for shots to recharge (in seconds)

	var/list/datum/reagents/reagent_list = list()
	var/list/reagent_ids = list("tricordrazine", "inaprovaline", "spaceacillin")

/obj/item/weapon/reagent_containers/borghypo/surgeon
	reagent_ids = list("bicaridine", "inaprovaline", "dexalin")

/obj/item/weapon/reagent_containers/borghypo/crisis
	reagent_ids = list("tricordrazine", "inaprovaline", "tramadol")

/obj/item/weapon/reagent_containers/borghypo/New()
	..()
	for(var/R in reagent_ids)
		add_reagent(R)

	processing_objects.Add(src)


/obj/item/weapon/reagent_containers/borghypo/Destroy()
	processing_objects.Remove(src)
	..()

/obj/item/weapon/reagent_containers/borghypo/process() //Every [recharge_time] seconds, recharge some reagents for the cyborg
	charge_tick++
	if(charge_tick < recharge_time) return 0
	charge_tick = 0

	if(isrobot(loc))
		var/mob/living/silicon/robot/R = loc
		if(R && R.cell)
			var/datum/reagents/RG = reagent_list[mode]
			if(RG.total_volume < RG.maximum_volume) 	//Don't recharge reagents and drain power if the storage is full.
				R.cell.use(charge_cost) 					//Take power from borg...
				RG.add_reagent(reagent_ids[mode], 5)		//And fill hypo with reagent.
	return 1

// Use this to add more chemicals for the borghypo to produce.
/obj/item/weapon/reagent_containers/borghypo/proc/add_reagent(var/reagent)
	reagent_ids |= reagent
	var/datum/reagents/RG = new(30)
	RG.my_atom = src
	reagent_list += RG

	var/datum/reagents/R = reagent_list[reagent_list.len]
	R.add_reagent(reagent, 30)

/obj/item/weapon/reagent_containers/borghypo/attack(mob/living/M as mob, mob/user as mob)
	var/datum/reagents/R = reagent_list[mode]
	if(!R.total_volume)
		user << "<span class='warning'>The injector is empty.</span>"
		return
	if (!istype(M))
		return

	if (R.total_volume && M.can_inject(user, 1))
		user << "<span class='notice'>You inject [M] with the injector.</span>"
		M << "<span class='notice'>You feel a tiny prick!</span>"

		if(M.reagents)
			var/trans = R.trans_to_mob(M, amount_per_transfer_from_this, CHEM_BLOOD)
			user << "<span class='notice'>[trans] units injected. [R.total_volume] units remaining.</span>"
	return

/obj/item/weapon/reagent_containers/borghypo/attack_self(mob/user as mob)
	playsound(src.loc, 'sound/effects/pop.ogg', 50, 0)		//Change the mode
	mode++
	if(mode > reagent_list.len)
		mode = 1

	charge_tick = 0 //Prevents wasted chems/cell charge if you're cycling through modes.
	var/datum/reagent/R = chemical_reagents_list[reagent_ids[mode]]
	user << "<span class='notice'>Synthesizer is now producing '[R.name]'.</span>"
	return

/obj/item/weapon/reagent_containers/borghypo/examine(mob/user)
	if(!..(user, 2))
		return

	var/empty = 1

	for(var/datum/reagents/RS in reagent_list)
		var/datum/reagent/R = locate() in RS.reagent_list
		if(R)
			user << "<span class='notice'>It currently has [R.volume] units of [R.name] stored.</span>"
			empty = 0

	if(empty)
		user << "<span class='notice'>It is currently empty. Allow some time for the internal syntheszier to produce more.</span>"
