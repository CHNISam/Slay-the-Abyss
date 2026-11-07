import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runStatic,reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {discoverSources,measureSources} from '../scripts/lua-quality-metrics.mjs';

const file='src/lua/abyss_colorless_cards.lua';
const normalized=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const responsibilities=['catalogIndex','catalogNewIndex','eligibleKill','rewardGreed','growRitual','resolveKill','M.apply',
  ...['apotheosis','shackles','impatience','enlightenment','discovery','madness',
    'generateColorless','generateDraw','transmutation','deepBreath','deepBreathShuffle',
    'violence','panache','bomb','mayhem','mayhemPlay','sadisticDamage'].map(name=>`actionHandlers.${name}`)];
function replay(source,group){
  const directory=mkdtempSync(join(tmpdir(),'colorless-actions-'));
  try{
    const path=join(directory,'driver.lua');
    writeFileSync(path,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\n`
      +`ABYSS_COLORLESS_GROUP=${luaString(group)}\n`
      +'ABYSS_COLORLESS_TRACE=true\n'
      +`package.preload.abyss_colorless_cards=function() return assert(load(${luaString(source)},'colorless-action-source'))() end\n`
      +"dofile('tests/lua/colorless_action_responsibilities.lua')\n");
    return runLua(path);
  }finally{rmSync(directory,{recursive:true,force:true});}
}
test('Colorless old full source is authenticated to b4ac6314',()=>{
  assert.equal(createHash('sha256').update(normalized('tests/fixtures/colorless-actions-before.lua')).digest('hex'),
    '0e27a235638b74f9390fb9ef3f51e8e4b50df4234c55a892fa99dc41ae980806');
});

test('Colorless apply and every extracted action responsibility stay within CC15',()=>{
  const sources=discoverSources();
  const diagnostics=runStatic(['--max-cyclomatic-complexity','0','--only','561']).diagnostics;
  const measured=measureSources(sources,diagnostics);
  assert.deepEqual(measured.errors,[]);
  const module=measured.modules.find(m=>m.file===file);
  const apply=module.functions.find(f=>f.name==='M.apply');
  assert(apply.complexity<=15,`M.apply CC${apply.complexity} exceeds 15`);
  for(const name of responsibilities){
    const rows=module.functions.filter(f=>f.name===name);assert.equal(rows.length,1,name);
    assert(rows[0].complexity<=15,`${name} CC${rows[0].complexity} exceeds 15`);
  }
  const report=reviewResponsibilityComplexity(diagnostics,sources);
  assert.deepEqual(report.errors,[]);
});

for(const [group,count]of [['random',7],['rewards',7],['dispatch',9]])test(`old/new independent VMs preserve complete Colorless ${group} graphs and returns`,()=>{
  const before=replay(normalized('tests/fixtures/colorless-actions-before.lua'),group);
  const after=replay(normalized(file),group);
  for(const result of [before,after]){
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,new RegExp(`COLORLESS_ACTION_PASS ${group} ${count}`));
  }
  assert.equal(after.stdout,before.stdout,'entire state/event/queue/RNG/alias graph differs');
});

test('ordinary raw Colorless regression runs all cases without large differential output',()=>{
  const result=runLua('tests/lua/colorless_action_responsibilities.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/COLORLESS_ACTION_PASS all 23/);
  assert(!result.stdout.includes('COLORLESS_TRACE'));
  assert(Buffer.byteLength(result.stdout)<65536);
});

for(const [name,group,before,after]of [
  ['Madness rejection sampling','random','until (better and combat.cardDefinition(state,c).cost or combat.combatBaseCost(state,c))>0','until true'],
  ['Deep Breath second shuffle','random',"Random.shuffle(assert(state.shuffleRng,'Deep Breath needs shuffle stream'),state.draw)",'-- omitted second shuffle'],
  ['Violence shuffle stream','random',"Random.shuffle(assert(state.shuffleRng,'Violence needs shuffle stream'),tmp)",'-- omitted candidate shuffle'],
  ['Greed minion rejection','rewards','and not target.minion','and true'],
  ['Greed captured action kind','rewards',"if kind=='greed'then rewardGreed(combat,state,a)","if a.kind=='greed'then rewardGreed(combat,state,a)"],
  ['Ritual graph deduplication','rewards','if c and not seen[c] and (c.uuid or c.uid)==uuid then','if c and (c.uuid or c.uid)==uuid then'],
  ['Ritual permanent identity','rewards','local key=c.deckUid','local key=c.uid'],
])test(`Colorless behavioral assertions reject real mutation: ${name}`,()=>{
  const source=normalized(file);assert.equal(source.split(before).length,2,'one exact production mutation');
  const result=replay(source.replace(before,after),group);
  assert.notEqual(result.status,0,'mutant survived');
  assert.match(result.stdout+result.stderr,/\[COLORLESS_ACTION\]/,'must fail a behavior assertion, not parse/load');
});

test('Colorless production complexity policy requires every action and nested callback',()=>{
  const lines=responsibilities.map(name=>`function ${name}() return function() end end`);
  const source=lines.join('\n');
  const row=(line,column,subject,cc)=>({file,line,column,code:'W561',message:`cyclomatic complexity of ${subject} is too high (${cc} > 0)`});
  const diagnostics=[row(1,1,'main chunk',1)];
  for(const [i,name]of responsibilities.entries()){
    diagnostics.push(row(i+1,1,`function '${name}'`,15));
    diagnostics.push(row(i+1,lines[i].indexOf('function()')+1,'function',1));
  }
  const errors=(rows=diagnostics)=>reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file);
  assert.deepEqual(errors(),[]);
  for(const diagnostic of diagnostics.slice(1)){
    const message=diagnostic.message;diagnostic.message=message.replace(/\(\d+ > 0\)/,'(16 > 0)');
    assert(errors().some(e=>e.message.includes('16 exceeds 15')));diagnostic.message=message;
  }
  for(const name of responsibilities)assert(errors(diagnostics.filter(d=>!d.message.includes(`'${name}'`))).some(e=>e.message.includes('entry missing')));
  assert(errors(diagnostics.slice(1)).some(e=>e.message.includes('Incomplete')));
});
