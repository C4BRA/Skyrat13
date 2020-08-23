/**
  * Kudzu Flower Bud
  *
  * A flower created by flowering kudzu which spawns a venus human trap after a certain amount of time has passed.
  *
  * A flower created by kudzu with the flowering mutation.  Spawns a venus human trap after 2 minutes under normal circumstances.
  * Also spawns 4 vines going out in diagonal directions from the bud.  Any living creature not aligned with plants is damaged by these vines.
  * Once it grows a venus human trap, the bud itself will destroy itself.
  *
  */
/obj/structure/alien/resin/flower_bud_enemy //inheriting basic attack/damage stuff from alien structures
	name = "flower bud"
	desc = "A large pulsating plant..."
	icon = 'icons/effects/spacevines.dmi'
	icon_state = "flower_bud"
	layer = SPACEVINE_MOB_LAYER
	opacity = 0
	canSmoothWith = list()
	smooth = SMOOTH_FALSE
	/// The amount of time it takes to create a venus human trap, in deciseconds
	//var/growth_time = 1200
	var/growth_time = 1 MINUTES //SKYRAT EDIT - VINES

/obj/structure/alien/resin/flower_bud_enemy/Initialize()
	. = ..()
	var/list/anchors = list()
	anchors += locate(x-2,y+2,z)
	anchors += locate(x+2,y+2,z)
	anchors += locate(x-2,y-2,z)
	anchors += locate(x+2,y-2,z)

	for(var/turf/T in anchors)
		var/datum/beam/B = Beam(T, "vine", time=INFINITY, maxdistance=5, beam_type=/obj/effect/ebeam/vine)
		B.sleep_time = 10 //these shouldn't move, so let's slow down updates to 1 second (any slower and the deletion of the vines would be too slow)
	addtimer(CALLBACK(src, .proc/bear_fruit), growth_time)

/**
  * Spawns a venus human trap, then qdels itself.
  *
  * Displays a message, spawns a human venus trap, then qdels itself.
  */
/obj/structure/alien/resin/flower_bud_enemy/proc/bear_fruit()
	visible_message("<span class='danger'>The plant has borne fruit!</span>")
	new /mob/living/simple_animal/hostile/venus_human_trap/ghost_playable(get_turf(src)) // Skyrat change: slight vine buff, rarely happens anyway!
	qdel(src)

/obj/effect/ebeam/vine
	name = "thick vine"
	mouse_opacity = MOUSE_OPACITY_ICON
	desc = "A thick vine, painful to the touch."

/obj/effect/ebeam/vine/Crossed(atom/movable/AM)
	. = ..()
	if(isliving(AM))
		var/mob/living/L = AM
		if(!isvineimmune(L))
			L.adjustBruteLoss(5)
			to_chat(L, "<span class='alert'>You cut yourself on the thorny vines.</span>")

/**
  * Venus Human Trap
  *
  * The result of a kudzu flower bud, these enemies use vines to drag prey close to them for attack.
  *
  * A carnivorious plant which uses vines to catch and ensnare prey.  Spawns from kudzu flower buds.
  * Each one has a maximum of four vines, which can be attached to a variety of things.  Carbons are stunned when a vine is attached to them, and movable entities are pulled closer over time.
  * Attempting to attach a vine to something with a vine already attached to it will pull all movable targets closer on command.
  * Once the prey is in melee range, melee attacks from the venus human trap heals itself for 10% of its max health, assuming the target is alive.
  * Akin to certain spiders, venus human traps can also be possessed and controlled by ghosts.
  *
  */
/mob/living/simple_animal/hostile/venus_human_trap
	name = "venus human trap"
	desc = "Now you know how the fly feels."
	icon_state = "venus_human_trap"
	layer = SPACEVINE_MOB_LAYER
	health = 50
	maxHealth = 50
	ranged = TRUE
	harm_intent_damage = 5
	obj_damage = 60
	//SKYRAT EDIT START - VINES
	//melee_damage_lower = 25 ORIGINAL
	//melee_damage_upper = 25 ORIGINAL
	melee_damage_lower = 15
	melee_damage_upper = 15
	a_intent = INTENT_HARM
	attack_sound = 'sound/weapons/bladeslice.ogg'
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_tox" = 0, "max_tox" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	unsuitable_atmos_damage = 0
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
	faction = list("hostile","vines","plants")
	initial_language_holder = /datum/language_holder/venus
	del_on_death = TRUE
	/// A list of all the plant's vines
	var/list/vines = list()
	/// The maximum amount of vines a plant can have at one time
	var/max_vines = 4
	/// How far away a plant can attach a vine to something
	var/vine_grab_distance = 5
	/// Whether or not this plant is ghost possessable
	var/playable_plant = FALSE //Normal plants can **not** have players.
	// SKYRAT EDIT START - VINES
	/// copied over from the code from eyeballs (the mob) to make it easier for venus human traps to see in kudzu that doesn't have the transparency mutation
	sight = SEE_SELF|SEE_MOBS|SEE_OBJS|SEE_TURFS
	// SKYRAT EDIT END - VINES

/mob/living/simple_animal/hostile/venus_human_trap/ghost_playable
	health = 75 // Skyrat change: slight health buff
	maxHealth = 75
	playable_plant = TRUE //For admins that want to buss some harmless plants

/mob/living/simple_animal/hostile/venus_human_trap/BiologicalLife(seconds, times_fired)
	if(!(. = ..()))
		return
	pull_vines()

/mob/living/simple_animal/hostile/venus_human_trap/AttackingTarget()
	. = ..()
	if(isliving(target))
		var/mob/living/L = target
		if(L.stat != DEAD)
			adjustHealth(-maxHealth * 0.1)

/mob/living/simple_animal/hostile/venus_human_trap/OpenFire(atom/the_target)
	for(var/datum/beam/B in vines)
		if(B.target == the_target)
			pull_vines()
			ranged_cooldown = world.time + (ranged_cooldown_time * 0.5)
			return
	//if(get_dist(src,the_target) > vine_grab_distance || vines.len == max_vines)
	if(get_dist(src,the_target) > vine_grab_distance || vines.len >= max_vines) //SKYRAT EDIT - VINES
		return
	for(var/turf/T in getline(src,target))
		if (T.density)
			return
		for(var/obj/O in T)
			if(O.density)
				return

	var/datum/beam/newVine = Beam(the_target, "vine", time=INFINITY, maxdistance = vine_grab_distance, beam_type=/obj/effect/ebeam/vine)
	RegisterSignal(newVine, COMSIG_PARENT_QDELETING, .proc/remove_vine, newVine)
	vines += newVine
	if(isliving(the_target))
		var/mob/living/L = the_target
		//L.Paralyze(20)
		L.Knockdown(2 SECONDS) //SKYRAT EDIT - VINES
	ranged_cooldown = world.time + ranged_cooldown_time

/mob/living/simple_animal/hostile/venus_human_trap/Login()
	. = ..()
	to_chat(src, "<span class='boldwarning'>You a venus human trap!  Protect the kudzu at all costs, and feast on those who oppose you!</span>")

/mob/living/simple_animal/hostile/venus_human_trap/attack_ghost(mob/user)
	. = ..()
	if(.)
		return
	humanize_plant(user)

/**
  * Sets a ghost to control the plant if the plant is eligible
  *
  * Asks the interacting ghost if they would like to control the plant.
  * If they answer yes, and another ghost hasn't taken control, sets the ghost to control the plant.
  * Arguments:
  * * mob/user - The ghost to possibly control the plant
  */

/mob/living/simple_animal/hostile/venus_human_trap/proc/humanize_plant(mob/user)
	if(key || !playable_plant || stat)
		return
	var/plant_ask = alert("Become a venus human trap?", "Are you reverse vegan?", "Yes", "No")
	if(plant_ask == "No" || QDELETED(src))
		return
	if(key)
		to_chat(user, "<span class='warning'>Someone else already took this plant!</span>")
		return
	key = user.key
	log_game("[key_name(src)] took control of [name].")

/**
  * Manages how the vines should affect the things they're attached to.
  *
  * Pulls all movable targets of the vines closer to the plant
  * If the target is on the same tile as the plant, destroy the vine
  * Removes any QDELETED vines from the vines list.
  */
/mob/living/simple_animal/hostile/venus_human_trap/proc/pull_vines()
	for(var/datum/beam/B in vines)
		if(istype(B.target, /atom/movable))
			var/atom/movable/AM = B.target
			if(!AM.anchored)
				step(AM,get_dir(AM,src))
		if(get_dist(src,B.target) == 0)
			B.End()

/**
  * Removes a vine from the list.
  *
  * Removes the vine from our list.
  * Called specifically when the vine is about to be destroyed, so we don't have any null references.
  * Arguments:
  * * datum/beam/vine - The vine to be removed from the list.
  */
mob/living/simple_animal/hostile/venus_human_trap/proc/remove_vine(datum/beam/vine, force)
	vines -= vine
