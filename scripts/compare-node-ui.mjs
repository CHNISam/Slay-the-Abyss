// Compare the frozen develop Node UI with this refactor using the real regression
// fixtures. Assertions check method returns; resulting core state and controls are
// serialized deterministically; only functions and parent back-references are omitted.
import {readFileSync,writeFileSync,mkdirSync,unlinkSync} from 'node:fs';
import {execFileSync,spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const baseline='1f260a71972b03dae5b63e8d6f12d055973a4c83';
const dir='.artifacts/node-ui-parity';mkdirSync(dir,{recursive:true});
const old=execFileSync('git',['show',`${baseline}:src/lua/abyss_node_ui.lua`],{encoding:'utf8'});
writeFileSync(`${dir}/baseline.lua`,old);
const tracing=`
local instances={}
local UI=require('abyss_node_ui')
local original=UI.new
UI.new=function(...)
 local ui=original(...);instances[#instances+1]=ui;return ui
end
local function serialize(value,seen)
 local kind=type(value)
 if kind=='function' then return 'function' end
 if kind~='table' then return kind..':'..tostring(value) end
 seen=seen or {};if seen[value] then return 'ref:'..seen[value] end
 local keys={};for k in pairs(value)do if k~='parent' then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 seen[value]=tostring(#keys)..':'..tostring(keys[1])
 local out={};for _,k in ipairs(keys)do out[#out+1]=serialize(k,seen)..'='..serialize(value[k],seen)end
 return '{'..table.concat(out,';')..'}'
end
local function trace()
 for _,ui in ipairs(instances)do
  local run={};for _,key in ipairs({'hp','maxHp','gold','deck','relics','potions','nodeFlow','phase','act','floor','roomGeneration'})do run[key]=ui.run[key]end
  print('PARITY '..serialize({root=ui.root,run=run,map=require('abyss_map').snapshot(ui.map),notice=ui.notice,mode=ui.mode,picker=ui.picker,selected=ui.selected,page=ui.page,pickPage=ui.pickPage,visible=ui.visible}))
 end
 instances={}
end
`;
const fixtures=['node_ui.lua',...Array.from({length:7},(_,i)=>`node_ui_slice_${i+2}.lua`),'node_ui_gestures.lua'];
const results=[];
for(const fixture of fixtures){
 const hashes=[];
 for(const version of ['old','new']){
  let support=readFileSync('tests/lua/support/node_ui_cases.lua','utf8').replace(' fn() count =',' fn() trace() count =');
  let source=readFileSync(`tests/lua/${fixture}`,'utf8');
  if(fixture==='node_ui_gestures.lua')source=source.replace('local ok,err=pcall(fn)','local ok,err=pcall(fn); if ok then trace() end');
  else source=source.replace('dofile("tests/lua/support/node_ui_cases.lua")',`(function() ${support} end)()`);
  const driver=`${version==='old'?`package.loaded.abyss_node_ui=dofile('${dir}/baseline.lua')`:''}\n${tracing}\n${source}`;
  const path=`${dir}/driver.lua`;writeFileSync(path,driver);
  const result=spawnSync(process.execPath,['node_modules/fengari-node-cli/src/lua-cli.js',path],{encoding:'utf8',timeout:120000,maxBuffer:128*1024*1024,env:{...process.env,LUA_PATH:'./build/lua/?.lua;./src/lua/?.lua;;'}});
  if(result.error||result.status!==0)throw new Error(`${fixture} ${version}: ${result.error?.message||result.stderr}`);
  if(!result.stdout.includes('PARITY ')||!result.stdout.includes(fixture==='node_ui_gestures.lua'?'LUA_NODE_GESTURES_PASS':'LUA_NODE_UI_PASS'))throw new Error('Missing replay/trace marker: '+fixture);
  hashes.push(createHash('sha256').update(result.stdout).digest('hex'));
  writeFileSync(`${dir}/${fixture}.${version}.log`,result.stdout);
 }
 const row={fixture,old:hashes[0],new:hashes[1],equal:hashes[0]===hashes[1]};results.push(row);console.log(JSON.stringify(row));
 if(!row.equal)throw new Error(`Behavior mismatch: ${fixture}; inspect ${dir}`);
}
writeFileSync(`${dir}/report.json`,JSON.stringify({baseline,results},null,2)+'\n');unlinkSync(`${dir}/driver.lua`);
