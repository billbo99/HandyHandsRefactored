local Smarts = require("smarts")

local function init_globals()
    storage.debug = storage.debug or {}
    storage.cached_recipes_by_product = Smarts.cache_recipes_by_product()
    storage.cached_quickbar_slot_data = Smarts.cache_quick_bar_data()

    -- Current recipe a player is crafting
    storage.player_current_job = storage.player_current_job or {}

    -- Boolean tracking of who has the mod enabled
    storage.check_player = storage.check_player or {}

    -- Boolean tracking of who might have cancelled some crafting
    storage.check_player_cancelled_crafting = storage.check_player_cancelled_crafting or {}
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
script.on_event(defines.events.on_pre_player_died, Smarts.on_pre_player_died)

script.on_event(defines.events.on_player_set_quick_bar_slot, Smarts.on_player_set_quick_bar_slot)
script.on_event(defines.events.on_lua_shortcut, Smarts.on_lua_shortcut)

commands.add_command("HandyHandsToggleDebug", nil, Smarts.toggle_debug)
commands.add_command("HandyHandsToggleReset", nil, Smarts.reset_globals)
commands.add_command("HandyHandsToggleDumpGlobals", nil, Smarts.dump_globals)
