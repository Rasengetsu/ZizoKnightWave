// Fae Mushroom Circle
//
// GROWTH CHAIN:
//   /obj/item/seeds/mushroom_fae  →  planted in blessed soil, watered once
//   /obj/structure/mushroom_sprout (5 min)
//   /obj/structure/mushroom_circle (active portal, tinymushrooms sprite)
//      ↓ 20 min without scissors maintenance
//   mushroomcluster sprite (unusable)
//      ↓ 10 more min
//   /obj/structure/flora/rogueshroom  (random mush1-5, final dead state)
//
// Teleportation:
//   Hold Dendor amulet → click circle → choose destination → 3 sec cast
//   Drags your pulled target with you if one is grabbed.
//
// Renaming:
//   Click with /obj/item/natural/feather (UNIQUE_RENAME flag).

GLOBAL_LIST_EMPTY(mushroom_circles)

//==============================================================================
// Mushroom Fae Sprout
//==============================================================================

/obj/structure/mushroom_sprout
	name = "fae mushroom sprout"
	desc = "A colony of tiny pale shoots, faintly alive with fae energy. Water it and it should bloom."
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	max_integrity = 5
	resistance_flags = FLAMMABLE
	icon = 'icons/obj/hydroponics/seeds.dmi'
	icon_state = "seed"
	color = "#FFFFFF"
	layer = OBJ_LAYER

	var/watered = FALSE
	var/timerid = null

/obj/structure/mushroom_sprout/Destroy()
	if(timerid)
		deltimer(timerid)
	return ..()

/obj/structure/mushroom_sprout/examine(mob/user)
	. = ..()
	if(watered)
		. += span_info("Already watered — it should bloom soon.")
	else
		. += span_info("It needs watering to begin growing.")

/obj/structure/mushroom_sprout/attackby(obj/item/I, mob/living/user, params)
	if(!watered && istype(I, /obj/item/reagent_containers))
		var/obj/item/reagent_containers/RC = I
		var/water_amt = RC.reagents.get_reagent_amount(/datum/reagent/water)
		var/holy_amt  = RC.reagents.get_reagent_amount(/datum/reagent/water/holywater)
		if(water_amt + holy_amt <= 0)
			to_chat(user, span_warning("[RC] doesn't have any water in it."))
			return
		if(water_amt > 0)
			RC.reagents.remove_reagent(/datum/reagent/water, min(1, water_amt))
		else
			RC.reagents.remove_reagent(/datum/reagent/water/holywater, min(1, holy_amt))
		watered = TRUE
		to_chat(user, span_notice("I water the sprout. It hums quietly with wild energy."))
		timerid = addtimer(CALLBACK(src, PROC_REF(bloom)), 5 MINUTES, flags = TIMER_STOPPABLE)
		return
	if(watered && istype(I, /obj/item/reagent_containers))
		to_chat(user, span_info("Already watered; it just needs time."))
		return
	if(istype(I, /obj/item/rogueweapon/shovel))
		to_chat(user, span_notice("I begin uprooting [src]..."))
		if(do_after(user, 2 SECONDS, target = src))
			qdel(src)
		return
	return ..()

/obj/structure/mushroom_sprout/proc/bloom()
	if(QDELETED(src))
		return
	new /obj/structure/mushroom_circle(get_turf(src))
	qdel(src)

//==============================================================================
// Fae Mushroom Circle
//==============================================================================

/obj/structure/mushroom_circle
	name = "fae mushroom circle"
	desc = "A magical ring of pale and purple mushrooms that pulse with faint light. Druids of Dendor use these as waypoints to travel across long distances instantly."
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	obj_flags = CAN_BE_HIT | UNIQUE_RENAME
	max_integrity = 50
	resistance_flags = FLAMMABLE
	icon = 'icons/roguetown/misc/foliage.dmi'
	icon_state = "tinymushrooms"
	layer = OBJ_LAYER

	/// Seconds since last scissors maintenance
	var/maintenance_elapsed = 0
	/// TRUE while usable as a portal; set to FALSE when decaying
	var/active = TRUE

/obj/structure/mushroom_circle/Initialize(mapload)
	. = ..()
	GLOB.mushroom_circles |= src
	set_light(3, 3, 3, l_color = "#5D3FD3")
	START_PROCESSING(SSprocessing, src)

/obj/structure/mushroom_circle/Destroy()
	GLOB.mushroom_circles -= src
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/obj/structure/mushroom_circle/process(dt)
	if(!active)
		return
	maintenance_elapsed += dt
	if(maintenance_elapsed >= 20 MINUTES)
		begin_decay()

/obj/structure/mushroom_circle/proc/begin_decay()
	active = FALSE
	GLOB.mushroom_circles -= src
	set_light(0)
	icon = 'icons/roguetown/misc/foliage.dmi'
	icon_state = "mushroomcluster"
	desc = "A withered ring of mushrooms that has lost its fae connection."
	visible_message(span_warning("[src] begins to wither — the mystical light flickers and dies."))
	addtimer(CALLBACK(src, PROC_REF(final_decay)), 10 MINUTES)

/obj/structure/mushroom_circle/proc/final_decay()
	if(QDELETED(src))
		return
	new /obj/structure/flora/rogueshroom(get_turf(src))
	qdel(src)

/obj/structure/mushroom_circle/examine(mob/user)
	. = ..()
	if(!active)
		. += span_warning("The circle has lost its power. Its fae connection is severed — it won't last much longer.")
		return
	if(maintenance_elapsed > (15 MINUTES))
		. += span_warning("The mushrooms look unhealthy. They need tending with scissors soon or the circle will fade and become overgrown.")
	else
		. += span_info("The mushrooms glow steadily with fae power.")
	if(user.patron?.type == /datum/patron/divine/dendor)
		. += span_notice("Hold my amulet of Dendor and press it on this circle to travel to another fae circle.")

/obj/structure/mushroom_circle/attackby(obj/item/I, mob/living/user, params)
	// Scissors maintenance — anyone can do it
	if(istype(I, /obj/item/rogueweapon/huntingknife/scissors))
		if(!active)
			to_chat(user, span_warning("The circle has already faded — scissors can't restore it now."))
			return
		to_chat(user, span_notice("I carefully tend to [src]..."))
		if(do_after(user, 3 SECONDS, target = src))
			if(!active)
				return
			maintenance_elapsed = 0
			to_chat(user, span_notice("[src] looks well-maintained. The mystical glow brightens."))
		return

	// Dendor amulet — opens teleport menu
	if(istype(I, /obj/item/clothing/neck/roguetown/psicross/dendor))
		if(user.patron?.type != /datum/patron/divine/dendor)
			to_chat(user, span_warning("Only a follower of Dendor may commune with this circle."))
			return
		if(!active)
			to_chat(user, span_warning("This circle has waned in power — it can no longer carry you anywhere."))
			return
		open_teleport_menu(user)
		return

	return ..()

/obj/structure/mushroom_circle/proc/open_teleport_menu(mob/living/user)
	var/list/choices = list()
	for(var/obj/structure/mushroom_circle/C in GLOB.mushroom_circles)
		if(C == src || !C.active)
			continue
		choices[C.name] = C

	if(!choices.len)
		to_chat(user, span_warning("There are no other active mushroom circles within the network."))
		return

	var/choice = input(user, "Which circle do you wish to travel to?", "Fae Mushroom Circle Network") as null|anything in choices
	if(isnull(choice) || QDELETED(src) || QDELETED(user))
		return

	var/obj/structure/mushroom_circle/dest = choices[choice]
	if(QDELETED(dest) || !dest.active)
		to_chat(user, span_warning("That circle has faded since you made your choice."))
		return

	to_chat(user, span_notice("I focus on [dest.name]..."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	if(QDELETED(dest) || !dest.active)
		to_chat(user, span_warning("The destination circle faded mid-journey."))
		return

	var/turf/dest_turf = get_turf(dest)
	var/mob/living/pulled = null
	if(user.pulling && isliving(user.pulling))
		pulled = user.pulling

	playsound(get_turf(src), 'sound/misc/portalactivate.ogg', 50, FALSE)
	user.forceMove(dest_turf)
	playsound(dest_turf, 'sound/misc/portalopen.ogg', 50, FALSE)
	if(pulled && !QDELETED(pulled))
		pulled.forceMove(dest_turf)

	to_chat(user, span_notice("I step into the ring, planting my feet firmly and emerge at [dest.name]."))
