/datum/withdraw_tab
	var/stockpile_index = -1
	var/budget = 0
	var/compact = TRUE
	var/free_withdraw = FALSE
	var/always_stocked = FALSE
	var/allow_remote = TRUE
	var/current_category = "Raw Materials"
	var/list/categories = list("Raw Materials", "Foodstuffs", "Fruits", "Seafood")
	var/list/stockpile_datums = null
	var/obj/structure/roguemachine/parent_structure = null

/datum/withdraw_tab/New(stockpile_param, obj/structure/roguemachine/structure_param, list/stockpile_datums_param = null, free_withdraw_param = FALSE, always_stocked_param = FALSE, allow_remote_param = TRUE)
	. = ..()
	stockpile_index = stockpile_param
	parent_structure = structure_param
	stockpile_datums = stockpile_datums_param
	free_withdraw = free_withdraw_param
	always_stocked = always_stocked_param
	allow_remote = allow_remote_param
	if(always_stocked && stockpile_datums)
		for(var/datum/roguestock/stockpile/A in stockpile_datums)
			A.held_items[stockpile_index] = A.stockpile_limit

/datum/withdraw_tab/proc/get_stockpile_datums()
	if(stockpile_datums)
		return stockpile_datums
	return SStreasury.stockpile_datums

/datum/withdraw_tab/proc/get_contents(title, show_back)
	var/contents = "<center>[title]<BR>"
	if(show_back)
		contents += "<a href='?src=[REF(parent_structure)];navigate=directory'>(back)</a><BR>"

	contents += "--------------<BR>"
	if(free_withdraw)
		contents += "<b>Fully stocked.</b><BR>"
	else
		contents += "<a href='?src=[REF(parent_structure)];change=1'>Stored Mammon: [budget]</a><BR>"
	contents += "<a href='?src=[REF(parent_structure)];compact=1'>Compact Mode: [compact ? "ENABLED" : "DISABLED"]</a></center><BR>"
	var/mob/living/user = usr
	if (!free_withdraw && user && HAS_TRAIT(user, TRAIT_FOOD_STIPEND))
		contents += "<center><b>TREASURY-LINE ACTIVE.</b></center><BR>"
	var/selection = "Categories: "
	for(var/category in categories)
		if(category == current_category)
			selection += "<b>[current_category]</b> "
		else
			selection += "<a href='?src=[REF(parent_structure)];changecat=[category]'>[category]</a> "
	contents += selection + "<BR>"
	contents += "--------------<BR>"
	var/list/source_stockpiles = get_stockpile_datums()

	if(compact)
		for(var/datum/roguestock/stockpile/A in source_stockpiles)
			if(A.category != current_category)
				continue
			var/remote_stockpile = stockpile_index == 1 ? 2 : 1
			var/local_price = free_withdraw ? 0 : A.withdraw_price
			var/remote_price = free_withdraw ? 0 : A.withdraw_price + A.transport_fee
			if(!A.withdraw_disabled)
				contents += "<b>[A.name] (Max: [A.stockpile_limit]):</b> <a href='?src=[REF(parent_structure)];withdraw=[REF(A)]'>LCL: [A.held_items[stockpile_index]] at [local_price]m</a>"
				if(allow_remote)
					contents += " /<a href='?src=[REF(parent_structure)];withdraw=[REF(A)];remote=1'>RMT: [A.held_items[remote_stockpile]] at [remote_price]m</a>"
				contents += "<BR>"

			else
				contents += "<b>[A.name]:</b> Withdrawing Disabled..."

	else
		for(var/datum/roguestock/stockpile/A in source_stockpiles)
			if(A.category != current_category)
				continue
			contents += "[A.name]<BR>"
			contents += "[A.desc]<BR>"
			contents += "Stockpiled Amount (Local): [A.held_items[stockpile_index]]<BR>"
			if(allow_remote)
				var/remote_stockpile = stockpile_index == 1 ? 2 : 1
				contents += "Stockpiled Amount (Remote): [A.held_items[remote_stockpile]]<BR>"
			if(!A.withdraw_disabled)
				var/local_price = free_withdraw ? 0 : A.withdraw_price
				var/remote_price = free_withdraw ? 0 : A.withdraw_price + A.transport_fee
				contents += "<a href='?src=[REF(parent_structure)];withdraw=[REF(A)]'>\[Withdraw Local ([local_price])\] </a>"
				if(allow_remote)
					contents += "<a href='?src=[REF(parent_structure)];withdraw=[REF(A)];remote=1'>\[Withdraw Remote ([remote_price])\]</a>"
				contents += "<BR><BR>"
			else
				contents += "Withdrawing Disabled...<BR><BR>"

	return contents

/datum/withdraw_tab/proc/perform_action(href, href_list)
	if(href_list["withdraw"])
		var/list/source_stockpiles = get_stockpile_datums()
		var/datum/roguestock/D = locate(href_list["withdraw"]) in source_stockpiles
		if(!D)
			return FALSE

		var/remote = href_list["remote"]
		if(remote && !allow_remote)
			remote = FALSE
		var/source_stockpile = stockpile_index
		var/total_price = free_withdraw ? 0 : D.withdraw_price
		if (remote)
			total_price += free_withdraw ? 0 : D.transport_fee
			source_stockpile = stockpile_index == 1 ? 2 : 1

		if(D.withdraw_disabled)
			return FALSE
		if(!always_stocked && D.held_items[source_stockpile] <= 0)
			parent_structure.say("Insufficient stock.")
		else if(!free_withdraw && total_price > budget)
			var/mob/living/user = usr
			if (user && HAS_TRAIT(user, TRAIT_FOOD_STIPEND))
				if (SStreasury.treasury_value >= total_price)
					if(!always_stocked)
						D.held_items[source_stockpile]--
					SStreasury.log_to_steward("-[D.withdraw_price]m worth of goods withdrawn direct from vomitorium (keep stipend)")
					var/obj/item/I = new D.item_type(parent_structure.loc)
					I.from_stockpile = TRUE
					to_chat(user, span_info("[parent_structure] chitters and squeaks into the treasury ratlines."))
					if(!user.put_in_hands(I))
						I.forceMove(get_turf(user))
					playsound(parent_structure.loc, 'sound/misc/hiss.ogg', 100, FALSE, -1)
				else
					parent_structure.say("The treasury is barren. Please insert coinage.")
			else
				parent_structure.say("Insufficient mammon.")
		else
			if(!always_stocked)
				D.held_items[source_stockpile]--
			if(!free_withdraw)
				budget -= total_price
				SStreasury.economic_output -= D.export_price // Prevent GDP double counting
				SStreasury.give_money_treasury(D.withdraw_price, "stockpile withdraw")
				record_round_statistic(STATS_STOCKPILE_REVENUE, D.withdraw_price)
			var/obj/item/I = new D.item_type(parent_structure.loc)
			I.from_stockpile = TRUE
			var/mob/user = usr
			if(!user.put_in_hands(I))
				I.forceMove(get_turf(user))
			playsound(parent_structure.loc, 'sound/misc/hiss.ogg', 100, FALSE, -1)
		return TRUE
	if(href_list["compact"])
		if(!usr.canUseTopic(parent_structure, BE_CLOSE))
			return FALSE
		if(ishuman(usr))
			compact = !compact
		return TRUE
	if(href_list["change"])
		if(!usr.canUseTopic(parent_structure, BE_CLOSE))
			return FALSE
		if(ishuman(usr))
			if(budget > 0)
				parent_structure.budget2change(budget, usr)
				budget = 0
	if(href_list["changecat"])
		if(!usr.canUseTopic(parent_structure, BE_CLOSE))
			return FALSE
		current_category = href_list["changecat"]
		return TRUE

/datum/withdraw_tab/proc/insert_coins(obj/item/roguecoin/C)
	budget += C.get_real_price()
	qdel(C)
	parent_structure.update_icon()
	playsound(parent_structure.loc, 'sound/misc/coininsert.ogg', 100, TRUE, -1)

/proc/stock_announce(message)
	for(var/obj/structure/roguemachine/stockpile/S in SSroguemachine.stock_machines)
		S.say(message, spans = list("info"))
