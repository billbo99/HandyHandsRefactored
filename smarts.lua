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
    if storage.debug and #storage.debug > 0 then
        for idx, flag in pairs(storage.debug) do
            if flag then
                local player = game.get_player(idx)
                if player then
                    player.print(msg)
                    helpers.write_file("HandyHandsRefactored.txt", msg, true, idx)
                end
            end
        end
    end
end

local function dump_items_to_craft(player, items)
    if storage.debug and #storage.debug > 0 then
        for idx, flag in pairs(storage.debug) do
            helpers.write_file("list_of_items_to_craft_" .. player.name .. ".json", helpers.table_to_json(items), false, idx)
        end
    end
end

function Smarts.dump_globals(event)
    if storage.player_current_job and #storage.player_current_job > 0 then
        local data = {}
        for idx, recipe in pairs(storage.player_current_job) do
            data[idx] = recipe.name
        end
        helpers.write_file("player_current_job.json", serpent.block(data), false, event.player_index)
    end

    helpers.write_file("check_player.json", serpent.block(storage.check_player), false, event.player_index)
    helpers.write_file("check_player_cancelled_crafting.json", serpent.block(storage.check_player_cancelled_crafting), false, event.player_index)
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
        storage.check_player[player.index] = false
        storage.player_current_job[player.index] = nil
        storage.check_player_cancelled_crafting[player.index] = nil
        player.set_shortcut_toggled(Smarts.SHORTCUT_NAME, storage.check_player[player.index])
    end
end

local function get_list_of_items_to_craft(player)
    local items = {}

    local function update_item(item, count, quality)
        local name
        if quality then
            name = item
        else
            name = item
        end
        if not (items[name]) then
            items[name] = { current = 0, target = 0 }
        end
        items[name].target = items[name].target + count
    end

    -- Check current crafting queue
    if player.crafting_queue and #player.crafting_queue > 0 then
        for _, recipe in pairs(player.crafting_queue) do
            player.print(recipe)
        end
    end


    -- Check quickbar
    if player.mod_settings['hhr-autocraft-quickbar-slots'].value then
        local quickbar = storage.cached_quickbar_slot_data[player.index] or cache_player_quick_bar_data(player)
        for k, v in pairs(quickbar) do
            items[k] = table.deepcopy(v)
        end
    end

    -- Check ammo
    if player.mod_settings['hhr-autocraft-ammo-slots'].value then
        local ammo_bar = player.get_inventory(defines.inventory.character_ammo)
        for _, _dict in pairs(ammo_bar.get_contents()) do
            local item = prototypes.item[_dict.name]
            local _key = _dict.name
            items[_key] = { current = _dict.count, target = item.stack_size }
        end

        if ammo_bar.is_filtered() then
            for i = 1, #ammo_bar do
                local ammo_name = ammo_bar.get_filter(i)
                if ammo_name then
                    local item = prototypes.item[ammo_name]
                    items[ammo_name] = { target = item.stack_size }
                end
            end
        end
    end

    -- Check logistics
    if player.mod_settings['hhr-autocraft-logistics-slots'].value then
        if player.character.get_requester_point() and player.character.get_requester_point().enabled and player.character.get_requester_point().filters then
            for _, slot in pairs(player.character.get_requester_point().filters) do
                if slot.count > 0 then
                    items[slot.name] = { target = slot.count }
                end
            end
        end
    end

    -- Check players hand contents
    local player_cursor = player.cursor_stack
    if player_cursor and player_cursor.valid and player_cursor.valid_for_read then
        if items[player_cursor.name] then
            if not (items[player_cursor.name].current) then items[player_cursor.name].current = 0 end
            items[player_cursor.name].current = items[player_cursor.name].current + player_cursor.count
        end
    end

    -- Check players hand for ghost
    local cursor_ghost = player.cursor_ghost
    if cursor_ghost and cursor_ghost.valid then
        if not (items[cursor_ghost.name]) then
            items[cursor_ghost.name] = { current = 0, target = 1 }
        end
    end

    if player.character.allow_dispatching_robots then
        local cell = player.character.logistic_cell
        if cell and cell.mobile and cell.transmitting and cell.owner and cell.owner.player == player then
            local x1 = cell.owner.position.x - cell.construction_radius + 1
            local y1 = cell.owner.position.y - cell.construction_radius + 1
            local x2 = cell.owner.position.x + cell.construction_radius - 1
            local y2 = cell.owner.position.y + cell.construction_radius - 1

            if player.mod_settings['hhr-autocraft-ghosts'].value then
                -- Find what is needed to place a ghost entity
                local ghost_entities = cell.owner.surface.find_entities_filtered { area = { { x1, y1 }, { x2, y2 } }, name = "entity-ghost", type = "entity-ghost" }
                if ghost_entities ~= nil and #ghost_entities > 0 then
                    for _, entity in pairs(ghost_entities) do
                        if entity.ghost_prototype.items_to_place_this then
                            for _, v in pairs(entity.ghost_prototype.items_to_place_this) do
                                update_item(v.name, v.count)
                            end
                        end
                    end
                end
            end

            if player.mod_settings['hhr-autocraft-upgrades'].value then
                -- Find what is needed to be upgraded
                local upgrade_entities = cell.owner.surface.find_entities_filtered { area = { { x1, y1 }, { x2, y2 } }, to_be_upgraded = true }
                if upgrade_entities ~= nil and #upgrade_entities > 0 then
                    for _, entity in pairs(upgrade_entities) do
                        local upgrade = entity.get_upgrade_target()
                        if upgrade ~= nil then
                            update_item(upgrade.name, 1)
                        end
                    end
                end
            end

            if player.mod_settings['hhr-autocraft-tiles'].value then
                -- Find what ghost tiles need to be crafted
                local tile_entities = cell.owner.surface.find_entities_filtered { area = { { x1, y1 }, { x2, y2 } }, name = "tile-ghost", type = "tile-ghost" }
                if tile_entities ~= nil and #tile_entities > 0 then
                    for _, entity in pairs(tile_entities) do
                        if entity.ghost_prototype.items_to_place_this then
                            for _, v in pairs(entity.ghost_prototype.items_to_place_this) do
                                update_item(v.name, v.count)
                            end
                        end
                    end
                end
            end

            if player.mod_settings['hhr-autocraft-requests'].value then
                -- Look for any outstanding proxy requests
                item_requests = cell.owner.surface.find_entities_filtered { area = { { x1, y1 }, { x2, y2 } }, name = "item-request-proxy" }
                if item_requests ~= nil and #item_requests > 0 then
                    for _, entity in pairs(item_requests) do
                        local requests = entity.item_requests
                        if requests ~= nil then
                            for idx, row in pairs(requests) do
                                update_item(row.name, row.count, row.quality)
                            end
                        end
                    end
                end
            end

            -- Clean up requests based on items needed to place entities
            for item, data in pairs(items) do
                local entity_prototype = prototypes.entity[item]
                if entity_prototype then
                    if entity_prototype.items_to_place_this then
                        for _, v in pairs(entity_prototype.items_to_place_this) do
                            update_item(v.name, 0)
                            if v.name ~= item then
                                items[item] = nil
                            end
                        end
                    end
                end
            end

            -- check robots inventory for items they are holding
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
        if storage.check_player_cancelled_crafting[player.index] then
            if storage.player_current_job[player.index] then
                local target = storage.player_current_job[player.index]
                local found = false
                if player.crafting_queue and #player.crafting_queue > 0 then
                    for _, recipe in pairs(player.crafting_queue) do
                        if recipe.recipe == target.name then
                            found = true
                        end
                    end
                end
                if found then
                    storage.check_player_cancelled_crafting[player.index] = nil
                else
                    disable_autocraft(player)
                end
            else
                storage.check_player_cancelled_crafting[player.index] = nil
            end
        else
            storage.player_current_job[player.index] = nil
            local flag = true
            local items = get_list_of_items_to_craft(player)
            logger(game.tick .. " " .. " get_list_of_items_to_craft queue length = " .. #items)
            dump_items_to_craft(player, items)
            for _, item in pairs(items) do
                if flag then
                    local recipes = storage.cached_recipes_by_product[item.name]
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
                                storage.player_current_job[player.index] = recipe
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
        if player_valid(player) and storage.check_player[player.index] and (player.crafting_queue_size == 0 or storage.check_player_cancelled_crafting[player.index]) then
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
    storage.check_player_cancelled_crafting[event.player_index] = true
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
        storage.check_player[player.index] = not (player.is_shortcut_toggled(Smarts.SHORTCUT_NAME))

        storage.player_current_job[player.index] = nil
        storage.check_player_cancelled_crafting[player.index] = nil

        player.set_shortcut_toggled(Smarts.SHORTCUT_NAME, storage.check_player[player.index])
    end
end

function Smarts.cache_recipes_by_product()
    local cache = {}
    for _, proto in pairs(prototypes.get_recipe_filtered({ { filter = "has-product-item" } })) do
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
        storage.cached_quickbar_slot_data[player.index] = cache_player_quick_bar_data(player)
    end
end

function Smarts.cache_quick_bar_data()
    local cache = storage.cached_quickbar_slot_data or {}
    for _, player in pairs(game.players) do
        cache[player.index] = cache_player_quick_bar_data(player)
    end
    return cache
end

function Smarts.reset_globals(event)
    local player = game.get_player(event.player_index)
    if player and player.admin then
        storage.player_current_job = {}
        storage.check_player_cancelled_crafting = {}
    end
end

function Smarts.toggle_debug(event)
    local player = game.get_player(event.player_index)
    if player then
        storage.debug[player.index] = storage.debug[player.index] or false
        storage.debug[player.index] = not (storage.debug[player.index])
        player.print("HandyHands debugging : " .. tostring(storage.debug[player.index]))
    end
end

return Smarts
