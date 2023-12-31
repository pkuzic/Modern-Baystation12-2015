/area/turret_protected
	name = "Turret Protected Area"
	var/list/turretTargets = list()

/area/turret_protected/proc/subjectDied(target)
	if( isliving(target) )
		if( !issilicon(target) )
			var/mob/living/L = target
			if( L.stat )
				if( L in turretTargets )
					src.Exited(L)


/area/turret_protected/Entered(O)
	..()
	if( iscarbon(O) )
		turretTargets |= O
	else if( istype(O, /obj/mecha) )
		var/obj/mecha/Mech = O
		if( Mech.occupant )
			turretTargets |= Mech
	else if(istype(O,/mob/living/simple_animal))
		turretTargets |= O
	return 1

/area/turret_protected/Exited(O)
	if( ismob(O) && !issilicon(O) )
		turretTargets -= O
	else if( istype(O, /obj/mecha) )
		turretTargets -= O
	..()
	return 1


/obj/machinery/turret
	name = "turret"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "grey_target_prism"
	var/raised = 0
	var/enabled = 1
	anchored = 1
	layer = 3
	invisibility = INVISIBILITY_LEVEL_TWO
	density = 1
	var/lasers = 0
	var/lasertype = 1
		// 1 = lasers
		// 2 = cannons
		// 3 = pulse
		// 4 = change (HONK)
		// 5 = bluetag
		// 6 = redtag
	var/health = 80
	var/maxhealth = 80
	var/auto_repair = 0
	var/obj/machinery/turretcover/cover = null
	var/popping = 0
	var/wasvalid = 0
	var/lastfired = 0
	var/shot_delay = 30 //3 seconds between shots
	var/datum/effect/effect/system/spark_spread/spark_system
	use_power = 1
	idle_power_usage = 50
	active_power_usage = 300
//	var/list/targets
	var/atom/movable/cur_target
	var/targeting_active = 0
	var/area/turret_protected/protected_area

/obj/machinery/turret/proc/take_damage(damage)
	src.health -= damage
	if(src.health<=0)
		qdel(src)
	return

/obj/machinery/turret/attack_hand(var/mob/living/carbon/human/user)

	if(!istype(user))
		return ..()

	if(user.species.can_shred(user) && !(stat & BROKEN))
		playsound(src.loc, 'sound/weapons/slash.ogg', 25, 1, -1)
		visible_message("\red <B>[user] has slashed at [src]!</B>")
		src.take_damage(15)
	return

/obj/machinery/turret/bullet_act(var/obj/item/projectile/Proj)
	if(!(Proj.damage_type == BRUTE || Proj.damage_type == BURN))
		return
	take_damage(Proj.damage)
	..()
	return

/obj/machinery/turret/New()
	maxhealth = health
	spark_system = new /datum/effect/effect/system/spark_spread
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)
//	targets = new
	..()
	return

/obj/machinery/turret/proc/update_health()
	if(src.health<=0)
		qdel(src)
	return

/obj/machinery/turretcover
	name = "pop-up turret cover"
	icon = 'icons/obj/turrets.dmi'
	icon_state = "turretCover"
	anchored = 1
	layer = 3.5
	density = 0
	var/obj/machinery/turret/host = null

/obj/machinery/turret/proc/isPopping()
	return (popping!=0)

/obj/machinery/turret/power_change()
	..()
	if(stat & BROKEN)
		icon_state = "grey_target_prism"
	else
		if( !(stat & NOPOWER) )
			if (src.enabled)
				if (src.lasers)
					icon_state = "orange_target_prism"
				else
					icon_state = "target_prism"
			else
				icon_state = "grey_target_prism"
			stat &= ~NOPOWER
		else
			spawn(rand(0, 15))
				src.icon_state = "grey_target_prism"
				stat |= NOPOWER

/obj/machinery/turret/proc/setState(var/enabled, var/lethal)
	src.enabled = enabled
	src.lasers = lethal
	src.power_change()


/obj/machinery/turret/proc/get_protected_area()
	var/area/turret_protected/TP = get_area(src)
	if(istype(TP))
		return TP
	return

/obj/machinery/turret/proc/check_target(var/atom/movable/T as mob|obj)
	if( T && T in protected_area.turretTargets )
		var/area/area_T = get_area(T)
		if( !area_T || (area_T.type != protected_area.type) )
			protected_area.Exited(T)
			return 0 //If the guy is somehow not in the turret's area (teleportation), get them out the damn list. --NEO
		if( iscarbon(T) )
			var/mob/living/carbon/MC = T
			if( !MC.stat )
				if( !MC.lying || lasers )
					return 1
		else if( istype(T, /obj/mecha) )
			var/obj/mecha/ME = T
			if( ME.occupant )
				return 1
		else if(istype(T,/mob/living/simple_animal))
			var/mob/living/simple_animal/A = T
			if( !A.stat )
				if(lasers)
					return 1
	return 0

/obj/machinery/turret/proc/get_new_target()
	var/list/new_targets = new
	var/new_target
	for(var/mob/living/carbon/M in protected_area.turretTargets)
		if(!M.stat)
			if(!M.lying || lasers)
				new_targets += M
	for(var/obj/mecha/M in protected_area.turretTargets)
		if(M.occupant)
			new_targets += M
	for(var/mob/living/simple_animal/M in protected_area.turretTargets)
		if(!M.stat)
			new_targets += M
	if(new_targets.len)
		new_target = pick(new_targets)
	return new_target


/obj/machinery/turret/process()
	if(stat & (NOPOWER|BROKEN))
		return
	if(src.cover==null)
		src.cover = new /obj/machinery/turretcover(src.loc)
		src.cover.host = src
	protected_area = get_protected_area()
	if(!enabled || !protected_area || protected_area.turretTargets.len<=0)
		if(!isDown() && !isPopping())
			popDown()
		return
	if(!check_target(cur_target)) //if current target fails target check
		cur_target = get_new_target() //get new target

	if(cur_target) //if it's found, proceed
//		world << "[cur_target]"
		if(!isPopping())
			if(isDown())
				popUp()
				use_power = 2
			else
				spawn()
					if(!targeting_active)
						targeting_active = 1
						target()
						targeting_active = 0

		if(prob(15))
			if(prob(50))
				playsound(src.loc, 'sound/effects/turret/move1.wav', 60, 1)
			else
				playsound(src.loc, 'sound/effects/turret/move2.wav', 60, 1)
	else if(!isPopping())//else, pop down
		if(!isDown())
			popDown()
			use_power = 1

	// Auto repair requires massive amount of power, but slowly regenerates the turret's health.
	// Currently only used by malfunction hardware, but may be used as admin-settable option too.
	if(auto_repair)
		if(health < maxhealth)
			use_power(20000)
			health = min(health + 1, maxhealth)
	return


/obj/machinery/turret/proc/target()
	while(src && enabled && !stat && check_target(cur_target))
		src.set_dir(get_dir(src, cur_target))
		shootAt(cur_target)
		sleep(shot_delay)
	return

/obj/machinery/turret/proc/shootAt(var/atom/movable/target)
	var/turf/T = get_turf(src)
	var/turf/U = get_turf(target)
	if (!T || !U)
		return
	var/obj/item/projectile/A
	if (src.lasers)
		switch(lasertype)
			if(1)
				A = new /obj/item/projectile/beam( loc )
			if(2)
				A = new /obj/item/projectile/beam/heavylaser( loc )
			if(3)
				A = new /obj/item/projectile/beam/pulse( loc )
			if(4)
				A = new /obj/item/projectile/change( loc )
			if(5)
				A = new /obj/item/projectile/beam/lastertag/blue( loc )
			if(6)
				A = new /obj/item/projectile/beam/lastertag/red( loc )
		A.original = target
		use_power(500)
	else
		A = new /obj/item/projectile/energy/electrode( loc )
		use_power(200)
	A.current = T
	A.starting = T
	A.yo = U.y - T.y
	A.xo = U.x - T.x
	spawn( 0 )
		A.process()
	return


/obj/machinery/turret/proc/isDown()
	return (invisibility!=0)

/obj/machinery/turret/proc/popUp()
	if ((!isPopping()) || src.popping==-1)
		invisibility = 0
		popping = 1
		playsound(src.loc, 'sound/effects/turret/open.wav', 60, 1)
		if (src.cover!=null)
			flick("popup", src.cover)
			src.cover.icon_state = "openTurretCover"
		spawn(10)
			if (popping==1) popping = 0

/obj/machinery/turret/proc/popDown()
	if ((!isPopping()) || src.popping==1)
		popping = -1
		playsound(src.loc, 'sound/effects/turret/open.wav', 60, 1)
		if (src.cover!=null)
			flick("popdown", src.cover)
			src.cover.icon_state = "turretCover"
		spawn(10)
			if (popping==-1)
				invisibility = INVISIBILITY_LEVEL_TWO
				popping = 0

/obj/machinery/turret/bullet_act(var/obj/item/projectile/Proj)
	if(!(Proj.damage_type == BRUTE || Proj.damage_type == BURN))
		return
	src.health -= Proj.damage
	..()
	if(prob(45) && Proj.damage > 0) src.spark_system.start()
	qdel (Proj)
	if (src.health <= 0)
		src.die()
	return

/obj/machinery/turret/attackby(obj/item/weapon/W, mob/user)//I can't believe no one added this before/N
	..()
	playsound(src.loc, 'sound/weapons/smash.ogg', 60, 1)
	src.spark_system.start()
	src.health -= W.force * 0.5
	if (src.health <= 0)
		src.die()
	return

/obj/machinery/turret/emp_act(severity)
	switch(severity)
		if(1)
			enabled = 0
			lasers = 0
			power_change()
	..()

/obj/machinery/turret/ex_act(severity)
	if(severity < 3)
		src.die()

/obj/machinery/turret/proc/die()
	src.health = 0
	src.density = 0
	src.stat |= BROKEN
	src.icon_state = "destroyed_target_prism"
	if (cover!=null)
		qdel(cover)
	sleep(3)
	flick("explosion", src)
	spawn(13)
		qdel(src)

/obj/machinery/turret/attack_generic(var/mob/user, var/damage, var/attack_message)
	if(!damage)
		return 0
	if(stat & BROKEN)
		user << "That object is useless to you."
		return 0
	user.do_attack_animation(src)
	visible_message("<span class='danger'>[user] [attack_message] the [src]!</span>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>attacked [src.name]</font>")
	src.health -= damage
	if (src.health <= 0)
		src.die()
	return 1

/obj/structure/turret/gun_turret
	name = "Gun Turret"
	density = 1
	anchored = 1
	var/cooldown = 20
	var/projectiles = 100
	var/projectiles_per_shot = 2
	var/deviation = 0.3
	var/list/exclude = list()
	var/atom/cur_target
	var/scan_range = 7
	var/health = 40
	var/list/scan_for = list("human"=0,"cyborg"=0,"mecha"=0,"alien"=1)
	var/on = 0
	icon = 'icons/obj/turrets.dmi'
	icon_state = "gun_turret"

	proc/take_damage(damage)
		src.health -= damage
		if(src.health<=0)
			qdel(src)
		return


	bullet_act(var/obj/item/projectile/Proj)
		if(Proj.damage_type == HALLOSS)
			return
		take_damage(Proj.damage)
		..()
		return


	ex_act()
		qdel(src)
		return

	emp_act()
		qdel(src)
		return

	meteorhit()
		qdel(src)
		return

	attack_hand(mob/user as mob)
		user.set_machine(src)
		var/dat = {"<html>
						<head><title>[src] Control</title></head>
						<body>
						<b>Power: </b><a href='?src=\ref[src];power=1'>[on?"on":"off"]</a><br>
						<b>Scan Range: </b><a href='?src=\ref[src];scan_range=-1'>-</a> [scan_range] <a href='?src=\ref[src];scan_range=1'>+</a><br>
						<b>Scan for: </b>"}
		for(var/scan in scan_for)
			dat += "<div style=\"margin-left: 15px;\">[scan] (<a href='?src=\ref[src];scan_for=[scan]'>[scan_for[scan]?"Yes":"No"]</a>)</div>"

		dat += {"<b>Ammo: </b>[max(0, projectiles)]<br>
					</body>
					</html>"}
		user << browse(dat, "window=turret")
		onclose(user, "turret")
		return

	attack_ai(mob/user as mob)
		return attack_hand(user)

	Topic(href, href_list)
		if(href_list["power"])
			src.on = !src.on
			if(src.on)
				spawn(50)
					if(src)
						src.process()
		if(href_list["scan_range"])
			src.scan_range = between(1,src.scan_range+text2num(href_list["scan_range"]),8)
		if(href_list["scan_for"])
			if(href_list["scan_for"] in scan_for)
				scan_for[href_list["scan_for"]] = !scan_for[href_list["scan_for"]]
		src.updateUsrDialog()
		return


	proc/validate_target(atom/target)
		if(get_dist(target, src)>scan_range)
			return 0
		if(istype(target, /mob))
			var/mob/M = target
			if(!M.stat && !M.lying)//ninjas can't catch you if you're lying
				return 1
		else if(istype(target, /obj/mecha))
			return 1
		return 0


	process()
		spawn while(on)
			if(projectiles<=0)
				on = 0
				return
			if(cur_target && !validate_target(cur_target))
				cur_target = null
			if(!cur_target)
				cur_target = get_target()
			fire(cur_target)
			sleep(cooldown)
		return

	proc/get_target()
		var/list/pos_targets = list()
		var/target = null
		if(scan_for["human"])
			for(var/mob/living/carbon/human/M in oview(scan_range,src))
				if(M.stat || M.lying || M in exclude)
					continue
				pos_targets += M
		if(scan_for["cyborg"])
			for(var/mob/living/silicon/M in oview(scan_range,src))
				if(M.stat || M.lying || M in exclude)
					continue
				pos_targets += M
		if(scan_for["mecha"])
			for(var/obj/mecha/M in oview(scan_range, src))
				if(M in exclude)
					continue
				pos_targets += M
		if(scan_for["alien"])
			for(var/mob/living/carbon/alien/M in oview(scan_range,src))
				if(M.stat || M.lying || M in exclude)
					continue
				pos_targets += M
		if(pos_targets.len)
			target = pick(pos_targets)
		return target


	proc/fire(atom/target)
		if(!target)
			cur_target = null
			return
		src.set_dir(get_dir(src,target))
		var/turf/targloc = get_turf(target)
		var/target_x = targloc.x
		var/target_y = targloc.y
		var/target_z = targloc.z
		targloc = null
		spawn	for(var/i=1 to min(projectiles, projectiles_per_shot))
			if(!src) break
			var/turf/curloc = get_turf(src)
			targloc = locate(target_x+GaussRandRound(deviation,1),target_y+GaussRandRound(deviation,1),target_z)
			if (!targloc || !curloc)
				continue
			if (targloc == curloc)
				continue
			playsound(src, 'sound/weapons/Gunshot.ogg', 50, 1)
			var/obj/item/projectile/A = new /obj/item/projectile(curloc)
			src.projectiles--
			A.current = curloc
			A.yo = targloc.y - curloc.y
			A.xo = targloc.x - curloc.x
			A.process()
			sleep(2)
		return
