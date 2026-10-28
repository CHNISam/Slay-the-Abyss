-- Inspect the actual generated detail card, not cached notice or projected model text.
local Theme = require("abyss_theme")
return function(ui, panel)
    local info, text = panel:GetChild("statusInfo"), {}
    local opened = ui.info
    assert(info.visible and opened, "ordinary unit inspection must use the detail card")
    local pages = opened.pages
    assert(type(pages) == "number" and pages >= 1 and pages % 1 == 0, "detail page count must be valid")
    for page = 1, pages do
        assert(info.visible and ui.info == opened and opened.page == page and opened.pages == pages,
            "detail navigation must visit every page of the same actor")
        for i = 1, Theme.layout.statusInfo.rows do
            for _, field in ipairs({"name", "text", "note", "tag"}) do
                local part = info:GetChild(field .. i)
                if part.visible then text[#text + 1] = part.text end
            end
        end
        if page < pages then info:GetChild("page").click() end
    end
    info:GetChild("hit").click()
    assert(not info.visible and not ui.info, "blank space closes the detail card")
    return table.concat(text, " | ")
end
