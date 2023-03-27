data:extend({
    {
        type = "sound",
        name = "handyhands-core-crafting_finished",
        filename = "__core__/sound/crafting-finished.ogg",
        volume = 1
    },
    {
        type = "shortcut",
        name = "hhr-handyhands-toggle",
        action = "lua",
        toggleable = true,
        icon = {
            filename = "__HandyHandsRefactored__/graphics/icon/shortcut-toggle.png",
            priority = "extra-high-no-scale",
            size = 144,
            scale = 0.2,
            flags = { "icon" }
        },
    },
})
