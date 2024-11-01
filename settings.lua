data:extend({
    {
        type = "int-setting",
        name = "hhr-nth-tick",
        setting_type = "startup",
        default_value = 60,
        minimum_value = 20,
        maximum_value = 600,
        order = "300"
    },
    {
        type = "int-setting",
        name = "hhr-quickbar-rows-to-read",
        setting_type = "runtime-per-user",
        default_value = 2,
        minimum_value = 0,
        maximum_value = 10,
        order = "300"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-quickbar-slots",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "103"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-logistics-slots",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "102"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-ammo-slots",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "101"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-ghosts",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "111"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-upgrades",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "112"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-tiles",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "113"
    },
    {
        type = "bool-setting",
        name = "hhr-autocraft-requests",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "114"
    },
    {
        type = "int-setting",
        name = "hhr-max-craft-at-a-time",
        setting_type = "runtime-per-user",
        default_value = 5,
        minimum_value = -1,
        maximum_value = 100,
        order = "200"
    },
    {
        type = "string-setting",
        name = "hhr-logistics-group",
        setting_type = "runtime-per-user",
        allow_blank = true,
        default_value = "",
        order = "400"
    },
    {
        type = "bool-setting",
        name = "hhr-debug-output",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "999"
    },
})
