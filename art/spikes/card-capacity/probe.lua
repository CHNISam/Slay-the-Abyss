-- Independent diagnostics; client update dt is not GPU time.
local elapsed = 0
local samples = {}
local reported = false
local alive = false
local generation = 0

function OnStart()
    elapsed, samples, reported, alive = 0, {}, false, true
    generation = generation + 1
    local current = generation
    print('ART_CAPACITY_PROBE_START')
    script.object:GetChild('Metrics').text = '客户端帧间隔采样中（10秒）'
    script:EnableUpdate(true)
    script.object:GetChild('Confirm'):AddCursorEventListener(Enum.CursorEventType.CursorClick, function()
        if not alive or generation ~= current then return end
        script.object:GetChild('Status').text = '点击通过'
        print('ART_CAPACITY_CLICK_OK')
    end)
end

function OnUpdate(dt)
    if not alive or reported or dt <= 0 then return end
    elapsed = elapsed + dt
    samples[#samples + 1] = dt
    if elapsed >= 10 then
        table.sort(samples)
        local mean = elapsed * 1000 / #samples
        local p95 = samples[math.ceil(#samples * 0.95)] * 1000
        script.object:GetChild('Metrics').text = string.format(
            '客户端帧间隔：均值 %.1f / P95 %.1f ms（非GPU耗时）', mean, p95)
        print('ART_CAPACITY_DT frames=' .. #samples .. ' mean_ms=' .. mean .. ' p95_ms=' .. p95)
        reported = true
        script:EnableUpdate(false)
    end
end

function OnDestroy()
    alive = false
    generation = generation + 1
    script:EnableUpdate(false)
    elapsed, samples, reported = 0, {}, false
end
