std = "lua53"
-- Formatting is not a correctness gate; retain all semantic diagnostics.
max_line_length = false
files["src/lua/abyss_ui.lua"] = {
    globals = {"OnStart", "OnUpdate"},
    read_globals = {"game", "script", "Color", "Enum"}
}
files["src/lua/abyss_map_ui.lua"] = {read_globals = {"Color", "Enum"}}
files["src/lua/abyss_node_ui.lua"] = {read_globals = {"Enum"}}
