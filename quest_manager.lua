-- Singletons
local quest_manager
local enemy_manager
local message_manager

-- Types
local message_manager_type_def = sdk.find_type_definition("snow.gui.MessageManager");
local get_enemy_name_message_method = message_manager_type_def:get_method("getEnemyNameMessage");
local enemy_character_base_type_def = sdk.find_type_definition("snow.enemy.EnemyCharacterBase");
local enemy_type_field = enemy_character_base_type_def:get_field("<EnemyType>k__BackingField");

-- Settings
local config = {
    end_quest_time = 60.0
}
local debug = false

local function clear_quest()
    quest_manager:call("setQuestClear")
end

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
end

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
            if not is_hyakuryu then
                if imgui.button("Kill") then
                    boss:call("questEnemyDie", 0)
                    boss:call("dieSelf")
                end
                if imgui.button("Capture") then
                    boss:call("questEnemyDie", 1)
                    boss:call("dieSelf")
                end                     
                if imgui.button("Request go away") then
                    boss:call("requestBossAwayProcess", 44)
                end
                imgui.same_line()
                imgui.text(" (Not instant)")
            else 
                if imgui.button("Kill") then
                    boss:call("questEnemyDie", 0)
                    boss:call("dieSelf")
                    boss:call("startHyakuryuExit")
                end
                if imgui.button("Force exit") then
                    boss:call("setImmediatelyForceHyakuryuExit")
                end
            end
            if debug and imgui.button("DEBUG") then
                DEBUG_BOSS = boss
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

re.on_draw_ui(function()
    if not quest_manager then
        init_singletons()
        return
    end
    if imgui.tree_node("Quest Manager") then

        local status = quest_manager:get_field("_QuestStatus")

        if status == 2 then 
            if imgui.button("Clear Quest") then
                clear_quest()
            end
            imgui.same_line()
            imgui.text(" (You will not get monsters rewards)")

            tree_bosses()
        else 
            imgui.text("Not in quest...")
        end

        if imgui.tree_node("Settings") then
            local changed = false
            changed, config.end_quest_time = imgui.drag_int("End quest time", config.end_quest_time, 1, 1, 360)
            if changed then
                write_config()
            end
            imgui.tree_pop()
        end
            
        imgui.tree_pop()
    end
end)

re.on_pre_application_entry("UpdateBehavior", function() 
    if not quest_manager then
        return nil
    end

    local status = quest_manager:get_field("_QuestStatus")
    local end_flow = quest_manager:get_field("_QuestEndFlowTimer")

    if status == 3 and end_flow > config.end_quest_time then
        quest_manager:set_field("_QuestEndFlowTimer", config.end_quest_time)
    end
end)

read_config()
init_singletons()