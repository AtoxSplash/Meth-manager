MethManager = MethManager or class()

if not MethManager.modname then
	MethManager.modname = "MethManager"
	MethManager.prefix = "[" .. MethManager.modname .. "] "
	MethManager._path = ModPath
	MethManager._data_path = SavePath.. "methmanager.json"
	MethManager._last_state = {}
	MethManager.settings = {
		display_mode = 2,
		mm_repeat_msg = true
	}

	local file = io.open(MethManager._data_path, 'r')
	
	if file then
		for k, v in pairs(json.decode(file:read('*all')) or {}) do
			MethManager.settings[k] = v
		end
		file:close()
	end
end

MethManager.ingredient_dialog = MethManager.ingredient_dialog or {}
MethManager.disallowedIngredientsUnit = MethManager.disallowedIngredientsUnit or {}
MethManager.disallowedIngredientsTextId = MethManager.disallowedIngredientsTextId or {}

function MethManager:save()
	local file = io.open(self._data_path, 'w+')

	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

function MethManager:send_message_to_peer(peer, message) 
	if managers.network:session() then
		peer:send("send_chat_message", ChatManager.GAME, self.prefix .. message)
	end
end

function MethManager:can_self_interact(peer_id, unit)
	if #MethManager.disallowedIngredientsUnit == 2 and unit and alive(unit) and unit.name then
		return unit:name() ~= Idstring(MethManager.disallowedIngredientsUnit[1]) and unit:name() ~= Idstring(MethManager.disallowedIngredientsUnit[2])
	end

	return true
end

function MethManager:can_peer_interact(peer_id, tweak_data_id)
	if #MethManager.disallowedIngredientsTextId == 2 then
		return tweak_data.interaction[tweak_data_id].text_id ~= MethManager.disallowedIngredientsTextId[1] and tweak_data.interaction[tweak_data_id].text_id ~= MethManager.disallowedIngredientsTextId[2]
	end

	return true
end

function MethManager:tase_player(peer_id) 
	local player_unit = managers.criminals:character_unit_by_peer_id(peer_id)
	local player_down_time = player_unit:character_damage():down_time()
	local player_id = player_unit:id()

	managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, "tased", player_down_time, player_id)

	self._last_state[peer_id] = player_unit:movement():current_state_name()
	player_unit:movement():sync_movement_state("tased", player_down_time)
end

function MethManager:untase_player(peer_id) 
	local player_unit = managers.criminals:character_unit_by_peer_id(peer_id)
	local player_down_time = player_unit:character_damage():down_time()
	local player_id = player_unit:id()

	if self._last_state[peer_id] ~= "" then
		managers.network:session():send_to_peers_synched("sync_player_movement_state", player_unit, self._last_state[peer_id], player_down_time, player_id)
		player_unit:movement():sync_movement_state(self._last_state[peer_id], player_down_time)
		self._last_state[peer_id] = ""
	end
end


if RequiredScript == "lib/managers/localizationmanager" then
	Hooks:Add("LocalizationManagerPostInit", "MethManager_LocalizationManagerPostInit", function(loc)
		local language_filename

		if BLT.Localization._current == 'cht' or BLT.Localization._current == 'zh-cn' then
			MethManager._abbreviation_length_v = 2
			language_filename = 'chinese.txt'
		end

		if not language_filename then
			local modname_to_language = {
				-- ['Payday 2 Korean patch'] = 'korean.txt',
				-- ['PAYDAY 2 THAI LANGUAGE Mod'] = 'thai.txt',
				['chnmod_patch'] = 'schinese.txt',
				['modschn'] = 'schinese.txt',
			}
			for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
				language_filename = mod:IsEnabled() and modname_to_language[mod:GetName()]
				if language_filename then
					MethManager._abbreviation_length_v = 2
					break
				end
			end
		end

		if not language_filename then
			for _, filename in pairs(file.GetFiles(MethManager._path .. 'loc/')) do
				local str = filename:match('^(.*).txt$')

				if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
					language_filename = filename
					break
				end
			end
		end

		if language_filename then
			loc:load_localization_file(MethManager._path .. 'loc/' .. language_filename)
		else
			loc:load_localization_file(MethManager._path .. 'loc/english.txt', false)
		end

		-- Cook off
		MethManager.ingredient_dialog["pln_rt1_12"] = {["text"] = loc:text("meth_manager_ing_added")}
		MethManager.ingredient_dialog["pln_rt1_20"] = {["text"] = loc:text("meth_manager_add_mu"), ["text_id"] = "hud_int_methlab_bubbling", ["unit"] = "units/payday2/pickups/gen_pku_methlab_bubbling/gen_pku_methlab_bubbling"}
		MethManager.ingredient_dialog["pln_rt1_22"] = {["text"] = loc:text("meth_manager_add_cs"), ["text_id"] = "hud_int_methlab_caustic_cooler", ["unit"] = "units/payday2/pickups/gen_pku_methlab_caustic_cooler/gen_pku_methlab_caustic_cooler"}
		MethManager.ingredient_dialog["pln_rt1_24"] = {["text"] = loc:text("meth_manager_add_hcl"), ["text_id"] = "hud_int_methlab_gas_to_salt", ["unit"] = "units/payday2/pickups/gen_pku_methlab_liquid_meth/gen_pku_methlab_liquid_meth"}
		MethManager.ingredient_dialog["pln_rat_stage1_28"] = {["text"] = loc:text("meth_manager_meth_done")}

		-- Rats
		MethManager.ingredient_dialog["pln_rat_stage1_20"] = {["text"] = loc:text("meth_manager_add_mu")}
		MethManager.ingredient_dialog["pln_rat_stage1_22"] = {["text"] = loc:text("meth_manager_add_cs")}
		MethManager.ingredient_dialog["pln_rat_stage1_24"] = {["text"] = loc:text("meth_manager_add_hcl")}

		WrongIngrident = loc:text("meth_manager_wrong_ing")
		TeamWrongIngrident = loc:text("meth_manager_team_wrong_ing")
	end)
end

if RequiredScript == "lib/managers/objectinteractionmanager" then 
	local SE_interact_original = ObjectInteractionManager.interact
	function ObjectInteractionManager:interact(player)
		if not MethManager:can_self_interact(_G.LuaNetworking:LocalPeerID(), self._active_unit) then
			managers.hud:show_hint({text = WrongIngrident, time = 3})

			return false
		else
			return SE_interact_original(self, player)
		end
	end
end

if RequiredScript == "lib/network/handlers/unitnetworkhandler" then
	Hooks:PostHook(UnitNetworkHandler, "sync_teammate_progress", "MethManager_UnitNetworkHandler", function(self, type_index, enabled, tweak_data_id, timer, success, sender)
		if not _G.LuaNetworking:IsHost() or type_index ~= 1 or success == true then
			return
		end

		local peer = self._verify_sender(sender)
		local peer_id = peer and peer:id()

		if peer_id then
			if not MethManager:can_peer_interact(peer_id, tweak_data_id) then
				if enabled == true then
					managers.hud:show_hint({text = tostring(peer:name()).. " ".. TeamWrongIngrident, time = 3})
					MethManager:send_message_to_peer(peer, WrongIngrident)
					MethManager:tase_player(peer_id)
				else
					MethManager:untase_player(peer_id)
				end
			end
		end
	end)
end

if RequiredScript == "lib/network/base/networkpeer" then
	Hooks:Add("NetworkManagerOnPeerAdded", "MethManager_NetworkManagerOnPeerAdded", function()
		if not _G.LuaNetworking:IsHost() then
			return
		end
	end)
end

if RequiredScript == "lib/managers/dialogmanager" then
	local origin_queue_dialog = DialogManager.queue_dialog

	function DialogManager:queue_dialog(id, ...)
		if id ~= nil and MethManager.ingredient_dialog[id] ~= nil then

			MethManager.disallowedIngredientsUnit = {"units/payday2/pickups/gen_pku_methlab_caustic_cooler/gen_pku_methlab_caustic_cooler", "units/payday2/pickups/gen_pku_methlab_liquid_meth/gen_pku_methlab_liquid_meth", "units/payday2/pickups/gen_pku_methlab_bubbling/gen_pku_methlab_bubbling"}
			for k, v in pairs(MethManager.disallowedIngredientsUnit) do 
				if v == MethManager.ingredient_dialog[id]["unit"] then
					table.remove(MethManager.disallowedIngredientsUnit, k)
				end
			end

			MethManager.disallowedIngredientsTextId = {"hud_int_methlab_bubbling", "hud_int_methlab_caustic_cooler", "hud_int_methlab_gas_to_salt"}
			for k, v in pairs(MethManager.disallowedIngredientsTextId) do
				if v == MethManager.ingredient_dialog[id]["text_id"] then
					table.remove(MethManager.disallowedIngredientsTextId, k)
				end
			end

			if not MethManager.settings.mm_repeat_msg then
				if id == lastDialog then
					return
				end
			end

			if MethManager.settings.display_mode == 0 or MethManager.settings.display_mode == 2 then
				managers.chat:send_message(ChatManager.GAME, managers.network.account:username() or "Offline", MethManager.ingredient_dialog[id]["text"])
			end

			if MethManager.settings.display_mode == 1 or MethManager.settings.display_mode == 2 then
				managers.hud:show_hint({text = MethManager.ingredient_dialog[id]["text"]})
			end

			lastDialog = id

			return
		end

		return origin_queue_dialog(self, id, ...)
	end
end

if RequiredScript == "lib/managers/menumanager" then
	Hooks:Add('MenuManagerInitialize', 'MethManager_MenuManagerInitialize', function()
		MenuCallbackHandler.MethManagerTest = function(this, item)
			MethManager.settings[item:name()] = item:value() == "on"
			MethManager:save()
		end

		MenuHelper:LoadFromJsonFile(MethManager._path.. 'menu/options.txt', MethManager, MethManager.settings)
	end)
end

if RequiredScript == "core/lib/utils/coreclass" then
	MethManager.settings.display_mode = MethManager.settings.display_mode + 1

	if MethManager.settings.display_mode > 3 then
		MethManager.settings.display_mode = 0
	end

	if MethManager.settings.display_mode == 0 then
		managers.hud:show_hint({text = "Chat mode"})
	elseif MethManager.settings.display_mode == 1 then
		managers.hud:show_hint({text = "Popup mode"})
	elseif MethManager.settings.display_mode == 2 then
		managers.hud:show_hint({text = "Chat and popup mode"})
	elseif MethManager.settings.display_mode == 3 then
		managers.hud:show_hint({text = "Disabled"})
	end

	MethManager:save()
end