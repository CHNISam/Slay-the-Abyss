import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,unlinkSync} from 'node:fs';
import {createHash,randomUUID} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import assert from 'node:assert/strict';
import {runLua} from '../../../scripts/test-lua.mjs';
import {luaString} from '../../../scripts/build-lua-data.mjs';
const base='aa4d56f57c15727668ef8675e626b44e67a5aaa5';
const modules=['abyss_game_ui','abyss_battle_actions','abyss_battle_card_view','abyss_battle_potion_bindings'];
const old=Object.fromEntries(modules.map(name=>[name,execFileSync('git',['show',`${base}:src/lua/${name}.lua`],{encoding:'utf8'})]));
const hash=text=>createHash('sha256').update(text.replaceAll('\r\n','\n')).digest('hex');
const selected=process.argv.slice(2);
assert.ok(selected.every(name=>['host','potion','trajectory'].includes(name)),'unknown evidence selection');
const report={base,node:process.version,environment:'Fengari 0.1.0, real production Lua Host, mock native controls',sources:Object.fromEntries(modules.map(name=>[name,{baseline:hash(old[name]),current:hash(readFileSync(`src/lua/${name}.lua`,'utf8'))}])),official:'NOT_RUN',devices:'NOT_RUN'};
for(const [label,sources] of [['baseline',old],['current',{}]]){
 for(const [name,fixture] of [['trajectory','runtime_ui_trajectory'],['host','runtime_ui_hotpaths'],['potion','potion_drag_hotpath']]){
  if(selected.length&&!selected.includes(name))continue;
  const entry=join(tmpdir(),`m9-runtime-${randomUUID()}.lua`);
  const preload=Object.entries(sources).map(([module,source])=>`package.preload[${luaString(module)}]=assert(load(${luaString(source)},'@${module}-${base}'))`).join('\n');
  writeFileSync(entry,`${preload}\nABYSS_RUNTIME_BASELINE=true;ABYSS_RUNTIME_FRAMES=300;dofile('tests/lua/${fixture}.lua')\n`);
  try{
   const result=runLua(entry,{timeout:60000});assert.equal(result.status,0,result.stdout+result.stderr);
   writeFileSync(`docs/evidence/m9-runtime-20261103/${label}-${name}.txt`,result.stdout);
   console.log(label,name,result.stdout.split('\n').filter(line=>/HOTPATH|refresh battle|settled cards/.test(line)).join('\n'));
  }finally{unlinkSync(entry);}
 }
}
const trajectory=label=>readFileSync(`docs/evidence/m9-runtime-20261103/${label}-trajectory.txt`,'utf8').split(/\r?\n/).filter(line=>line.startsWith('RUNTIME_TRAJECTORY '));
assert.deepEqual(trajectory('current'),trajectory('baseline'));
report.trajectoryParity=true;
writeFileSync('docs/evidence/m9-runtime-20261103/baseline.json',JSON.stringify(report,null,2)+'\n');
console.log('Exact old/current trajectory parity PASS');
