project = "LuaTwit"
title = "LuaTwit reference"
description = "LuaTwit library 0.3"
backtick_references = true
file = "src"
examples = { "examples", exclude = { "examples/_config.lua" } }
format = "markdown"
plain = true
readme = "README.md"
custom_tags = { { 'constructor', hidden = true } }

custom_display_name_handler = function(item, default_handler)
    if item.type == 'function' and item.tags.constructor then
        item.display_name = item.name:gsub("_init$", "new")
    end
    return default_handler(item)
end
