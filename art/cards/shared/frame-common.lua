-- Abyss_Shared_frame-common：图片与文本 Lua 绘制脚本
-- 挂到专用空客户端容器，OnStart 绘制；模板设为仅存为模板。
local IMAGE_PREFAB_ID = 0 -- 图片控件模板索引ID；无图片且未启用蒙版/羽化时无需填写
local TEXTBOX_PREFAB_ID = 0 -- 必填：文本框控件模板索引ID
-- 字号自适应由每个文本框的 autoSize 显式设置，默认开启；minFontSize 为最小字号。
local BASE_SCALE = 1
local OFFSET_X = 0
local OFFSET_Y = 0
local ROOT = {0,0,180.0,240.0,0.5,0.5,0.5,0.5,0.5,0.5,1,1,0}
local ELEMENTS = {
    {100001,0.0,0.0,148.0,208.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,95,143,214,255},
    {100001,0.0,0.0,144.0,204.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,28,30,39,255},
    {100001,0.0,87.0,144.0,30.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,39,42,54,255},
    {100001,0.0,40.0,144.0,64.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,28,30,39,255},
    {100001,0.0,-1.0,144.0,18.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,19,20,27,255},
    {100002,-64.0,94.0,46.0,46.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,245,215,154,255},
    {100002,-64.0,94.0,44.0,44.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,15,17,23,255},
    {100002,-64.0,94.0,40.0,40.0,0.5,0.5,0.5,0.5,0.5,0.5,1.0,1.0,0,233,169,59,255},
}
-- 文本框数据：位置使用编辑器画布坐标，textBox 保存完整文字与样式。
local TEXTBOXES = {
    {["name"]="card-title",["x"]=90.0,["y"]=33.0,["width"]=148.0,["height"]=40.0,["rotation"]=0.0,["textBox"]={["text"]="",["fontSize"]=17,["autoSize"]=true,["minFontSize"]=14,["textColor"]="#ece6da",["textOpacity"]=1.0,["bgColor"]="#ffffff",["bgOpacity"]=0.0,["outlineEnabled"]=false,["outlineColor"]="#333333",["outlineOpacity"]=0.2,["alignH"]="center",["alignV"]="middle",["anchorType"]="center",["visible"]=true,["scaleX"]=1.0,["scaleY"]=1.0,["anchorMinX"]=0.5,["anchorMinY"]=0.5,["anchorMaxX"]=0.5,["anchorMaxY"]=0.5,["pivotX"]=0.5,["pivotY"]=0.5}},
    {["name"]="card-type",["x"]=90.0,["y"]=121.0,["width"]=144.0,["height"]=40.0,["rotation"]=0.0,["textBox"]={["text"]="",["fontSize"]=14,["autoSize"]=true,["minFontSize"]=14,["textColor"]="#a9a595",["textOpacity"]=1.0,["bgColor"]="#ffffff",["bgOpacity"]=0.0,["outlineEnabled"]=false,["outlineColor"]="#333333",["outlineOpacity"]=0.2,["alignH"]="center",["alignV"]="middle",["anchorType"]="center",["visible"]=true,["scaleX"]=1.0,["scaleY"]=1.0,["anchorMinX"]=0.5,["anchorMinY"]=0.5,["anchorMaxX"]=0.5,["anchorMaxY"]=0.5,["pivotX"]=0.5,["pivotY"]=0.5}},
    {["name"]="card-description",["x"]=90.0,["y"]=174.0,["width"]=132.0,["height"]=92.0,["rotation"]=0.0,["textBox"]={["text"]="",["fontSize"]=15,["autoSize"]=true,["minFontSize"]=14,["textColor"]="#ece6da",["textOpacity"]=1.0,["bgColor"]="#ffffff",["bgOpacity"]=0.0,["outlineEnabled"]=false,["outlineColor"]="#333333",["outlineOpacity"]=0.2,["alignH"]="center",["alignV"]="middle",["anchorType"]="center",["visible"]=true,["scaleX"]=1.0,["scaleY"]=1.0,["anchorMinX"]=0.5,["anchorMinY"]=0.5,["anchorMaxX"]=0.5,["anchorMaxY"]=0.5,["pivotX"]=0.5,["pivotY"]=0.5}},
    {["name"]="card-cost",["x"]=26.0,["y"]=26.0,["width"]=40.0,["height"]=40.0,["rotation"]=0.0,["textBox"]={["text"]="",["fontSize"]=22,["autoSize"]=true,["minFontSize"]=14,["textColor"]="#2a2620",["textOpacity"]=1.0,["bgColor"]="#ffffff",["bgOpacity"]=0.0,["outlineEnabled"]=false,["outlineColor"]="#333333",["outlineOpacity"]=0.2,["alignH"]="center",["alignV"]="middle",["anchorType"]="center",["visible"]=true,["scaleX"]=1.0,["scaleY"]=1.0,["anchorMinX"]=0.5,["anchorMinY"]=0.5,["anchorMaxX"]=0.5,["anchorMaxY"]=0.5,["pivotX"]=0.5,["pivotY"]=0.5}},
}
-- {1,图片序号} / {2,文本框序号}，从背景到前景绘制。
local DRAW_ORDER = {
    {1,1},
    {1,2},
    {1,3},
    {1,4},
    {1,5},
    {2,1},
    {2,2},
    {2,3},
    {1,6},
    {1,7},
    {1,8},
    {2,4},
}
local ALIGN_H = {left=Enum.TextHorizontalAlignment.Left, center=Enum.TextHorizontalAlignment.Middle, right=Enum.TextHorizontalAlignment.Right}
local ALIGN_V = {top=Enum.TextVerticalAlignment.Top, middle=Enum.TextVerticalAlignment.Middle, bottom=Enum.TextVerticalAlignment.Bottom}
local function TextColor(hex, opacity)
    return Color.FromRGBA(tonumber(string.sub(hex, 2, 3), 16), tonumber(string.sub(hex, 4, 5), 16), tonumber(string.sub(hex, 6, 7), 16), math.floor(opacity * 255))
end

local created = {}
local function Clear()
    for i = #created, 1, -1 do
        game.DestroyClientUIControl(created[i])
    end
    created = {}
end

function OnStart()
    Clear()
    if #ELEMENTS > 0 and (type(IMAGE_PREFAB_ID) ~= "number" or IMAGE_PREFAB_ID <= 0 or IMAGE_PREFAB_ID % 1 ~= 0) then
        printerr("[图片绘制] 请填写 IMAGE_PREFAB_ID：客户端图片控件模板索引ID")
        return
    end
    if type(TEXTBOX_PREFAB_ID) ~= "number" or TEXTBOX_PREFAB_ID <= 0 or TEXTBOX_PREFAB_ID % 1 ~= 0 then
        printerr("[图片绘制] 请填写 TEXTBOX_PREFAB_ID：客户端文本框控件模板索引ID")
        return
    end
    local parent = script.object
    if parent == nil then return end
    parent:SetAnchorMin(0.5, 0.5)
    parent:SetAnchorMax(0.5, 0.5)
    parent:SetPivot(ROOT[5], ROOT[6])
    parent:SetSizeDelta(ROOT[3], ROOT[4])
    parent:SetLocalScale(ROOT[11] * BASE_SCALE, ROOT[12] * BASE_SCALE, 1)
    parent:SetLocalRotation(0, 0, ROOT[13])
    parent:SetAnchoredPosition(OFFSET_X, OFFSET_Y)
    local ok, err = pcall(function()
        for _, entry in ipairs(DRAW_ORDER) do
            local index = entry[2]
            if entry[1] == 2 then
                local item = TEXTBOXES[index]
                local box = item.textBox
                local text = game.InstantiateClientUIControl(TEXTBOX_PREFAB_ID, parent)
                if text == nil then error("文本框模板无法实例化，请确认已设为仅存为模板") end
                table.insert(created, text)
                text.name = item.name
                text:SetAnchorMin(box.anchorMinX, box.anchorMinY)
                text:SetAnchorMax(box.anchorMaxX, box.anchorMaxY)
                text:SetPivot(box.pivotX, box.pivotY)
                text:SetSizeDelta(item.width, item.height)
                text:SetLocalScale(box.scaleX, box.scaleY, 1)
                text:SetLocalRotation(item.rotationX or 0, item.rotationY or 0, item.rotation)
                text:SetAnchoredPosition(item.x - ROOT[3] / 2, ROOT[4] / 2 - item.y)
                text.fontSize = box.fontSize
                text.minimumFontSize = box.minFontSize
                text.adaptiveFontSize = box.autoSize
                text.fontColor = TextColor(box.textColor, box.textOpacity)
                text.bgColor = TextColor(box.bgColor, box.bgOpacity)
                text.enableOutline = box.outlineEnabled
                text.outlineColor = TextColor(box.outlineColor, box.outlineOpacity)
                text.horizontalAlignment = ALIGN_H[box.alignH]
                text.verticalAlignment = ALIGN_V[box.alignV]
                text.text = box.text
                text:SetActive(true)
                text:SetVisible(box.visible)
                text:SetAsLastSibling()
            else
                local item = ELEMENTS[index]
                local image = game.InstantiateClientUIControl(IMAGE_PREFAB_ID, parent)
                if image == nil then error("图片模板无法实例化，请确认已设为仅存为模板") end
                table.insert(created, image)
                image:SetImage(Enum.ImageSource.StaticReference, item[1])
                -- imageType 仅部分图片支持，保留不支持该属性的静态图片。
                pcall(function() image.imageType = Enum.ImageType.Stretch end)
                image:SetAnchorMin(item[8], item[9])
                image:SetAnchorMax(item[10], item[11])
                image:SetPivot(item[6], item[7])
                image:SetSizeDelta(item[4], item[5])
                image:SetLocalScale(item[12], item[13], 1)
                image:SetLocalRotation(0, 0, item[14])
                image:SetAnchoredPosition(item[2], item[3])
                image.imageColor = Color.FromRGBA(item[15], item[16], item[17], item[18])
                image:SetAsLastSibling()
            end
        end
    end)
    if not ok then
        Clear()
        printerr("[图片绘制] " .. tostring(err))
    end
end

function OnDestroy()
    Clear()
end

-- 编辑器回导数据：保留图元名称、文本框与素材库，请勿删除。
-- MILIASTRA_EDITOR_SCENE_V1 eyJ2ZXJzaW9uIjoxLCJkcmF3aW5nSGFzaCI6IjAzYmZmMjM1ZWVkNzQwMTUwN2Q4OTRiZGQwZWNlMmY2Y2M0MmM3N2E1ZDc5MjUzODBkOTFhNzNiYjBkY2Q4NzkiLCJzY2VuZSI6eyJjYW52YXMiOnsid2lkdGgiOjE4MC4wLCJoZWlnaHQiOjI0MC4wLCJiYWNrZ3JvdW5kIjoidHJhbnNwYXJlbnQiLCJtYXNrIjp7IngiOjAuMCwieSI6MC4wLCJ3aWR0aCI6bnVsbCwiaGVpZ2h0IjpudWxsLCJzaGFwZVR5cGUiOjEsImVuYWJsZWQiOmZhbHNlLCJwcmV2aWV3T25DYW52YXMiOmZhbHNlfX0sImVsZW1lbnRzIjpbeyJpZCI6InJhcml0eS1mcmFtZSIsIm5hbWUiOiJyYXJpdHktZnJhbWUiLCJ0eXBlIjoicmVjdGFuZ2xlIiwieCI6OTAuMCwieSI6MTIwLjAsIndpZHRoIjoxNDguMCwiaGVpZ2h0IjoyMDguMCwicm90YXRpb24iOjAuMCwicm90YXRpb25YIjowLjAsInJvdGF0aW9uWSI6MC4wLCJjb2xvciI6IiM1ZjhmZDYiLCJvcGFjaXR5IjoxLjAsInpJbmRleCI6MCwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6bnVsbCwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNhcmQtcGFuZWwiLCJuYW1lIjoiY2FyZC1wYW5lbCIsInR5cGUiOiJyZWN0YW5nbGUiLCJ4Ijo5MC4wLCJ5IjoxMjAuMCwid2lkdGgiOjE0NC4wLCJoZWlnaHQiOjIwNC4wLCJyb3RhdGlvbiI6MC4wLCJyb3RhdGlvblgiOjAuMCwicm90YXRpb25ZIjowLjAsImNvbG9yIjoiIzFjMWUyNyIsIm9wYWNpdHkiOjEuMCwiekluZGV4IjoxLCJpc0JhY2tncm91bmQiOmZhbHNlLCJ0ZXh0Qm94IjpudWxsLCJpbWFnZUFzc2V0SWQiOm51bGwsImltYWdlVGludCI6ZmFsc2UsImltYWdlVHlwZSI6ImJhc2ljIiwicHJlZmFiSWQiOm51bGwsInByZWZhYlZhcmlhYmxlIjpudWxsLCJsdWFNYXNrIjpudWxsfSx7ImlkIjoibmFtZS1iYW5kIiwibmFtZSI6Im5hbWUtYmFuZCIsInR5cGUiOiJyZWN0YW5nbGUiLCJ4Ijo5MC4wLCJ5IjozMy4wLCJ3aWR0aCI6MTQ0LjAsImhlaWdodCI6MzAuMCwicm90YXRpb24iOjAuMCwicm90YXRpb25YIjowLjAsInJvdGF0aW9uWSI6MC4wLCJjb2xvciI6IiMyNzJhMzYiLCJvcGFjaXR5IjoxLjAsInpJbmRleCI6MiwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6bnVsbCwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImFydC1wYW5lbCIsIm5hbWUiOiJhcnQtcGFuZWwiLCJ0eXBlIjoicmVjdGFuZ2xlIiwieCI6OTAuMCwieSI6ODAuMCwid2lkdGgiOjE0NC4wLCJoZWlnaHQiOjY0LjAsInJvdGF0aW9uIjowLjAsInJvdGF0aW9uWCI6MC4wLCJyb3RhdGlvblkiOjAuMCwiY29sb3IiOiIjMWMxZTI3Iiwib3BhY2l0eSI6MS4wLCJ6SW5kZXgiOjMsImlzQmFja2dyb3VuZCI6ZmFsc2UsInRleHRCb3giOm51bGwsImltYWdlQXNzZXRJZCI6bnVsbCwiaW1hZ2VUaW50IjpmYWxzZSwiaW1hZ2VUeXBlIjoiYmFzaWMiLCJwcmVmYWJJZCI6bnVsbCwicHJlZmFiVmFyaWFibGUiOm51bGwsImx1YU1hc2siOm51bGx9LHsiaWQiOiJ0eXBlLWJhbmQiLCJuYW1lIjoidHlwZS1iYW5kIiwidHlwZSI6InJlY3RhbmdsZSIsIngiOjkwLjAsInkiOjEyMS4wLCJ3aWR0aCI6MTQ0LjAsImhlaWdodCI6MTguMCwicm90YXRpb24iOjAuMCwicm90YXRpb25YIjowLjAsInJvdGF0aW9uWSI6MC4wLCJjb2xvciI6IiMxMzE0MWIiLCJvcGFjaXR5IjoxLjAsInpJbmRleCI6NCwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6bnVsbCwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNhcmQtdGl0bGUiLCJuYW1lIjoiY2FyZC10aXRsZSIsInR5cGUiOiJ0ZXh0Ym94IiwieCI6OTAuMCwieSI6MzMuMCwid2lkdGgiOjE0OC4wLCJoZWlnaHQiOjQwLjAsInJvdGF0aW9uIjowLjAsInJvdGF0aW9uWCI6MC4wLCJyb3RhdGlvblkiOjAuMCwiY29sb3IiOiIjZWNlNmRhIiwib3BhY2l0eSI6MS4wLCJ6SW5kZXgiOjUsImlzQmFja2dyb3VuZCI6ZmFsc2UsInRleHRCb3giOnsidGV4dCI6IiIsImZvbnRTaXplIjoxNywiYXV0b1NpemUiOnRydWUsIm1pbkZvbnRTaXplIjoxNCwidGV4dENvbG9yIjoiI2VjZTZkYSIsInRleHRPcGFjaXR5IjoxLjAsImJnQ29sb3IiOiIjZmZmZmZmIiwiYmdPcGFjaXR5IjowLjAsIm91dGxpbmVFbmFibGVkIjpmYWxzZSwib3V0bGluZUNvbG9yIjoiIzMzMzMzMyIsIm91dGxpbmVPcGFjaXR5IjowLjIsImFsaWduSCI6ImNlbnRlciIsImFsaWduViI6Im1pZGRsZSIsImFuY2hvclR5cGUiOiJjZW50ZXIiLCJ2aXNpYmxlIjp0cnVlLCJzY2FsZVgiOjEuMCwic2NhbGVZIjoxLjAsImFuY2hvck1pblgiOjAuNSwiYW5jaG9yTWluWSI6MC41LCJhbmNob3JNYXhYIjowLjUsImFuY2hvck1heFkiOjAuNSwicGl2b3RYIjowLjUsInBpdm90WSI6MC41fSwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNhcmQtdHlwZSIsIm5hbWUiOiJjYXJkLXR5cGUiLCJ0eXBlIjoidGV4dGJveCIsIngiOjkwLjAsInkiOjEyMS4wLCJ3aWR0aCI6MTQ0LjAsImhlaWdodCI6NDAuMCwicm90YXRpb24iOjAuMCwicm90YXRpb25YIjowLjAsInJvdGF0aW9uWSI6MC4wLCJjb2xvciI6IiNhOWE1OTUiLCJvcGFjaXR5IjoxLjAsInpJbmRleCI6NiwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6eyJ0ZXh0IjoiIiwiZm9udFNpemUiOjE0LCJhdXRvU2l6ZSI6dHJ1ZSwibWluRm9udFNpemUiOjE0LCJ0ZXh0Q29sb3IiOiIjYTlhNTk1IiwidGV4dE9wYWNpdHkiOjEuMCwiYmdDb2xvciI6IiNmZmZmZmYiLCJiZ09wYWNpdHkiOjAuMCwib3V0bGluZUVuYWJsZWQiOmZhbHNlLCJvdXRsaW5lQ29sb3IiOiIjMzMzMzMzIiwib3V0bGluZU9wYWNpdHkiOjAuMiwiYWxpZ25IIjoiY2VudGVyIiwiYWxpZ25WIjoibWlkZGxlIiwiYW5jaG9yVHlwZSI6ImNlbnRlciIsInZpc2libGUiOnRydWUsInNjYWxlWCI6MS4wLCJzY2FsZVkiOjEuMCwiYW5jaG9yTWluWCI6MC41LCJhbmNob3JNaW5ZIjowLjUsImFuY2hvck1heFgiOjAuNSwiYW5jaG9yTWF4WSI6MC41LCJwaXZvdFgiOjAuNSwicGl2b3RZIjowLjV9LCJpbWFnZUFzc2V0SWQiOm51bGwsImltYWdlVGludCI6ZmFsc2UsImltYWdlVHlwZSI6ImJhc2ljIiwicHJlZmFiSWQiOm51bGwsInByZWZhYlZhcmlhYmxlIjpudWxsLCJsdWFNYXNrIjpudWxsfSx7ImlkIjoiY2FyZC1kZXNjcmlwdGlvbiIsIm5hbWUiOiJjYXJkLWRlc2NyaXB0aW9uIiwidHlwZSI6InRleHRib3giLCJ4Ijo5MC4wLCJ5IjoxNzQuMCwid2lkdGgiOjEzMi4wLCJoZWlnaHQiOjkyLjAsInJvdGF0aW9uIjowLjAsInJvdGF0aW9uWCI6MC4wLCJyb3RhdGlvblkiOjAuMCwiY29sb3IiOiIjZWNlNmRhIiwib3BhY2l0eSI6MS4wLCJ6SW5kZXgiOjcsImlzQmFja2dyb3VuZCI6ZmFsc2UsInRleHRCb3giOnsidGV4dCI6IiIsImZvbnRTaXplIjoxNSwiYXV0b1NpemUiOnRydWUsIm1pbkZvbnRTaXplIjoxNCwidGV4dENvbG9yIjoiI2VjZTZkYSIsInRleHRPcGFjaXR5IjoxLjAsImJnQ29sb3IiOiIjZmZmZmZmIiwiYmdPcGFjaXR5IjowLjAsIm91dGxpbmVFbmFibGVkIjpmYWxzZSwib3V0bGluZUNvbG9yIjoiIzMzMzMzMyIsIm91dGxpbmVPcGFjaXR5IjowLjIsImFsaWduSCI6ImNlbnRlciIsImFsaWduViI6Im1pZGRsZSIsImFuY2hvclR5cGUiOiJjZW50ZXIiLCJ2aXNpYmxlIjp0cnVlLCJzY2FsZVgiOjEuMCwic2NhbGVZIjoxLjAsImFuY2hvck1pblgiOjAuNSwiYW5jaG9yTWluWSI6MC41LCJhbmNob3JNYXhYIjowLjUsImFuY2hvck1heFkiOjAuNSwicGl2b3RYIjowLjUsInBpdm90WSI6MC41fSwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNvc3Qtb3V0bGluZSIsIm5hbWUiOiJjb3N0LW91dGxpbmUiLCJ0eXBlIjoiZWxsaXBzZSIsIngiOjI2LjAsInkiOjI2LjAsIndpZHRoIjo0Ni4wLCJoZWlnaHQiOjQ2LjAsInJvdGF0aW9uIjowLjAsInJvdGF0aW9uWCI6MC4wLCJyb3RhdGlvblkiOjAuMCwiY29sb3IiOiIjZjVkNzlhIiwib3BhY2l0eSI6MS4wLCJ6SW5kZXgiOjgsImlzQmFja2dyb3VuZCI6ZmFsc2UsInRleHRCb3giOm51bGwsImltYWdlQXNzZXRJZCI6bnVsbCwiaW1hZ2VUaW50IjpmYWxzZSwiaW1hZ2VUeXBlIjoiYmFzaWMiLCJwcmVmYWJJZCI6bnVsbCwicHJlZmFiVmFyaWFibGUiOm51bGwsImx1YU1hc2siOm51bGx9LHsiaWQiOiJjb3N0LXNlcGFyYXRvciIsIm5hbWUiOiJjb3N0LXNlcGFyYXRvciIsInR5cGUiOiJlbGxpcHNlIiwieCI6MjYuMCwieSI6MjYuMCwid2lkdGgiOjQ0LjAsImhlaWdodCI6NDQuMCwicm90YXRpb24iOjAuMCwicm90YXRpb25YIjowLjAsInJvdGF0aW9uWSI6MC4wLCJjb2xvciI6IiMwZjExMTciLCJvcGFjaXR5IjoxLjAsInpJbmRleCI6OSwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6bnVsbCwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNvc3QtZW5lcmd5IiwibmFtZSI6ImNvc3QtZW5lcmd5IiwidHlwZSI6ImVsbGlwc2UiLCJ4IjoyNi4wLCJ5IjoyNi4wLCJ3aWR0aCI6NDAuMCwiaGVpZ2h0Ijo0MC4wLCJyb3RhdGlvbiI6MC4wLCJyb3RhdGlvblgiOjAuMCwicm90YXRpb25ZIjowLjAsImNvbG9yIjoiI2U5YTkzYiIsIm9wYWNpdHkiOjEuMCwiekluZGV4IjoxMCwiaXNCYWNrZ3JvdW5kIjpmYWxzZSwidGV4dEJveCI6bnVsbCwiaW1hZ2VBc3NldElkIjpudWxsLCJpbWFnZVRpbnQiOmZhbHNlLCJpbWFnZVR5cGUiOiJiYXNpYyIsInByZWZhYklkIjpudWxsLCJwcmVmYWJWYXJpYWJsZSI6bnVsbCwibHVhTWFzayI6bnVsbH0seyJpZCI6ImNhcmQtY29zdCIsIm5hbWUiOiJjYXJkLWNvc3QiLCJ0eXBlIjoidGV4dGJveCIsIngiOjI2LjAsInkiOjI2LjAsIndpZHRoIjo0MC4wLCJoZWlnaHQiOjQwLjAsInJvdGF0aW9uIjowLjAsInJvdGF0aW9uWCI6MC4wLCJyb3RhdGlvblkiOjAuMCwiY29sb3IiOiIjMmEyNjIwIiwib3BhY2l0eSI6MS4wLCJ6SW5kZXgiOjExLCJpc0JhY2tncm91bmQiOmZhbHNlLCJ0ZXh0Qm94Ijp7InRleHQiOiIiLCJmb250U2l6ZSI6MjIsImF1dG9TaXplIjp0cnVlLCJtaW5Gb250U2l6ZSI6MTQsInRleHRDb2xvciI6IiMyYTI2MjAiLCJ0ZXh0T3BhY2l0eSI6MS4wLCJiZ0NvbG9yIjoiI2ZmZmZmZiIsImJnT3BhY2l0eSI6MC4wLCJvdXRsaW5lRW5hYmxlZCI6ZmFsc2UsIm91dGxpbmVDb2xvciI6IiMzMzMzMzMiLCJvdXRsaW5lT3BhY2l0eSI6MC4yLCJhbGlnbkgiOiJjZW50ZXIiLCJhbGlnblYiOiJtaWRkbGUiLCJhbmNob3JUeXBlIjoiY2VudGVyIiwidmlzaWJsZSI6dHJ1ZSwic2NhbGVYIjoxLjAsInNjYWxlWSI6MS4wLCJhbmNob3JNaW5YIjowLjUsImFuY2hvck1pblkiOjAuNSwiYW5jaG9yTWF4WCI6MC41LCJhbmNob3JNYXhZIjowLjUsInBpdm90WCI6MC41LCJwaXZvdFkiOjAuNX0sImltYWdlQXNzZXRJZCI6bnVsbCwiaW1hZ2VUaW50IjpmYWxzZSwiaW1hZ2VUeXBlIjoiYmFzaWMiLCJwcmVmYWJJZCI6bnVsbCwicHJlZmFiVmFyaWFibGUiOm51bGwsImx1YU1hc2siOm51bGx9XSwibWV0YSI6eyJzb3VyY2VUeXBlIjoianNvbiIsInNvdXJjZU5hbWUiOiJmcmFtZS1jb21tb24iLCJ3YXJuaW5ncyI6W119LCJsaWJyYXJ5Ijp7ImFjdGl2ZUNhdGVnb3J5Ijoi5Z+656GA5b2i54q2IiwiY2F0ZWdvcmllcyI6W3sia2V5IjoiZnVuY3Rpb24taWNvbi1tb25vIiwibGFiZWwiOiLlip/og73lm77moIct5Y2V6ImyIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJmdW5jdGlvbi1pY29uLWNvbG9yIiwibGFiZWwiOiLlip/og73lm77moIct5b2p6ImyIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJnYW1lcGxheS1pY29uLW1vbm8iLCJsYWJlbCI6IueOqeazleWbvuaghy3ljZXoibIiLCJzdXBwb3J0ZWQiOmZhbHNlfSx7ImtleSI6ImdhbWVwbGF5LWljb24tY29sb3IiLCJsYWJlbCI6IueOqeazleWbvuaghy3lvanoibIiLCJzdXBwb3J0ZWQiOmZhbHNlfSx7ImtleSI6Im9ybmFtZW50LW1vbm8iLCJsYWJlbCI6IuijhemlsOWbvuahiC3ljZXoibIiLCJzdXBwb3J0ZWQiOmZhbHNlfSx7ImtleSI6Im9ybmFtZW50LWNvbG9yIiwibGFiZWwiOiLoo4XppbDlm77moYgt5b2p6ImyIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJmbG9vci1tb25vIiwibGFiZWwiOiLlnLDmnb8t5Y2V6ImyIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJmbG9vci1jb2xvciIsImxhYmVsIjoi5Zyw5p2/LeW9qeiJsiIsInN1cHBvcnRlZCI6ZmFsc2V9LHsia2V5IjoiYmFzaWMtc2hhcGUiLCJsYWJlbCI6IuWfuuehgOW9oueKtiIsInN1cHBvcnRlZCI6dHJ1ZX0seyJrZXkiOiJkaXZpZGVyIiwibGFiZWwiOiLliIblibLnur8iLCJzdXBwb3J0ZWQiOmZhbHNlfSx7ImtleSI6InNraWxsLXRhbGVudCIsImxhYmVsIjoi5oqA6IO95aSp6LWLIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJzcGVjaWFsLWNoYXJhY3RlciIsImxhYmVsIjoi54m55q6K5a2X56ymIiwic3VwcG9ydGVkIjpmYWxzZX0seyJrZXkiOiJpdGVtIiwibGFiZWwiOiLpgZPlhbciLCJzdXBwb3J0ZWQiOmZhbHNlfSx7ImtleSI6ImNyZWF0aW9uIiwibGFiZWwiOiLpgKDniakiLCJzdXBwb3J0ZWQiOmZhbHNlfV0sImJhc2VTaGFwZVByZXNldHMiOlt7InR5cGUiOiJlbGxpcHNlIiwiY29sb3IiOiIjMGY3NjZlIiwid2lkdGgiOjg4LjAsImhlaWdodCI6ODguMH0seyJ0eXBlIjoicmVjdGFuZ2xlIiwiY29sb3IiOiIjYzI0MTBjIiwid2lkdGgiOjEwMi4wLCJoZWlnaHQiOjcwLjB9LHsidHlwZSI6InRyaWFuZ2xlIiwiY29sb3IiOiIjN2MzYWVkIiwid2lkdGgiOjk2LjAsImhlaWdodCI6ODYuMH0seyJ0eXBlIjoiZm91cl9wb2ludF9zdGFyIiwiY29sb3IiOiIjMGY0YzgxIiwid2lkdGgiOjkwLjAsImhlaWdodCI6OTAuMH0seyJ0eXBlIjoiZml2ZV9wb2ludF9zdGFyIiwiY29sb3IiOiIjYmUxMjNjIiwid2lkdGgiOjkyLjAsImhlaWdodCI6OTIuMH0seyJ0eXBlIjoicmluZyIsImNvbG9yIjoiI2Y1OWUwYiIsIndpZHRoIjo5Mi4wLCJoZWlnaHQiOjkyLjB9LHsidHlwZSI6InRleHRib3giLCJjb2xvciI6IiNmZmZmZmYiLCJ3aWR0aCI6MTgwLjAsImhlaWdodCI6NDAuMH1dLCJzYXZlZEl0ZW1zIjpbXX19fQ==
