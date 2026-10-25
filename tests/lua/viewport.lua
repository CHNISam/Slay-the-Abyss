local Viewport = require("abyss_viewport")
local Layout = require("abyss_ui_layout")
local backdropSpec, stageSpec
for _, spec in ipairs(Layout) do
    if spec.name == "canvasBackdrop" then backdropSpec = spec end
    if spec.name == "stage" then stageSpec = spec end
end
assert(backdropSpec and stageSpec)
local stage = {}
function stage:SetLocalScale(x, y, z) self.scale = {x, y, z} end
local backdrop = { delta = {backdropSpec.size[1], backdropSpec.size[2]} }
function backdrop:SetSizeDelta(w, h) self.delta = {w, h} end
local root = {}
function root:GetChild(name)
    if name == "stage" then return stage end
    if name == "canvasBackdrop" then return backdrop end
end
local cases = {
    -- Canvas API and actual host need not have the same width.
    {1280, 720, 2556, 1179}, {1280, 720, 2268, 1179},
    {1920, 1080, 1920, 1080}, {2340, 1080, 2340, 1080},
    {2400, 1080, 2400, 1080}, {2520, 1080, 2520, 1080},
    {2048, 1536, 2048, 1536}, {2732, 2048, 2732, 2048},
    {1280, 720, 1280, 720},
}
for _, device in ipairs(cases) do
    -- Repeat after portrait/tablet/wide-screen changes: no accumulated enlargement.
    for _ = 1, 3 do
        local returned, scale = Viewport.apply(root, device[1], device[2])
        local expected = math.min(device[1] / 1280, device[2] / 720)
        assert(returned == stage and scale == expected)
        assert(stage.scale[1] == expected and stage.scale[2] == expected and stage.scale[3] == 1)
        for axis = 1, 2 do
            local low = backdropSpec.anchor and backdropSpec.anchor.min[axis] or 0.5
            local high = backdropSpec.anchor and backdropSpec.anchor.max[axis] or 0.5
            local extent = device[axis + 2]
            local actual = extent * (high - low) + backdrop.delta[axis]
            assert(actual == extent, "background misses native host or adds canvas size twice")
        end
        assert(stageSpec.size[1] * scale <= device[1] + 1e-9)
        assert(stageSpec.size[2] * scale <= device[2] + 1e-9)
    end
end
for _, bad in ipairs({0, -1, math.huge, 0/0, "1280"}) do
    assert(not pcall(Viewport.apply, root, bad, 720))
    assert(not pcall(Viewport.apply, root, 1280, bad))
end
print("PASS viewport: independent host coverage, uniform content and repeated resize (9 devices)")
