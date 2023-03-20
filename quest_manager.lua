-- Singletons
local quest_manager
local enemy_manager
local message_manager
local player_manager

-- Types
local message_manager_type_def = sdk.find_type_definition("snow.gui.MessageManager");
local get_enemy_name_message_method = message_manager_type_def:get_method("getEnemyNameMessage");
local enemy_character_base_type_def = sdk.find_type_definition("snow.enemy.EnemyCharacterBase");
local enemy_type_field = enemy_character_base_type_def:get_field("<EnemyType>k__BackingField");

-- Settings
local config = {
    end_quest_time_enabled = true,
    end_quest_time = 60.0,
    actions = {}
}
local debug = false
local version = '1.0.3'

local emote_dict = {
    [732121360] = "Greetings",
    [2886060014] = "Point",
    [1570689224] = "Nod",
    [450598662] = "Refuse",
    [2890191254] = "Wave",
    [1681284212] = "Applaud",
    [3846365576] = "Stop Stop stop!",
    [521758449] = "Show off 1",
    [767487127] = "Show off 2",
    [419486350] = "Call",
    [3142136635] = "Remorse",
    [2042488002] = "Joy 1",
    [1441936304] = "Joy 2",
    [4271773211] = "Taunt",
    [2440417892] = "Good Work",
    [2679737030] = "Apologize",
    [577511813] = "Woohoo",
    [3747543313] = "Shadow box",
    [2911330891] = "Crossed Arms",
    [690136471] = "Ninjutsu",
    [2779914844] = "Shock",
    [265971467] = "Have Fun",
    [1597975431] = "LOL",
    [1388851383] = "Kneel",
    [418062269] = "OMG",
    [3868312077] = "For honor",
    [1349005651] = "Bow",
    [4066581064] = "Genuflect",
    [1532093800] = "Flourish",
    [2791190130] = "Ponder",
    [3400342652] = "Spirit Fingers",
    [8324598] = "Prance",
    [2264077207] = "Regret",
    [328531840] = "Mew Mew"
}

local emote_indexes = {}
local emote_names = {}
local i = 1
for key, name in pairs(emote_dict) do
    emote_indexes[key] = i
    i = i + 1
    table.insert(emote_names, name)
end
  
local action_types = {
    "Clear Quest",
    "Kill Nearest",
    "Capture Nearest",
    "Force Exit"
}

-- Init

local function init_singletons()
	if not quest_manager then
		quest_manager = sdk.get_managed_singleton('snow.QuestManager')
	end

    if not enemy_manager then
        enemy_manager = sdk.get_managed_singleton('snow.enemy.EnemyManager')
    end

    if not message_manager then
        message_manager = sdk.get_managed_singleton('snow.gui.MessageManager')
    end

    if not player_manager then
        player_manager = sdk.get_managed_singleton("snow.player.PlayerManager")
    end
end

-- Utils

local function get_key(dict, value)
    for key, name in pairs(dict) do
        if name == value then
            return key
        end
    end
    return nil
end

local function distance(pos1, pos2)
    return ((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2 + (pos2.z - pos1.z)^2)^0.5
end

local function is_alive(enemy)
    local dead = enemy:call("isNowDie", 0)
    return not dead
end

local function get_nearest()
    local nearest

    if player_manager then
	    local master_player = player_manager:call("findMasterPlayer")
        if master_player ~= nil then 
            local player_pos = master_player:call("get_Pos")
            local count = enemy_manager:call("getBossEnemyCount")
            local nearestDis
            for i = 0, count - 1 do
                local boss = enemy_manager:call("getBossEnemy", i)
                local boss_pos = boss:call("get_Pos")
                local dis = distance(player_pos, boss_pos)
                if is_alive(boss) and (nearestDis == nil or nearestDis > dis) then
                    nearestDis = dis
                    nearest = boss
                end
            end
        end
    end

    return nearest
end

-- Actions

local function clear_quest()
    quest_manager:call("setQuestClear")
end

local function set_enableCapture(enemy)
    local physical_param = enemy:get_field("<PhysicalParam>k__BackingField");
    local vital_param = physical_param:call("getVital", 0, 0);

    local max_health = vital_param:call("get_Max");
    physical_param:call("setCaptureHpVital", max_health + 1);
    physical_param:call("setDyingHpVital", max_health + 1);
end

local function capture(enemy)
    enemy:call("questEnemyDie", 1)
    enemy:call("dieSelf")
end

local function kill(enemy)
    enemy:call("questEnemyDie", 0)
    enemy:call("dieSelf")
end

local function force_exit(enemy)
    enemy:call("setImmediatelyForceHyakuryuExit")
end

local function kill_nearest()
    local nearest = get_nearest()

    if nearest ~= nil then
        kill(nearest)
    end
end

local function capture_nearest()
    local nearest = get_nearest()

    if nearest ~= nil then
        capture(nearest)
    end
end

local function force_exit_nearest()
    local nearest = get_nearest()

    if nearest ~= nil then
        force_exit(nearest)
    end
end

local function on_anim_changed(anim)
    if quest_manager == nil then
        return
    end
    local status = quest_manager:get_field("_QuestStatus")
    if status == 2 and config.actions ~= nil then
        local is_hyakuryu = quest_manager:call("isHyakuryuQuest")
        for _, action in pairs(config.actions) do
            if action.emote == anim then
                if action.type == 1 then
                    clear_quest()
                end
                if action.type == 2 then
                    kill_nearest()
                end
                if action.type == 3 and not is_hyakuryu then
                    capture_nearest()
                end
                if action.type == 4 and is_hyakuryu then
                    force_exit_nearest()
                end
            end
        end
    end
end

-- Config

local function read_config()
    local config_file = json.load_file("quest_manager.json")
    if config_file then
        config = config_file
    end
end

local function write_config()
    json.dump_file("quest_manager.json", config)
end

local function tree_boss(boss, is_hyakuryu, count)
    local enemy_type = enemy_type_field:get_data(boss)
    if enemy_type ~= nil then                
        local enemy_name = get_enemy_name_message_method:call(message_manager, enemy_type)
        if enemy_name == nil then
            enemy_name = "Unknown"
        end

        local is_target = boss:call("isQuestTargetEnemy")

        if is_target then
            enemy_name = enemy_name .. " (Target)"
        end

        if imgui.tree_node(count .. " - " .. enemy_name) then
            if imgui.button("Kill") then
                kill(boss)
            end
            if not is_hyakuryu then
                if imgui.button("Capturable") then
                    set_enableCapture(boss)
                end
                if imgui.button("Capture") then
                    capture(boss)
                end                     
                if imgui.button("Request go away") then
                    boss:call("requestBossAwayProcess", 44)
                end
                imgui.same_line()
                imgui.text(" (Not instant)")
                if imgui.button("Debug") then
                    GLOBAL_MONSTER = boss
                end
            else 
                if imgui.button("Force exit") then
                    force_exit(boss)
                end
            end

            imgui.tree_pop()
        end
    end
end

local function tree_bosses()
    if imgui.tree_node("Larges Monsters") then
        local is_hyakuryu = quest_manager:call("isHyakuryuQuest")
        local count = enemy_manager:call("getBossEnemyCount")
        for i = 0, count - 1 do
            local boss = enemy_manager:call("getBossEnemy", i)
            tree_boss(boss, is_hyakuryu, i + 1)
        end
        imgui.tree_pop()
    end
end

-- Main

local last_anim

re.on_frame(function()
	if player_manager then
	    local masterPlayer = player_manager:call("findMasterPlayer");
		if masterPlayer then
			local mBehaviortree = masterPlayer:call("get_GameObject"):call("getComponent(System.Type)",sdk.typeof("via.behaviortree.BehaviorTree"));
			local curNodeID = mBehaviortree:call("getCurrentNodeID", 0);

            if curNodeID ~= last_anim then
                log.info("anim: " .. curNodeID)
                last_anim = curNodeID
                on_anim_changed(curNodeID)
            end
		end
	end
end);

re.on_draw_ui(function()
    if not quest_manager then
        init_singletons()
        return
    end
    if imgui.tree_node("Quest Manager (" .. version .. ")") then
        local status = quest_manager:get_field("_QuestStatus")

        if status == 2 then 
            if imgui.button("Clear Quest") then
                clear_quest()
            end
            imgui.same_line()
            imgui.text(" (You will not get monsters rewards)")
            tree_bosses(is_hyakuryu)
        else 
            imgui.text("Not in quest...")
        end

        if imgui.tree_node("Settings") then
            local changed = false
            changed, config.end_quest_time_enabled = imgui.checkbox("Enable end quest time", config.end_quest_time_enabled)
            changed, config.end_quest_time = imgui.drag_int("End quest time", config.end_quest_time, 1, 1, 360)

            imgui.text("Custom actions:")

            if config.actions == nil then
                config.actions = {}
                changed = true
            end

            for key, action in pairs(config.actions) do
                if imgui.tree_node(action_types[action.type]) then
                    local type_changed = false
                    local emote_changed = false
                    local action_type = action.type
                    local action_emote_index = emote_indexes[action.emote]
                    type_changed, action_type = imgui.combo("Type", action_type, action_types)
                    emote_changed, action_emote_index = imgui.combo("Emote", action_emote_index, emote_names)

                    if type_changed or emote_changed then
                        changed = true
                        local emote = get_key(emote_indexes, action_emote_index)
                        local new_action = {
                            type = action_type,
                            emote = emote
                        }
                        config.actions[key] = new_action
                    end

                    if imgui.button("Remove action") then
                        changed = true
                        table.remove(config.actions, key)
                    end

                    imgui.tree_pop()
                end
            end

            if #config.actions < #action_types and imgui.button("Add action") then
                changed = true
                for key, _ in pairs(action_types) do
                    local found = false
                    for _, action in pairs(config.actions) do
                        if action.type == key then 
                            found = true
                            break
                        end
                    end
                    if not found then
                        local first_emote, _ = next(emote_dict, nil)
                        table.insert(config.actions, {
                            type = key,
                            emote = first_emote
                        })
                        break
                    end
                end
            end

            if changed then
                write_config()
            end
            imgui.tree_pop()
        end

        if imgui.button("Debug object") then
            start_debug()
        end
            
        imgui.tree_pop()
    end
end)

local end_quest_time_changed = false
re.on_application_entry("UpdateBehavior", function() 
    if not quest_manager then
        return nil
    end

    local status = quest_manager:get_field("_QuestStatus")

    if config.end_quest_time_enabled then
        if status == 3 then
            if not end_quest_time_changed then 
                local end_flow = quest_manager:get_field("_QuestEndFlowTimer")
                if math.ceil(end_flow) ~= config.end_quest_time then
                    quest_manager:set_field("_QuestEndFlowTimer", config.end_quest_time)
                else 
                    end_quest_time_changed = true
                end
            end
        else
            end_quest_time_changed = false
        end
    end
end)

read_config()
init_singletons()

