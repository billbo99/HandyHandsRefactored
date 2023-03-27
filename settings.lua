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
        order = "110"
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
        type = "int-setting",
        name = "hhr-max-craft-at-a-time",
        setting_type = "runtime-per-user",
        default_value = 5,
        minimum_value = -1,
        maximum_value = 100,
        order = "200"
    },
    -- {
    --     type = "bool-setting",
    --     name = "hhr-handyhands-autocraft-multi-product-recipes",
    --     setting_type = "runtime-per-user",
    --     default_value = false
    -- },
    -- {
    --     type = "string-setting",
    --     name = "hhr-logistics-requests-are-autocraft-requests",
    --     setting_type = "runtime-per-user",
    --     default_value = 'When personal logistics requests are enabled',
    --     allowed_values = { 'Never', 'When personal logistics requests are enabled', 'Always' },
    -- }
})
