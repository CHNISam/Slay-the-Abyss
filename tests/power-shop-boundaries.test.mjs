import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {gunzipSync} from 'node:zlib';
import {luaString} from '../scripts/build-lua-data.mjs';
import {installLuaGraphObserver} from './helpers/lua-graph-observer.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
import {discoverSources,dependencyCycles} from '../scripts/lua-quality-metrics.mjs';
import {reviewResponsibilityComplexity} from '../scripts/check-lua-static.mjs';
import {prePowerShopSource,powerShopAfter} from './helpers/power-shop-source-inverse.mjs';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
process.on('exit',()=>process.stdout.write('POWER_SHOP_RESOURCE '+JSON.stringify({testProcessMaxRSSKiB:process.resourceUsage().maxRSS})+'\n'));
const hash=s=>createHash('sha256').update(s).digest('hex');
const archive=readFileSync('tests/helpers/power-shop-before-2c85.json.gz');
assert.equal(hash(archive),'9a0e812b775133a4052eaba470bbc6a82eb4b447b5d7cb0f05e4c0bdbb98a52c');
const bytes=gunzipSync(archive);
assert.equal(hash(bytes),'eb41ac2b407423b2f0298f27f07d8f5bed349b9804f144b2b9d8de4ac0d05025');
export const before=JSON.parse(bytes);
assert.equal(before.revision,'2c85bc618f39a4706dbc108eca0ebe5797630081');
for(const entry of Object.values(before.files)){
 assert.equal(hash(entry.source),entry.sha256);
 assert.equal(createHash('sha1').update('blob '+Buffer.byteLength(entry.source)+'\0'+entry.source).digest('hex'),entry.gitBlob);
}
function vm(variant,body,{mutation}={}){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const graphs=[],logs=[],errors=[];let graphBytes=0;
 installLuaGraphObserver(L,'BOUNDARY_GRAPH',(label,graph)=>{graphBytes+=Buffer.byteLength(graph);graphs.push({label,sha256:hash(graph)});});
 lua.lua_pushcfunction(L,L=>{errors.push({call:to_jsstring(lua.lua_tolstring(L,1)),message:to_jsstring(lua.lua_tolstring(L,2))});return 0;});lua.lua_setglobal(L,to_luastring('BOUNDARY_ERROR'));
 lua.lua_pushcfunction(L,L=>{logs.push(to_jsstring(lauxlib.luaL_tolstring(L,1)));return 0;});lua.lua_setglobal(L,to_luastring('print'));
 let prelude=`BOUNDARY_BEFORE=${variant==='before'};package.path='tests/lua/?.lua;src/lua/?.lua;build/lua/?.lua;'..package.path;`;
 if(variant==='before')for(const [path,entry]of Object.entries(before.files))if(path.endsWith('.lua'))
  prelude+=`package.preload[${luaString(path.slice(8,-4))}]=assert(load(${luaString(entry.source)},${luaString('@'+path)}));`;
 if(mutation)prelude+=`package.preload[${luaString(mutation.name)}]=assert(load(${luaString(mutation.source)},${luaString('@src/lua/'+mutation.name+'.lua')}));`;
 const status=lauxlib.luaL_dostring(L,to_luastring(prelude+body));
 const error=status===lua.LUA_OK?null:to_jsstring(lua.lua_tostring(L,-1));lua.lua_close(L);
 return {status,error,graphs,graphBytes,logs,errors};
}
const coldLoad=`
 require('abyss_power_order')
 for _,name in ipairs({'abyss_actor','abyss_combat','abyss_turn_powers','abyss_warrior_strength_cards','abyss_watcher_flow_cards'})do
  assert(package.loaded[name]==nil,'ordering loaded executor: '..name)
 end
`;
test('Power ordering cold load is independent of turn and combat execution',()=>{
 const old=vm('before',coldLoad);assert.notEqual(old.status,0);assert.match(old.error,/ordering loaded executor/);
 const current=vm('after',coldLoad);assert.equal(current.status,0,current.error);
});
const observe=`
 local C=require('abyss_combat');local P=require('abyss_turn_powers');local Shop=require('abyss_shop');local Schedule=require('abyss_power_schedule')
 local function observe(owner,key,stateArgument)
  local original=assert(owner[key])
  owner[key]=function(...)
   local args=table.pack(...);local returned=table.pack(pcall(original,...))
   local observed=returned
   if not returned[1]and type(returned[2])=='string'then
    BOUNDARY_ERROR(key,returned[2])
    -- This unchanged assertion moved by six source lines. Canonicalize only
    -- its diagnostic prefix in the observation; rethrow the original value.
    local line=BOUNDARY_BEFORE and 83 or 77
    local prefix='src/lua/abyss_turn_powers.lua:'..line..': invalid turn Power amount:'
    if key=='prepareStart'and returned[2]:sub(1,#prefix)==prefix then
     observed=table.pack(table.unpack(returned,1,returned.n))
     observed[2]='src/lua/abyss_turn_powers.lua:<amount assertion>: invalid turn Power amount:'..returned[2]:sub(#prefix+1)
    end
   end
   BOUNDARY_GRAPH_WRITE({owner=args[stateArgument or 1],returned=observed},key,true)
   if not returned[1]then error(returned[2],0)end
   return table.unpack(returned,2,returned.n)
  end
 end
 for _,key in ipairs({'prepare','afterPurchase'})do observe(Shop,key)end
 for _,key in ipairs({'prepareStart','onEnergyRecharge','preparePostDraw'})do observe(P,key)end
 for _,key in ipairs({'recordApplied','remove','list','ownerEnd'})do observe(Schedule,key)end
 for _,key in ipairs({'new','startTurn','endTurn'})do if C[key]then observe(C,key)end end
`;
for(const fixture of ['power_schedule','turn_power_plans','shop_complete_source','shop_card_identity'])
 test(`${fixture}: independent old/current VMs retain full state, aliases, RNG and error results`,()=>{
  const body=observe+`dofile(${luaString('tests/lua/'+fixture+'.lua')})`;
  const old=vm('before',body),current=vm('after',body);
  assert.equal(old.status,0,old.error);assert.equal(current.status,0,current.error);
  assert(old.graphs.length>0,'at least one actual state observed');
  assert.deepEqual(current.graphs,old.graphs,JSON.stringify({oldErrors:old.errors,currentErrors:current.errors}));assert.deepEqual(current.logs,old.logs);assert.equal(current.graphBytes,old.graphBytes);
  mkdirSync('build/power-shop',{recursive:true});
  assert.deepEqual(current.errors,old.errors.map(e=>({...e,message:e.call==='prepareStart'?e.message.replace(/^src\/lua\/abyss_turn_powers\.lua:83: invalid turn Power amount:/,'src/lua/abyss_turn_powers.lua:77: invalid turn Power amount:'):e.message})));
  writeFileSync('build/power-shop/'+fixture+'.json',JSON.stringify({fixture,baseline:before.revision,checkpoints:current.graphs,bytesPerSide:current.graphBytes,logs:current.logs,rawErrors:{before:old.errors,after:current.errors}},null,2)+'\n');
 });
test('Power ordering cannot reach an executor through immediate or deferred AST dependencies',()=>{
 const sources=Object.fromEntries(Object.entries(discoverSources()).map(([path,value])=>[path.slice(8,-4),value]));
 const policy=JSON.parse(readFileSync('config/architecture.json','utf8'));
 const roots=['abyss_power_order','abyss_power_schedule','abyss_turn_power_phases'];
 const forbidden=new Set(['abyss_actor','abyss_combat','abyss_turn_powers']);
 function check(graph){
  const seen=new Set(),pending=[...roots];
  while(pending.length){const name=pending.pop();if(seen.has(name))continue;seen.add(name);
   assert(!forbidden.has(name),'ordering reaches executor: '+name);
   for(const edge of graph.edges)if(edge.from===name)pending.push(edge.to);
  }
  assert.equal(graph.edges.filter(e=>e.from==='abyss_turn_power_phases').length,0,'metadata stays a leaf');
 }
 const graph=analyzeSources(sources,policy);assert.deepEqual(graph.errors,[]);check(graph);
 const groups=dependencyCycles(graph.nodes,graph.edges);
 assert.deepEqual(groups.filter(g=>g.members.includes('abyss_power_order')).map(g=>g.members),[['abyss_power_order','abyss_power_schedule']]);
 for(const text of ["local forbidden=require('abyss_turn_powers')\n","local function forbidden()return require('abyss_turn_powers')end\n"]){
  const changed={...sources,abyss_power_schedule:text+sources.abyss_power_schedule};
  assert.throws(()=>check(analyzeSources(changed,policy)),/ordering reaches executor/);
 }
});
test('the metadata leaf main chunk and nested helpers actually enforce CC15',()=>{
 const file='src/lua/abyss_turn_power_phases.lua',source='local function probe()return function()end end';
 const rows=[{file,line:1,column:1,code:'W561',message:'cyclomatic complexity of main chunk is too high (16 > 0)'},
  {file,line:1,column:7,code:'W561',message:"cyclomatic complexity of function 'probe' is too high (16 > 0)"},
  {file,line:1,column:source.indexOf('function()')+1,code:'W561',message:'cyclomatic complexity of function is too high (16 > 0)'}];
 const errors=reviewResponsibilityComplexity(rows,{[file]:source}).errors.filter(e=>e.file===file);
 for(const subject of ['main chunk',"function 'probe'",'function'])assert(errors.some(e=>e.message===`Responsibility complexity 16 exceeds 15: ${subject}`),subject);
});
test('the new source epoch keeps complete old Git sources and freshly authenticates all current owners',()=>{
 const read=p=>readFileSync(p,'utf8');
 for(const path of Object.keys(powerShopAfter)){
  const current=read(path),expected=before.files[path]?.source??null;
  assert.equal(prePowerShopSource(path,current),expected);
  for(const linked of Object.keys(powerShopAfter))for(const bad of ['foreign','missing','throw']){
   let changed=false;
   const readSource=p=>{if(p!==linked||!changed)return read(p);if(bad==='throw')throw Error('fresh sentinel');return bad==='missing'?undefined:read(p)+'-- foreign';};
   assert.equal(prePowerShopSource(path,current,{readSource}),expected);
   changed=true;assert.throws(()=>prePowerShopSource(path,current,{readSource}),/Power\/Shop linked owner/);
  }
  for(const foreign of [expected,current+'-- foreign',null,'']){
   if(foreign===null&&expected===null)continue;
   let reads=0;const readSource=()=>{reads++;throw Error('no foreign permission');};
   assert.equal(prePowerShopSource(path,foreign,{readSource}),foreign);assert.equal(reads,0);
  }
 }
 const path='config/architecture.json',policy=JSON.parse(read(path));
 for(const input of [JSON.stringify(policy),JSON.stringify(policy,null,'\t')])assert.equal(prePowerShopSource(path,input),before.files[path].source);
 for(const input of [read(path).replace('"abyss_turn_power_phases"','"abyss_turn_power_pha\\u0073es"'),read(path).replace('"abyss_turn_power_phases":','"abyss_turn_power_phases":"core","abyss_turn_power_phases":')])
  assert.equal(prePowerShopSource(path,input),input,'escaped/duplicate tokens cannot acquire permission');
});
