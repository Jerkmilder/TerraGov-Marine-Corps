/obj/machinery/recharge_station
	name = "cyborg recharging station"
	icon = 'icons/obj/objects.dmi'
	icon_state = "borgcharger0"
	density = 1
	anchored = 1.0
	use_power = 1
	idle_power_usage = 50
	active_power_usage = 50
	var/mob/occupant = null
	var/max_internal_charge = 15000 		// Two charged borgs in a row with default cell
	var/current_internal_charge = 15000 	// Starts charged, to prevent power surges on round start
	var/charging_cap_active = 25000			// Active Cap - When cyborg is inside
	var/charging_cap_passive = 2500			// Passive Cap - Recharging internal capacitor when no cyborg is inside
	var/icon_update_tick = 0				// Used to update icon only once every 10 ticks



/obj/machinery/recharge_station/New()
	..()
	build_icon()
	update_icon()

/obj/machinery/recharge_station/process()
	if(machine_stat & (BROKEN))
		return

	if((machine_stat & (NOPOWER)) && !current_internal_charge) // No Power.
		return

	var/chargemode = 0
	if(src.occupant)
		process_occupant()
		chargemode = 1
	// Power Stuff

	if(machine_stat & NOPOWER)
		current_internal_charge = max(0, (current_internal_charge - (50 * GLOB.CELLRATE))) // Internal Circuitry, 50W load. No power - Runs from internal cell
		return // No external power = No charging



	if(max_internal_charge < current_internal_charge)
		current_internal_charge = max_internal_charge// Safety check if varedit adminbus or something screws up
	// Calculating amount of power to draw
	var/charge_diff = max_internal_charge - current_internal_charge // OK we have charge differences
	charge_diff = charge_diff / GLOB.CELLRATE 							// Deconvert from Charge to Joules
	if(chargemode)													// Decide if use passive or active power
		charge_diff = between(0, charge_diff, charging_cap_active)	// Trim the values to limits
	else															// We should have load for this tick in Watts
		charge_diff = between(0, charge_diff, charging_cap_passive)

	charge_diff += 50 // 50W for circuitry

	if(idle_power_usage != charge_diff) // Force update, but only when our power usage changed this tick.
		idle_power_usage = charge_diff
		update_use_power(1,TRUE)

	current_internal_charge = min((current_internal_charge + ((charge_diff - 50) * GLOB.CELLRATE)), max_internal_charge)

	if(icon_update_tick >= 10)
		update_icon()
		icon_update_tick = 0
	else
		icon_update_tick++

	return 1


/obj/machinery/recharge_station/allow_drop()
	return 0

/obj/machinery/recharge_station/examine(mob/user)
	to_chat(user, "The charge meter reads: [round(chargepercentage())]%")

/obj/machinery/recharge_station/proc/chargepercentage()
	return ((current_internal_charge / max_internal_charge) * 100)

/obj/machinery/recharge_station/relaymove(mob/user as mob)
	if(user.stat)
		return
	src.go_out()
	return

/obj/machinery/recharge_station/emp_act(severity)
	if(machine_stat & (BROKEN|NOPOWER))
		..(severity)
		return
	if(occupant)
		occupant.emp_act(severity)
		go_out()
	..(severity)

/obj/machinery/recharge_station/update_icon()
	..()
	overlays.Cut()
	switch(round(chargepercentage()))
		if(1 to 20)
			overlays += image('icons/obj/objects.dmi', "statn_c0")
		if(21 to 40)
			overlays += image('icons/obj/objects.dmi', "statn_c20")
		if(41 to 60)
			overlays += image('icons/obj/objects.dmi', "statn_c40")
		if(61 to 80)
			overlays += image('icons/obj/objects.dmi', "statn_c60")
		if(81 to 98)
			overlays += image('icons/obj/objects.dmi', "statn_c80")
		if(99 to 110)
			overlays += image('icons/obj/objects.dmi', "statn_c100")

/obj/machinery/recharge_station/proc/build_icon()
	if(NOPOWER|BROKEN)
		if(src.occupant)
			icon_state = "borgcharger1"
		else
			icon_state = "borgcharger0"
	else
		icon_state = "borgcharger0"

/obj/machinery/recharge_station/proc/process_occupant()
	if(src.occupant)
		if (iscyborg(occupant))
			var/mob/living/silicon/robot/R = occupant
			if(R.module)
				R.module.respawn_consumable(R)
			if(!R.cell)
				return
			if(!R.cell.fully_charged())
				var/diff = min(R.cell.maxcharge - R.cell.charge, 500) 	// 500 charge / tick is about 2% every 3 seconds
				diff = min(diff, current_internal_charge) 				// No over-discharging
				R.cell.give(diff)
				current_internal_charge -= diff
			else
				update_use_power(1)

/obj/machinery/recharge_station/proc/go_out()
	if(!( src.occupant ))
		return
	//for(var/obj/O in src)
	//	O.loc = src.loc
	if (src.occupant.client)
		src.occupant.client.eye = src.occupant.client.mob
		src.occupant.client.perspective = MOB_PERSPECTIVE
	src.occupant.loc = src.loc
	src.occupant = null
	STOP_PROCESSING(SSmachines, src)
	build_icon()
	update_use_power(1)
	return


/obj/machinery/recharge_station/verb/move_eject()
	set category = "Object"
	set src in oview(1)
	if (usr.stat != 0)
		return
	src.go_out()
	add_fingerprint(usr)
	return

/obj/machinery/recharge_station/verb/move_inside()
	set category = "Object"
	set src in oview(1)
	if (usr.stat == 2)
		//Whoever had it so that a borg with a dead cell can't enter this thing should be shot. --NEO
		return
	if (!(istype(usr, /mob/living/silicon/)))
		to_chat(usr, "<span class='boldnotice'>Only non-organics may enter the recharger!</span>")
		return
	if (src.occupant)
		to_chat(usr, "<span class='boldnotice'>The cell is already occupied!</span>")
		return
	if (!usr:cell)
		to_chat(usr, "<span class='notice'>Without a powercell, you can't be recharged.</span>")
		//Make sure they actually HAVE a cell, now that they can get in while powerless. --NEO
		return
	usr.stop_pulling()
	if(usr && usr.client)
		usr.client.perspective = EYE_PERSPECTIVE
		usr.client.eye = src
	usr.loc = src
	src.occupant = usr
	START_PROCESSING(SSmachines, src)
	/*for(var/obj/O in src)
		O.loc = src.loc*/
	src.add_fingerprint(usr)
	build_icon()
	update_use_power(1)
	return
