require "util"
local Smarts = {}

Smarts.SHORTCUT_NAME = 'hhr-handyhands-toggle'
Smarts.NTH_TICK = settings.startup["hhr-nth-tick"].value

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
    -- game.print("check_player " .. " " .. game.tick .. " " .. player.name)
    if player.connected and player.controller_type == defines.controllers.character then
        local flag = true
        local items = get_list_of_items_to_craft(player)
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
                            player.begin_crafting { count = craftable_count, recipe = recipe.name, silent = true }
                            flag = false
                            break
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
    -- game.print("on_nth_tick .. " .. event.tick .. " slot .. " .. slot)

    local enabled_players = {}
    for _, player in pairs(game.connected_players) do
        if global.check_player[player.index] and player.crafting_queue_size == 0 then
            table.insert(enabled_players, player)
        end
    end

    local count_enabled_players = #enabled_players
    if count_enabled_players > 0 then
        local selected_player = slot % count_enabled_players
        check_player(enabled_players[selected_player + 1]) -- need to add 1,  as the array starts from 1 not 0
    end
end

function Smarts.on_player_cancelled_crafting(event)
    local player = game.get_player(event.player_index)
    disable_autocraft(player)
end

function Smarts.on_player_respawned(event)
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

-- ---comment
-- ---@param event EventData.on_player_ammo_inventory_changed
-- function Smarts.on_player_ammo_inventory_changed(event)
--     local player = game.get_player(event.player_index)
--     if player and player.mod_settings['hhr-autocraft-ammo-slots'].value then
--         global.cached_ammo_slot_data[player.index] = cache_player_ammo_slot_data(player)
--     end
-- end

-- function Smarts.cache_ammo_slot_data()
--     local cache = global.cached_ammo_slot_data or {}
--     for _, player in pairs(game.players) do
--         cache[player.index] = cache_player_ammo_slot_data(player)
--     end
--     return cache
-- end

return Smarts