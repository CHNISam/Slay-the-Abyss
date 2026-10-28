// Opt-in serial workload benchmark; never imported by the test suites.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../../scripts/test-lua.mjs';

const [phase,output,baselineFile]=process.argv.slice(2);
assert.ok(['before','after'].includes(phase)&&output,'Usage: node tests/benchmarks/lua-entry-duplication.mjs before|after output.json [before.json]');
const fixtures=['battle_ui_slice_6.lua','battle_ui_slice_7.lua','map_no_crossings.lua'];
const hash=s=>createHash('sha256').update(s).digest('hex');
const baseline=phase==='after'?JSON.parse(readFileSync(baselineFile,'utf8')):null;
const rows=[];
const started=performance.now();
for (const file of fixtures) {
  const script=phase==='before'?'tests/lua/'+file:'tests/fixtures/js-owned/tests/lua/'+file;
  for (let repeat=0;repeat<(phase==='before'?2:1);repeat++) {
    const start=performance.now(),result=runLua(script);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const row={file,repeat,ms:performance.now()-start,status:result.status,
      stdoutSha256:hash(result.stdout),stderrSha256:hash(result.stderr)};
    if(phase==='before'&&repeat) {
      assert.equal(row.stdoutSha256,rows.at(-1).stdoutSha256,'raw and wrapper inputs yield identical complete output');
      assert.equal(row.stderrSha256,rows.at(-1).stderrSha256);
    }
    if(baseline) {
      const before=baseline.rows.find(r=>r.file===file);
      assert.equal(row.stdoutSha256,before.stdoutSha256,'all original scenario output remains');
      assert.equal(row.stderrSha256,before.stderrSha256);
    }
    rows.push(row);
    console.log(`${phase} ${file} ${repeat+1}: ${Math.round(row.ms)} ms`);
  }
}
const report={phase,node:process.version,platform:process.platform,
  scope:'Serial Lua execution workload for three unchanged fixtures; before replays both identical raw/wrapper runLua calls, after retains one. Excludes suite build and JS static-assertion overhead. Not CI wall clock.',
  wallMs:performance.now()-started,rows};
writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(`Measured workload wall: ${Math.round(report.wallMs)} ms`);
