require "util"
local Smarts = {}

Smarts.SHORTCUT_NAME = 'hhr-handyhands-toggle'
Smarts.NTH_TICK = settings.startup["hhr-nth-tick"].value

local function player_valid(player)
    if player and player.connected and player.controller_type == defines.controllers.character and player.ticks_to_respawn == nil then
        return true
    else
        return false
    end
end

local function logger(msg)
    if global.debug and #global.debug > 0 then
        for idx, flag in pairs(global.debug) do
            if flag then
                local player = game.get_player(idx)
                if player then
                    player.print(msg)
                    game.write_file("HandyHandsRefactored.txt", msg, true, idx)
                end
            end
        end
    end
end

local function dump_items_to_craft(player, items)
    if global.debug and #global.debug > 0 then
        for idx, flag in pairs(global.debug) do
            game.write_file("list_of_items_to_craft_" .. player.name .. ".json", game.table_to_json(items), false, idx)
        end
    end
end

function Smarts.dump_globals(event)
    if global.player_current_job and #global.player_current_job > 0 then
        local data = {}
        for idx, recipe in pairs(global.player_current_job) do
            data[idx] = recipe.name
        end
        game.write_file("player_current_job.json", serpent.block(data), false, event.player_index)
    end

    game.write_file("check_player.json", serpent.block(global.check_player), false, event.player_index)
    game.write_file("check_player_cancelled_crafting.json", serpent.block(global.check_player_cancelled_crafting), false, event.player_index)
end

local function cache_player_quick_bar_data(player)
    local items = {}
    local quick_bar_rows = player.mod_settings['hhr-quickbar-rows-to-read'].value
    local index = 1
    for row = 1, quick_bar_rows do
        for column = 1, 10 do
            local slot = player.get_quick_bar_slot(index)
            if slot then
                items[slot.name] = { target = slot.stack_size }
            end
            index = index + 1
        end
    end
    return items
end

---Toggle off from autocrafting
---@param player LuaPlayer?
local function disable_autocraft(player)
    if player and player.connected then
        global.check_player[player.index] = false
        global.player_current_job[player.index] = nil
        global.check_player_cancelled_crafting[player.index] = nil
        player.set_shortcut_toggled(Smarts.SHORTCUT_NAME, global.check_player[player.index])
    end
end

local function get_list_of_items_to_craft(player)
    local items = {}

    -- Check quickbar
    if player.mod_settings['hhr-autocraft-quickbar-slots'].value then
        local quickbar = global.cached_quickbar_slot_data[player.index] or cache_player_quick_bar_data(player)
        for k, v in pairs(quickbar) do
            items[k] = table.deepcopy(v)
        end
    end

    -- Check ammo
    if player.mod_settings['hhr-autocraft-ammo-slots'].value then
        local ammo_bar = player.get_inventory(defines.inventory.character_ammo)
        for ammo_name, ammo_count in pairs(ammo_bar.get_contents()) do
            local item = game.item_prototypes[ammo_name]
            items[ammo_name] = { current = ammo_count, target = item.stack_size }
        end

        if ammo_bar.is_filtered() then
            for i = 1, #ammo_bar do
                local ammo_name = ammo_bar.get_filter(i)
                if ammo_name then
                    local item = game.item_prototypes[ammo_name]
                    items[ammo_name] = { target = item.stack_size }
                end
            end
        end
    end

    -- Check logistics
    if player.mod_settings['hhr-autocraft-logistics-slots'].value then
        for i = 1, player.character.request_slot_count do
            local slot = player.get_personal_logistic_slot(i)
            if slot.min > 0 then
                items[slot.name] = { target = slot.min }
            end
        end
    end

    -- Check players hand contents
    local player_cursor = player.cursor_stack
    if player_cursor and player_cursor.valid and player_cursor.valid_for_read then
        if items[player_cursor.name] then
            if not (items[player_cursor.name].current) then items[player_cursor.name].current = 0 end
            items[player_cursor.name].current = items[player_cursor.name].current + player_cursor.count
            print("here")
        end
    end

    -- Check players hand for ghost
    local cursor_ghost = player.cursor_ghost
    if cursor_ghost and cursor_ghost.valid then
        if not (items[cursor_ghost.name]) then
            items[cursor_ghost.name] = { current = 0, target = 1 }
        end
    end


    -- local logi_network = player.surface.find_logistic_networks_by_construction_area(player.position, player.force)
    -- for _, network in pairs(logi_network) do
    --     for _, cell in pairs(network.cells) do

    if player.character.allow_dispatching_robots then
        local cell = player.character.logistic_cell
        if cell and cell.mobile and cell.transmitting and cell.owner and cell.owner.player == player then
            local x1 = cell.owner.position.x - cell.construction_radius + 1
            local y1 = cell.owner.position.y - cell.construction_radius + 1
            local x2 = cell.owner.position.x + cell.construction_radius - 1
            local y2 = cell.owner.position.y + cell.construction_radius - 1
            entities = cell.owner.surface.find_entities_filtered { area = { { x1, y1 }, { x2, y2 } }, name = "entity-ghost", type = "entity-ghost" }
            if entities ~= nil and #entities > 0 then
                for _, entity in pairs(entities) do
                    if not (items[entity.ghost_name]) then
                        items[entity.ghost_name] = { current = 0, target = 0 }
                    end
                    items[entity.ghost_name].target = items[entity.ghost_name].target + 1
                end
                for _, robot in pairs(player.character.logistic_network.construction_robots) do
                    local robot_inv = robot.get_inventory(defines.inventory.robot_cargo)
                    for item, data in pairs(items) do
                        if data.current then
                            data.current = data.current + robot_inv.get_item_count(item)
                        else
                            data.current = robot_inv.get_item_count(item)
                        end
                    end
                end
            end
        end
    end
    --     end
    -- end

    -- Process inventory
    local inv = player.get_main_inventory()
    for item, data in pairs(items) do
        if data.current then
            data.current = data.current + inv.get_item_count(item)
        else
            data.current = inv.get_item_count(item)
        end
        data.pct = (data.current * 100) / data.target
    end

    -- Create a list of dictionary items that we can sort on the % completed
    local list = {}
    for k, v in pairs(items) do
        if v.pct < 100 then
            v.name = k
            table.insert(list, v)
        end
    end

    table.sort(list, function(a, b) return a.pct < b.pct end)

    return list
end

---Check if the player should perform any work
---@param player LuaPlayer
local function check_player(player)
    logger(game.tick .. " " .. " check_player " .. player.name)
    if player.connected and player.controller_type == defines.controllers.character and player.ticks_to_respawn == nil then
        if global.check_player_cancelled_crafting[player.index] then
            if global.player_current_job[player.index] then
                local target = global.player_current_job[player.index]
                local found = false
                if player.crafting_queue and #player.crafting_queue > 0 then
                    for _, recipe in pairs(player.crafting_queue) do
                        if recipe.recipe == target.name then
                            found = true
                        end
                    end
                end
                if found then
                    global.check_player_cancelled_crafting[player.index] = nil
                else
                    disable_autocraft(player)
                end
            end
        else
            global.player_current_job[player.index] = nil
            local flag = true
            local items = get_list_of_items_to_craft(player)
            logger(game.tick .. " " .. " get_list_of_items_to_craft queue length = " .. #items)
            dump_items_to_craft(player, items)
            for _, item in pairs(items) do
                if flag then
                    local recipes = global.cached_recipes_by_product[item.name]
                    if recipes then
                        for _, recipe in pairs(recipes) do
                            local craftable_count = player.get_craftable_count(recipe.name)
                            if player.force.recipes[recipe.name].enabled and craftable_count > 0 then
                                local amount = 1
                                for _, product in pairs(recipe.products) do
                                    if product.name == item.name then
                                        amount = product.amount or 1
                                    end
                                end
                                craftable_count = craftable_count * amount
                                local max_craft = player.mod_settings['hhr-max-craft-at-a-time'].value * amount

                                if max_craft > 0 and craftable_count > max_craft then craftable_count = max_craft end

                                -- Make sure we dont over craft an item
                                if craftable_count > (item.target - item.current) then
                                    craftable_count = (item.target - item.current)
                                end

                                craftable_count = craftable_count / amount
                                if craftable_count < 1 then craftable_count = 1 end

                                logger(game.tick .. " " .. " begin_crafting " .. recipe.name .. " count=" .. tostring(craftable_count))
                                player.begin_crafting { count = craftable_count, recipe = recipe.name, silent = true }
                                global.player_current_job[player.index] = recipe
                                flag = false
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

---Parse online players to see if they have someting to do.
---@param event EventData.on_tick
function Smarts.on_nth_tick(event)
    local slot = math.floor(game.tick / Smarts.NTH_TICK)

    local enabled_players = {}
    for _, player in pairs(game.connected_players) do
        if player_valid(player) and global.check_player[player.index] and (player.crafting_queue_size == 0 or global.check_player_cancelled_crafting[player.index]) then
            table.insert(enabled_players, player)
        end
    end

    local count_enabled_players = #enabled_players
    if count_enabled_players > 0 then
        local selected_player = slot % count_enabled_players
        check_player(enabled_players[selected_player + 1]) -- need to add 1,  as the array starts from 1 not 0
    end
end

---Crafting was cancelled by player or script
---@param event EventData.on_player_cancelled_crafting
function Smarts.on_player_cancelled_crafting(event)
    global.check_player_cancelled_crafting[event.player_index] = true
end

function Smarts.on_pre_player_died(event)
    local player = game.get_player(event.player_index)
    disable_autocraft(player)
end

---Event trigged when shortcut key pressed
---@param event EventData.on_lua_shortcut
function Smarts.on_lua_shortcut(event)
    if event.prototype_name ~= Smarts.SHORTCUT_NAME then return end
    local player = game.get_player(event.player_index)
    if player then
        global.check_player[player.index] = not (player.is_shortcut_toggled(Smarts.SHORTCUT_NAME))

        global.player_current_job[player.index] = nil
        global.check_player_cancelled_crafting[player.index] = nil

        player.set_shortcut_toggled(Smarts.SHORTCUT_NAME, global.check_player[player.index])
    end
end

function Smarts.cache_recipes_by_product()
    local cache = {}
    for _, proto in pairs(game.get_filtered_recipe_prototypes({ { filter = "has-product-item" } })) do
        for _, product in ipairs(proto.products) do
            cache[product.name] = cache[product.name] or {}
            table.insert(cache[product.name], proto)
        end
    end
    return cache
end

---comment
---@param event EventData.on_player_set_quick_bar_slot
function Smarts.on_player_set_quick_bar_slot(event)
    local player = game.get_player(event.player_index)
    if player and player.mod_settings['hhr-autocraft-quickbar-slots'].value then
        global.cached_quickbar_slot_data[player.index] = cache_player_quick_bar_data(player)
    end
end

function Smarts.cache_quick_bar_data()
    local cache = global.cached_quickbar_slot_data or {}
    for _, player in pairs(game.players) do
        cache[player.index] = cache_player_quick_bar_data(player)
    end
    return cache
end

function Smarts.reset_globals(event)
    local player = game.get_player(event.player_index)
    if player and player.admin then
        global.player_current_job = {}
        global.check_player_cancelled_crafting = {}
    end
end

function Smarts.toggle_debug(event)
    local player = game.get_player(event.player_index)
    if player then
        global.debug[player.index] = global.debug[player.index] or false
        global.debug[player.index] = not (global.debug[player.index])
        player.print("HandyHands debugging : " .. tostring(global.debug[player.index]))
    end
end

return Smarts
