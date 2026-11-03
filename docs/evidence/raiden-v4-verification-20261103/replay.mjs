// Run from this worktree root. Produces a machine-readable, timestamped offline receipt.
// No source edits, desktop access, installs or Git writes. Mutants are fresh Lua processes.
import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync,realpathSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';

const root=fileURLToPath(new URL('../../../',import.meta.url));
if (realpathSync(process.cwd())!==realpathSync(root)) throw new Error('Run from the assigned worktree root');
const negativeOnly=process.argv[2]==='--negative-only';
const focused=process.argv[2]==='--focused';
if (process.argv.length>((negativeOnly||focused)?3:2)) throw new Error('Usage: replay.mjs [--negative-only|--focused]');
const require=createRequire(import.meta.url);
const receipt={schemaVersion:1,stage:'offline-fengari-contracts',startedAt:new Date().toISOString(),
  cwd:process.cwd(),node:process.version,executable:process.execPath,platform:process.platform,
  dependencyResolution:{fengari:require.resolve('fengari'),cli:require.resolve('fengari-node-cli/src/lua-cli.js')},
  sourceCommit:spawnSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).stdout.trim(),
  commands:[],inputs:[],platformEvidence:{candidateGil:'NOT_RUN',officialImport:'NOT_RUN',ready:'NOT_RUN',pc:'NOT_RUN',phone:'NOT_RUN',naturalTwoActs:'NOT_RUN'}};
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
for (const path of ['data/original_v4/cards_v4.json','data/original_v4/rules_v4.json',
  'tests/raiden-v4-verification.test.mjs','tests/lua/raiden_v4_public_commands.lua','tests/lua/raiden_v4_rollback.lua',
  'src/lua/abyss_run.lua','src/lua/abyss_combat.lua','src/lua/abyss_original_v4.lua','src/lua/abyss_snapshot.lua']) {
  const bytes=readFileSync(path);receipt.inputs.push({path,bytes:bytes.length,sha256:sha(bytes)});
}
const frozenExpected=['89229cdd7f6c1640d47bca95338f5e7887fbfd8720af181f7561d6eb45a45fca',
  'a100f8b0fd61e3724f0eda5e077055f82bcacb7a4536d337096d9a6389419c8e'];
if (receipt.inputs.slice(0,2).some((input,i)=>input.sha256!==frozenExpected[i])) throw new Error('Frozen input mismatch');
if (negativeOnly||focused) {
  const latest='docs/evidence/raiden-v4-verification-20261103/results.json';
  const path=negativeOnly && existsSync(latest)?latest:'docs/evidence/raiden-v4-verification-20261103/results-initial.json';
  const bytes=readFileSync(path),baseline=JSON.parse(bytes);
  if (!baseline.commands.filter(command=>!command.expectedFailure).every(command=>command.result==='PASS')
    || baseline.sourceCommit!==receipt.sourceCommit) throw new Error('Baseline is not green at this source commit');
  const changed=receipt.inputs.filter((input,i)=>JSON.stringify(input)!==JSON.stringify(baseline.inputs[i])).map(input=>input.path);
  if (changed.some(path=>!focused||path!=='tests/lua/raiden_v4_rollback.lua')) throw new Error('Unexpected baseline input drift');
  receipt.baseline={path,sha256:sha(bytes),result:'ALL_NORMAL_COMMANDS_PASS',
    changedInputs:changed,reason:focused?'Strengthen late eye rollback only; rerun both new tests and negative controls. Existing seven fixtures remain at their recorded baseline.':'Only negative-control diagnostic matching changed; tests and runtime hashes are unchanged.'};
}
function run(args,{expectedFailure,env}={}) {
  const start=performance.now();
  const result=spawnSync(process.execPath,args,{encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024,
    env:env??process.env});
  const accepted=!result.error && !result.signal && (expectedFailure
    ? result.status!==0 && result.stderr.includes(expectedFailure)
    : result.status===0);
  const entry={executable:process.execPath,args,durationMs:Math.round(performance.now()-start),
    exitCode:result.status,signal:result.signal,error:result.error?.message??null,
    expectedFailure:expectedFailure??null,result:accepted?(expectedFailure?'EXPECTED_RED':'PASS'):'FAIL',
    stdout:result.stdout,stderr:result.stderr};
  receipt.commands.push(entry);
  console.log(`${entry.result} ${entry.durationMs}ms ${JSON.stringify(args)}`);
  return accepted;
}
let ok=true;
if (!negativeOnly && !focused) {
  ok=run(['scripts/build-lua-data.mjs']) && run(['scripts/build-ui.mjs']);
}
if (ok && !negativeOnly) {
  ok=run(['--test','--test-concurrency=1','tests/raiden-v4-verification.test.mjs']) && ok;
  for (const file of focused?[]:['original_v4_contract','original_v4_acquisition','original_v4_lifecycle','original_v4_cards',
    'competition_roster_run','competition_roster_ui','competition_roster_prepared_ui']) {
    ok=run(['scripts/test-lua.mjs',`tests/lua/${file}.lua`]) && ok;
  }
}
if (ok) {
  const luaEnv={...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;',
    LUA_PATH_5_3:'./build/lua/?.lua;./src/lua/?.lua;;',LUA_INIT:'',LUA_INIT_5_3:''};
  const mutants=[
    {name:'omit per-turn resolve reset',needle:'expected 4 got 2',script:'public_commands',
      code:'local V=require("abyss_original_v4");local start=V.startTurn;V.startTurn=function(s)local prior=s.originalV4.resolveGained;local out=start(s);s.originalV4.resolveGained=prior;return out end;'},
    {name:'preview consumes real eye use',needle:'original graph edge uses',script:'public_commands',
      code:'local V=require("abyss_original_v4");local preview=V.preview;V.preview=function(c,s,...)local out=preview(c,s,...);s.originalV4.eye.uses=s.originalV4.eye.uses-1;return out end;'},
    {name:'late rollback leaves corrupted resolve',needle:'original graph edge resolve',script:'rollback',
      code:'local S=require("abyss_snapshot");local capture=S.capture;S.capture=function(root,...)local restore,owner=capture(root,...);if root.character=="raiden"then return function()restore();root.combat.originalV4.resolve=99 end,owner end;return restore,owner end;'},
  ];
  for (const mutant of mutants) {
    const accepted=run([receipt.dependencyResolution.cli,'-e',
      `${mutant.code}dofile("tests/lua/raiden_v4_${mutant.script}.lua")`],{env:luaEnv,expectedFailure:mutant.needle});
    receipt.commands.at(-1).negativeControl=mutant.name;ok=accepted && ok;
  }
}
receipt.finishedAt=new Date().toISOString();
receipt.result=ok?'PASS_WITH_EXPECTED_NEGATIVE_CONTROLS':'FAIL';
const output=resolve(root,`docs/evidence/raiden-v4-verification-20261103/${negativeOnly?'negative-controls':'results'}.json`);
writeFileSync(output,JSON.stringify(receipt,null,2)+'\n');
console.log(`Receipt: ${output}`);
process.exitCode=ok?0:1;
