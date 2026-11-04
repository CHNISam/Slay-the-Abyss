import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import luaparse from 'luaparse';
import {luaString} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {effectsSupportedBefore as before,effectsSupportedSha256,effectsSupportedRevision} from './helpers/effects-supported-source.mjs';
const file='src/lua/abyss_effects.lua';
const source=()=>readFileSync(file,'utf8').replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(s).digest('hex');
function execute(source){
 const dir=mkdtempSync(join(tmpdir(),'effects-supported-'));
 try{
  const module=join(dir,'effects.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
  writeFileSync(driver,`EFFECTS_SOURCE=${luaString(module.replaceAll('\\','/'))};dofile(${luaString(resolve('tests/lua/effects_supported_responsibility.lua').replaceAll('\\','/'))})`);
  return runLua(driver,{timeout:30000,maxBuffer:4*1024*1024});
 }finally{rmSync(dir,{recursive:true,force:true});}
}
test('supported complete frozen old and live modules characterize in independent VMs',t=>{
 assert.equal(effectsSupportedRevision,'a308edbfde7792485cbe79b5650c17e1c7de98cc');
 assert.equal(effectsSupportedSha256,'5129a4a7929eec8c0acea1197532c902714ed3f06a5a52bb7939d7de8d0310f5');
 assert.equal(hash(before),effectsSupportedSha256);
 const old=execute(before),live=execute(source());
 for(const result of [old,live]){assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/EFFECTS_SUPPORTED_PASS/);}
 assert.equal(live.stdout,old.stdout,'results, arity, graph aliases, reads, dynamic calls and errors');
 t.diagnostic(`full independent trace SHA256 ${hash(live.stdout)}`);
});

test('supported responsibility rejects genuine semantic mutants',()=>{
 const live=source();
 const changes=[
  ['dense holes','for i = 1, count do if effects[i] == nil then return nil, "invalid_effect" end end','-- omit dense member validation'],
  ['scry global prescan','if hasScry then','if false then'],
  ['conditional target preflight','branch or not targetChecked or','branch or false or'],
  ['recursive branch guard','return not (branch or not targetChecked or','return not (false or not targetChecked or'],
  ['poison/vulnerable distinction',"branch=='target_poison' and op=='damage'","branch and op=='damage'"],
  ['conditional metadata','ok, unsupported = effectMetadataSupported(effect, op)','ok, unsupported = op == "conditional" or effectMetadataSupported(effect, op)'],
  ['second dynamic support check','or op=="damageAll" or CardActions.supports(op)','or op=="damageAll" or true'],
  ['discard reads amount too soon','branch or effectIndex ~= count\n        or type(effect.value) ~= "number"','type(effect.value) ~= "number" or branch or effectIndex ~= count'],
  ['targetGroup preflight omitted','local _, invalid = targetGroup(effects)','local invalid = nil'],
  ['defect validation omitted',"if op=='defectFinal' and not require('abyss_defect_final_cards').supports(effect)","if false"],
  ['success arity','    return supported(effects, false)','    local ok, why = supported(effects, false); return ok, why'],
  ['cached amount reads','local function selectionAmountsSupported(effect, op, branch, effectIndex, count)\n','local function selectionAmountsSupported(effect, op, branch, effectIndex, count)\n    effect = setmetatable({op=op,value=effect.value},{__index=effect})\n'],
 ];
 const fixedStart=live.indexOf('    if effect.fixed ~= nil'),targetStart=live.indexOf('    if effect.target ~= nil',fixedStart),metadataEnd=live.indexOf('    return true\nend',targetStart);
 assert.ok(fixedStart>0&&targetStart>fixedStart&&metadataEnd>targetStart);
 const mutants=changes.map(([label,a,b])=>{assert.equal(live.split(a).length-1,1,label+' unique seam');return [label,live.replace(a,b)];});
 mutants.push(['fixed/target order',live.slice(0,fixedStart)+live.slice(targetStart,metadataEnd)+live.slice(fixedStart,targetStart)+live.slice(metadataEnd)]);
 for(const [label,mutant] of mutants){
  luaparse.parse(mutant,{luaVersion:'5.3'});
  const result=execute(mutant);
  assert.notEqual(result.status,0,label+' survived');
  assert.match(result.stdout+result.stderr,/\[EFFECTS_SUPPORTED\]/,label+' must fail a behavioral assertion');
 }
});
