param(
    [Parameter(Mandatory)][string]$BaseMap,
    [string]$CardLua = 'art/spikes/card-editor/card.lua',
    [ValidatePattern('^[A-Za-z0-9_-]{1,60}$')][string]$CandidateName = 'abyss-art-card-candidate',
    [string]$ToolkitRoot = 'D:/MiliastraTools/genshin-miliastra-mcp',
    [string]$Python = 'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$outputRoot = Join-Path $projectRoot 'build/art-platform'
$cli = Join-Path $ToolkitRoot 'scripts/dev/mcp_cli.mjs'
if (-not (Test-Path -LiteralPath $cli)) { throw 'Installed MCP CLI not found; see docs/TOOLCHAIN.md.' }
$sourceMap = (Resolve-Path -LiteralPath $BaseMap).Path
New-Item -ItemType Directory -Force $outputRoot | Out-Null
$baseCopy = Join-Path $outputRoot 'base.gil'
if ($sourceMap -eq $baseCopy) { throw 'Choose an input other than the generated base copy.' }
@{state='preparing'; officialImport='not_run'; inGameDisplay='not_run'; performance='not_measured'} |
    ConvertTo-Json | Set-Content (Join-Path $outputRoot 'candidate.json') -Encoding utf8
Copy-Item -LiteralPath $sourceMap -Destination $baseCopy
$env:MILIASTRA_WORKSPACE = Join-Path $outputRoot 'workspace'
$env:MILIASTRA_ALLOW_LIVE_WRITE = '0'
$env:MILIASTRA_PYTHON = $Python
$env:MILIASTRA_PLAYTEST_PYTHON = $Python
$script:step = 0
function Invoke-ArtTool([string]$tool, [hashtable]$arguments) {
    $script:step++
    $stem = Join-Path $outputRoot ('{0:00}-{1}' -f $script:step, $tool)
    $arguments | ConvertTo-Json -Depth 30 | Set-Content "$stem.args.json" -Encoding utf8
    $response = & node $cli call $tool "$stem.args.json" $outputRoot
    if ($LASTEXITCODE -ne 0) { throw "MCP process failed: $tool" }
    $response | Set-Content "$stem.result.json" -Encoding utf8
    $parsed = $response | ConvertFrom-Json
    if ($parsed.isError) { throw ($parsed.result | ConvertTo-Json -Depth 10) }
    return $parsed.result
}
# Required resources are read through the installed MCP, never inferred from generated files.
foreach ($uri in @('miliastra://workflow', 'miliastra://platform-rules')) {
    $resource = & node $cli read $uri
    if ($LASTEXITCODE -ne 0) { throw "Cannot read $uri" }
    $resource | Set-Content (Join-Path $outputRoot (($uri.Split('/')[-1]) + '.json'))
}
$image = Invoke-ArtTool 'scene_add_client_template' @{
    mapPath=$baseCopy; template=@{name='ART_Image'; kind='image'; size=@(20,20); image=100001; mask=$false}
    outputName='art-image-template'
}
$text = Invoke-ArtTool 'scene_add_client_template' @{
    mapPath=$image.mapPath; template=@{name='ART_Text'; kind='text'; size=@(180,30)
        text=@{content='美术实验'; fontSize=22; backgroundOpacity=0; outline=$false}}
    outputName='art-text-template'
}
$cardLuaPath = if ([IO.Path]::IsPathRooted($CardLua)) { $CardLua } else { Join-Path $projectRoot $CardLua }
$source = Get-Content -LiteralPath $cardLuaPath -Raw
foreach ($binding in @(@('IMAGE_PREFAB_ID',$image.templateIndex), @('TEXTBOX_PREFAB_ID',$text.templateIndex))) {
    $needle = 'local ' + $binding[0] + ' = 0'
    if (($source.Split($needle).Count - 1) -ne 1) { throw "Unexpected upstream binding: $needle" }
    $source = $source.Replace($needle, 'local ' + $binding[0] + ' = ' + $binding[1])
}
$boundLua = Join-Path $outputRoot 'ART_Card.lua'
$source | Set-Content $boundLua -NoNewline -Encoding utf8
$card = Invoke-ArtTool 'scene_set_client_script' @{
    mapPath=$text.mapPath; name='ART_Card'; sourceFile=$boundLua; outputName='art-card-script'
}
$probe = Invoke-ArtTool 'scene_set_client_script' @{
    mapPath=$card.mapPath; name='ART_Probe'
    sourceFile=(Join-Path $projectRoot 'art/spikes/platform/probe.lua'); outputName='art-probe-script'
}
$uiSpec = Get-Content (Join-Path $projectRoot 'art/spikes/platform/card-ui.json') -Raw | ConvertFrom-Json -AsHashtable
$uiSpec.mapPath = $probe.mapPath
$uiSpec.outputName = $CandidateName
$ui = Invoke-ArtTool 'scene_add_client_ui' $uiSpec
$check = Invoke-ArtTool 'scene_check_client' @{mapPath=$ui.mapPath}
if (-not $check.ok) { throw 'Candidate client check failed; inspect generated results.' }
[ordered]@{state='prepared'; candidate=$ui.mapPath; sourceLua=(Resolve-Path -LiteralPath $cardLuaPath).Path
    sourceLuaSha256=(Get-FileHash -LiteralPath $cardLuaPath).Hash.ToLower(); imageTemplateIndex=$image.templateIndex; textTemplateIndex=$text.templateIndex
    clientCheck=$check; officialImport='not_run'; inGameDisplay='not_run'; performance='not_measured'} |
    ConvertTo-Json -Depth 15 | Set-Content (Join-Path $outputRoot 'candidate.json') -Encoding utf8
Write-Output "Prepared copy: $($ui.mapPath). Client check passed. Official import and playtest still required."
