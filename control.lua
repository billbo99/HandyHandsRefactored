local Smarts = require("smarts")

local function init_globals()
    global.cached_recipes_by_product = Smarts.cache_recipes_by_product()
    global.cached_quickbar_slot_data = Smarts.cache_quick_bar_data()
    global.check_player = global.check_player or {} -- Boolean tracking of who has the mod enabled
end

local function on_init()
    init_globals()
end

local function on_load()
end

local function on_configuration_changed(e)
    init_globals()
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)

script.on_nth_tick(Smarts.NTH_TICK, Smarts.on_nth_tick)
script.on_event(defines.events.on_player_cancelled_crafting, Smarts.on_player_cancelled_crafting)

script.on_event(defines.events.on_player_set_quick_bar_slot, Smarts.on_player_set_quick_bar_slot)
-- script.on_event(defines.events.on_player_ammo_inventory_changed, Smarts.on_player_ammo_inventory_changed)

script.on_event(defines.events.on_lua_shortcut, Smarts.on_lua_shortcut)
