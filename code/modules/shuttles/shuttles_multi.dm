//This is a holder for things like the Vox and Nuke shuttle.
/datum/shuttle/multi_shuttle

	var/cloaked = 1
	var/at_origin = 1
	var/returned_home = 0
	var/move_time = 240
	var/cooldown = 20
	var/last_move = 0	//the time at which we last moved

	var/announcer
	var/arrival_message
	var/departure_message

	var/area/interim
	var/area/last_departed
	var/list/destinations
	var/area/origin
	var/return_warning = 0

/datum/shuttle/multi_shuttle/New()
	..()
	if(origin) last_departed = origin

/datum/shuttle/multi_shuttle/move(var/area/origin, var/area/destination)
	..()
	last_move = world.time
	if (destination == src.origin)
		returned_home = 1

/datum/shuttle/multi_shuttle/proc/announce_departure()

	if(cloaked || isnull(departure_message))
		return

	command_announcement.Announce(departure_message,(announcer ? announcer : "Central Command"))

/datum/shuttle/multi_shuttle/proc/announce_arrival()

	if(cloaked || isnull(arrival_message))
		return

	command_announcement.Announce(arrival_message,(announcer ? announcer : "Central Command"))


/obj/machinery/computer/shuttle_control/multi
	icon_state = "syndishuttle"

/obj/machinery/computer/shuttle_control/multi/attack_hand(mob/user)

	if(..())
		return
	add_fingerprint(user)

	var/datum/shuttle/multi_shuttle/MS = shuttle_controller.shuttles[shuttle_tag]
	if(!istype(MS)) return

	var/dat = "<center>"


	if(MS.moving_status != SHUTTLE_IDLE)
		dat += "Location: <font color='red'>Moving</font> <br>"
	else
		var/area/areacheck = get_area(src)
		dat += "Location: [areacheck.name]<br>"

	if((MS.last_move + MS.cooldown*10) > world.time)
		dat += "<font color='red'>Engines charging.</font><br>"
	else
		dat += "<font color='green'>Engines ready.</font><br>"

	dat += "<br><b><A href='?src=\ref[src];toggle_cloak=[1]'>Toggle cloaking field</A></b><br>"
	dat += "<b><A href='?src=\ref[src];move_multi=[1]'>Move ship</A></b><br>"
	dat += "<b><A href='?src=\ref[src];start=[1]'>Return to base</A></b></center>"


	var/datum/browser/popup = new(user, "[shuttle_tag]shuttlecontrol", "<div align='center'>[shuttle_tag] Ship Control</div>", 300, 600)
	popup.set_content(dat)
	popup.open(FALSE)


/obj/machinery/computer/shuttle_control/multi/Topic(href, href_list)
	if(..())
		return

	usr.set_interaction(src)
	src.add_fingerprint(usr)

	var/datum/shuttle/multi_shuttle/MS = shuttle_controller.shuttles[shuttle_tag]
	if(!istype(MS)) return

	//to_chat(world, "multi_shuttle: last_departed=[MS.last_departed], origin=[MS.origin], interim=[MS.interim], travel_time=[MS.move_time]")

	if (MS.moving_status != SHUTTLE_IDLE)
		to_chat(usr, "<span class='notice'>[shuttle_tag] vessel is moving.</span>")
		return

	if(href_list["start"])

		if(MS.at_origin)
			to_chat(usr, "<span class='warning'>You are already at your home base.</span>")
			return

		if(!MS.return_warning)
			to_chat(usr, "<span class='warning'>Returning to your home base will end your mission. If you are sure, press the button again.</span>")
			//TODO: Actually end the mission.
			MS.return_warning = 1
			return

		MS.long_jump(MS.last_departed,MS.origin,MS.interim,MS.move_time)
		MS.last_departed = MS.origin
		MS.at_origin = 1

	if(href_list["toggle_cloak"])

		MS.cloaked = !MS.cloaked
		to_chat(usr, "<span class='warning'>Ship stealth systems have been [(MS.cloaked ? "activated. The station will not" : "deactivated. The station will")] be warned of our arrival.</span>")

	if(href_list["move_multi"])
		if((MS.last_move + MS.cooldown*10) > world.time)
			to_chat(usr, "<span class='warning'>The ship's drive is inoperable while the engines are charging.</span>")
			return

		var/choice = input("Select a destination.") as null|anything in MS.destinations
		if(!choice) return

		to_chat(usr, "<span class='notice'>[shuttle_tag] main computer recieved message.</span>")

		if(MS.at_origin)
			MS.announce_arrival()
			MS.last_departed = MS.origin
			MS.at_origin = 0


			MS.long_jump(MS.last_departed, MS.destinations[choice], MS.interim, MS.move_time)
			MS.last_departed = MS.destinations[choice]
			return

		else if(choice == MS.origin)

			MS.announce_departure()

		MS.short_jump(MS.last_departed, MS.destinations[choice])
		MS.last_departed = MS.destinations[choice]

	updateUsrDialog()