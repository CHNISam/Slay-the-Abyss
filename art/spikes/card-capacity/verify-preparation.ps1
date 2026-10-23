# Offline failure injection only. Writes mock reports under this worktree's build/.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$mockRoot = Join-Path $projectRoot 'build/art-capacity-failure-check'
$mockCliDir = Join-Path $mockRoot 'scripts/dev'
$outputRoot = Join-Path $projectRoot 'build/art-capacity'
New-Item -ItemType Directory -Force $mockCliDir, $outputRoot | Out-Null
$base = Join-Path $mockRoot 'base.gil'
'OFFLINE MOCK INPUT; NOT A GAME SAVE' | Set-Content $base
@'
import {readFileSync} from 'node:fs';
const [action, tool, argsFile, output] = process.argv.slice(2);
if (action === 'read') {
  if (process.env.CAPACITY_MOCK_FAIL === 'read') process.exit(2);
  console.log('{}');
} else {
  const a = JSON.parse(readFileSync(argsFile, 'utf8').replace(/^\uFEFF/, ''));
  if (process.env.CAPACITY_MOCK_FAIL === 'tool' && output.endsWith('ten') && tool === 'scene_set_client_script') process.exit(3);
  const result = tool === 'scene_check_client' ? {ok:true,mock:true} : {mapPath:output+'/mock.gil'};
  if (tool === 'scene_add_client_template') result.templateIndex = a.template.kind === 'image' ? 901 : 902;
  console.log(JSON.stringify({isError:false,result}));
}
'@ | Set-Content (Join-Path $mockCliDir 'mcp_cli.mjs') -Encoding utf8
$cases = @('baseline','one','five','ten','longest')
function Read-Report([string]$relative) {
    return Get-Content (Join-Path $outputRoot $relative) -Raw | ConvertFrom-Json
}
function Assert-True([bool]$value, [string]$message) {
    if (-not $value) { throw $message }
}
try {
    foreach ($failure in @('read', 'tool')) {
        # Seed both the total and every selected case with a previous success.
        @{state='prepared'; runId='old'; candidates=@(@{candidate='old.gil'})} |
            ConvertTo-Json -Depth 4 | Set-Content (Join-Path $outputRoot 'candidates.json')
        foreach ($id in $cases) {
            $folder = Join-Path $outputRoot $id
            New-Item -ItemType Directory -Force $folder | Out-Null
            @{state='prepared'; runId='old'; candidate='old.gil'} | ConvertTo-Json |
                Set-Content (Join-Path $folder 'candidate.json')
        }
        $env:CAPACITY_MOCK_FAIL = $failure
        $failed = $false
        try { & (Join-Path $projectRoot 'scripts/art/prepare-card-capacity.ps1') -BaseMap $base -ToolkitRoot $mockRoot | Out-Null }
        catch { $failed = $true }
        Assert-True $failed "$failure injection must fail"
        $total = Read-Report 'candidates.json'
        Assert-True ($total.state -eq 'preparing' -and @($total.candidates).Count -eq 0) "$failure left a usable total index"
        foreach ($id in $cases) {
            $case = Read-Report "$id/candidate.json"
            Assert-True ($case.runId -eq $total.runId -and $case.runId -ne 'old') "$failure retained an old case"
            if ($failure -eq 'read' -or $id -in @('ten','longest')) {
                Assert-True ($case.state -eq 'preparing' -and $null -eq $case.candidate) "$failure retained an old prepared path for $id"
            }
        }
        Write-Output "PASS $failure failure: total invalidated; selected cases belong to this run; no stale prepared paths"
    }
    $env:CAPACITY_MOCK_FAIL = ''
    & (Join-Path $projectRoot 'scripts/art/prepare-card-capacity.ps1') -BaseMap $base -ToolkitRoot $mockRoot | Out-Null
    $total = Read-Report 'candidates.json'
    Assert-True ($total.state -eq 'prepared' -and @($total.candidates).Count -eq 5) 'success must publish all five current candidates'
    Assert-True (@($total.candidates | Where-Object { $_.runId -ne $total.runId -or $_.state -ne 'prepared' }).Count -eq 0) 'success mixed runs'
    Write-Output 'PASS success: prepared total publishes exactly five current-run prepared candidates (MOCK ONLY)'
}
finally { Remove-Item Env:CAPACITY_MOCK_FAIL -ErrorAction SilentlyContinue }
