-- Test-only: client callback intervals are not GPU frame times.
local elapsed, samples, reported = 0, {}, false
function OnStart()
    local w, h = game.GetUICanvasSize()
    local k = math.min(w / 1280, h / 720)
    script.object:SetSizeDelta(1280, 720)
    script.object:SetLocalScale(k, k, 1)
    print('AI_ART_START canvas=' .. w .. 'x' .. h)
    script:EnableUpdate(true)
    script.object:GetChild('Confirm'):AddCursorEventListener(Enum.CursorEventType.CursorClick, function()
        script.object:GetChild('Status').text = '点击通过 / AI_ART_CLICK_OK'
        print('AI_ART_CLICK_OK')
    end)
end
function OnUpdate(dt)
    if reported or dt <= 0 then return end
    elapsed = elapsed + dt
    samples[#samples + 1] = dt
    if elapsed >= 10 then
        table.sort(samples)
        local mean = elapsed * 1000 / #samples
        local p95 = samples[math.ceil(#samples * .95)] * 1000
        script.object:GetChild('Metrics').text = string.format('10s 客户端dt mean %.1f / P95 %.1f ms / n=%d', mean, p95, #samples)
        print('AI_ART_DT mean=' .. mean .. ' p95=' .. p95 .. ' n=' .. #samples)
        reported = true
        script:EnableUpdate(false)
    end
end
