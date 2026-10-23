-- Integration probe only. Frame dt measures client updates, not GPU frame time.
local elapsed = 0
local samples = {}
local reported = false

function OnStart()
    print('ART_PROBE_START')
    script.object:GetChild('Metrics').text = '客户端帧间隔采样中（10秒）'
    script:EnableUpdate(true)
    local button = script.object:GetChild('Confirm')
    button:AddCursorEventListener(Enum.CursorEventType.CursorClick, function()
        script.object:GetChild('Status').text = '点击通过'
        print('ART_CLICK_OK')
    end)
end

function OnUpdate(dt)
    if reported or dt <= 0 then return end
    elapsed = elapsed + dt
    samples[#samples + 1] = dt
    if elapsed >= 10 then
        table.sort(samples)
        script.object:GetChild('Metrics').text = string.format(
            '客户端帧间隔：均值 %.1f / P95 %.1f ms（非GPU耗时）',
            elapsed * 1000 / #samples, samples[math.ceil(#samples * 0.95)] * 1000)
        print('ART_DT frames=' .. #samples .. ' mean_ms=' .. (elapsed * 1000 / #samples)
            .. ' p95_ms=' .. (samples[math.ceil(#samples * 0.95)] * 1000))
        reported = true
        script:EnableUpdate(false)
    end
end
