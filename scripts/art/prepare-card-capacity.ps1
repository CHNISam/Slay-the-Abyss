param(
    [Parameter(Mandatory)][string]$BaseMap,
    [ValidateSet('baseline','one','five','ten','longest','all')][string]$Scenario = 'all',
    [string]$ToolkitRoot = 'D:/MiliastraTools/genshin-miliastra-mcp',
    [string]$Python = 'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$fixtureRoot = Join-Path $projectRoot 'art/spikes/card-capacity'
$outputRoot = Join-Path $projectRoot 'build/art-capacity'
$cli = Join-Path $ToolkitRoot 'scripts/dev/mcp_cli.mjs'
if (-not (Test-Path -LiteralPath $cli)) { throw 'Installed MCP CLI not found; see docs/TOOLCHAIN.md.' }
$sourceMap = (Resolve-Path -LiteralPath $BaseMap).Path
if ([IO.Path]::GetExtension($sourceMap) -ne '.gil') { throw 'BaseMap must be a clean .gil file.' }
# All candidates must originate from one unchanged source, never from a previous candidate.
if ($sourceMap.StartsWith([IO.Path]::GetFullPath($outputRoot) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a clean base outside build/art-capacity.'
}
$manifest = Get-Content (Join-Path $fixtureRoot 'manifest.json') -Raw | ConvertFrom-Json
$cases = @($manifest.scenarios | Where-Object { $Scenario -eq 'all' -or $_.id -eq $Scenario })
New-Item -ItemType Directory -Force $outputRoot | Out-Null
$env:MILIASTRA_ALLOW_LIVE_WRITE = '0'
$env:MILIASTRA_PYTHON = $Python
$env:MILIASTRA_PLAYTEST_PYTHON = $Python
# Required resource reads happen before any candidate mutation.
foreach ($uri in @('miliastra://workflow', 'miliastra://platform-rules')) {
    $resource = & node $cli read $uri
    if ($LASTEXITCODE -ne 0) { throw "Cannot read $uri" }
    $resource | Set-Content (Join-Path $outputRoot (($uri.Split('/')[-1]) + '.json')) -Encoding utf8
}
$sourceHash = (Get-FileHash -LiteralPath $sourceMap).Hash.ToLower()
$prepared = @()
foreach ($case in $cases) {
    $caseRoot = Join-Path $outputRoot $case.id
    New-Item -ItemType Directory -Force $caseRoot | Out-Null
    $env:MILIASTRA_WORKSPACE = Join-Path $caseRoot 'workspace'
    $baseCopy = Join-Path $caseRoot 'base.gil'
    Copy-Item -LiteralPath $sourceMap -Destination $baseCopy
    if ((Get-FileHash -LiteralPath $baseCopy).Hash.ToLower() -ne $sourceHash) { throw 'Base copy hash mismatch.' }
    @{state='preparing'; scenario=$case.id; platformCompile=$null; officialImport=$null; inGameDisplay=$null; performance=$null} |
        ConvertTo-Json | Set-Content (Join-Path $caseRoot 'candidate.json') -Encoding utf8
    $script:step = 0
    function Invoke-CapacityTool([string]$tool, [hashtable]$arguments) {
        $script:step++
        $stem = Join-Path $caseRoot ('{0:00}-{1}' -f $script:step, $tool)
        $arguments | ConvertTo-Json -Depth 30 | Set-Content "$stem.args.json" -Encoding utf8
        $response = & node $cli call $tool "$stem.args.json" $caseRoot
        if ($LASTEXITCODE -ne 0) { throw "MCP process failed: $tool" }
        $response | Set-Content "$stem.result.json" -Encoding utf8
        $parsed = $response | ConvertFrom-Json
        if ($parsed.isError) { throw ($parsed.result | ConvertTo-Json -Depth 10) }
        return $parsed.result
    }
    $image = Invoke-CapacityTool 'scene_add_client_template' @{
        mapPath=$baseCopy; template=@{name='ART_Image'; kind='image'; size=@(20,20); image=100001; mask=$false}
        outputName='capacity-image-template'
    }
    $text = Invoke-CapacityTool 'scene_add_client_template' @{
        mapPath=$image.mapPath; template=@{name='ART_Text'; kind='text'; size=@(180,40)
            text=@{content='容量验收'; fontSize=22; backgroundOpacity=0; outline=$false}}
        outputName='capacity-text-template'
    }
    foreach ($index in @($image.templateIndex, $text.templateIndex)) {
        if ($null -eq $index -or [double]$index -le 0 -or [double]$index % 1 -ne 0) { throw 'Invalid returned templateIndex.' }
    }
    $mapPath = $text.mapPath
    $luaPath = Join-Path $fixtureRoot ($case.fixture + '/card.lua')
    $originalLua = Get-Content -LiteralPath $luaPath -Raw
    foreach ($slot in $case.slots) {
        $bound = $originalLua
        $bindings = @(@('IMAGE_PREFAB_ID', $image.templateIndex), @('TEXTBOX_PREFAB_ID', $text.templateIndex),
            @('OFFSET_X', $slot.position[0]), @('OFFSET_Y', $slot.position[1]))
        foreach ($binding in $bindings) {
            $needle = 'local ' + $binding[0] + ' = 0'
            if (($bound.Split($needle).Count - 1) -ne 1) { throw "Unexpected exported binding: $needle" }
            $bound = $bound.Replace($needle, 'local ' + $binding[0] + ' = ' + $binding[1])
        }
        $boundPath = Join-Path $caseRoot ($slot.script + '.lua')
        $bound | Set-Content -LiteralPath $boundPath -NoNewline -Encoding utf8
        $result = Invoke-CapacityTool 'scene_set_client_script' @{
            mapPath=$mapPath; name=$slot.script; sourceFile=$boundPath; outputName=('capacity-card-' + $slot.name)
        }
        $mapPath = $result.mapPath
    }
    $probe = Invoke-CapacityTool 'scene_set_client_script' @{
        mapPath=$mapPath; name='ART_Capacity_Probe'; sourceFile=(Join-Path $fixtureRoot 'probe.lua'); outputName='capacity-probe'
    }
    $uiSpec = Get-Content (Join-Path $fixtureRoot $case.ui) -Raw | ConvertFrom-Json -AsHashtable
    $uiSpec.mapPath = $probe.mapPath
    $ui = Invoke-CapacityTool 'scene_add_client_ui' $uiSpec
    $check = Invoke-CapacityTool 'scene_check_client' @{mapPath=$ui.mapPath}
    if (-not $check.ok) { throw 'Candidate client check failed; inspect generated results.' }
    $report = [ordered]@{state='prepared'; scenario=$case.id; candidate=$ui.mapPath; baseSha256=$sourceHash
        sourceLuaSha256=(Get-FileHash -LiteralPath $luaPath).Hash.ToLower(); activeControls=$case.activeControls
        imageTemplateIndex=$image.templateIndex; textTemplateIndex=$text.templateIndex; clientCheck=$check
        platformCompile=$null; officialImport=$null; inGameDisplay=$null; performance=$null}
    $report | ConvertTo-Json -Depth 15 | Set-Content (Join-Path $caseRoot 'candidate.json') -Encoding utf8
    $prepared += $report
    Write-Output "Prepared $($case.id): $($ui.mapPath) (client check only; official import/playtest pending)."
}
if ((Get-FileHash -LiteralPath $sourceMap).Hash.ToLower() -ne $sourceHash) { throw 'Original base changed during preparation.' }
$prepared | ConvertTo-Json -Depth 15 | Set-Content (Join-Path $outputRoot 'candidates.json') -Encoding utf8
