// Independent review probe retained as a regression: each trace position may
// throw the same sentinel, so helper extraction cannot reorder observable reads.
import {readFileSync} from 'node:fs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const old=readFileSync('tests/fixtures/card-capability-responsibilities-before.lua','utf8'),current=readFileSync('src/lua/abyss_card_capability.lua','utf8');
const quote=luaString;
const program=`
local sources={${quote(old)},${quote(current)}}
local results={}
for version,source in ipairs(sources) do
 local all={}
 for scenario=1,12 do for stop=0,50 do
  local trace={};local fault={};local marker={};local n=0;local armed=false
  local function tick(label) trace[#trace+1]=label;n=n+1;if armed and n==stop then error(fault,0) end end
  local function proxy(label,fields) return setmetatable({},{__index=function(_,key)tick(label..'.'..key);return fields[key]end,__len=function()tick(label..'.len');return 1 end}) end
  local raw=proxy('raw',{id='test'})
  local effect=proxy('effect',{op='originalV4',raw=raw})
  local effects=proxy('effects',{[1]=effect})
  local fields={id='test',type='skill',cost=1,effects={}}
  if scenario==1 then fields.originalV4=raw;fields.effects=effects
  elseif scenario==2 then fields.condition='draw_pile_empty';fields.experimental=true;fields.costMode='all_energy';fields.cost=-1
  elseif scenario==3 then fields.type='curse'
  elseif scenario==4 then fields.watcherFinal=true
  elseif scenario==5 then fields.type='status';fields.id='wound';fields.cost=-2
  elseif scenario==6 then fields.type='status';fields.id='burn';fields.cost=-2;fields.burnDamage=4
  elseif scenario==7 then fields.type='status';fields.id='slimed';fields.exhaust=true
  elseif scenario==8 then fields.type='status';fields.id='void';fields.ethereal=true;fields.cost=-2
  elseif scenario==9 then fields.id='deus_ex_machina';fields.cost=-2;fields.onDrawFinal=false
  elseif scenario==10 then fields.condition='only_attacks_in_hand';fields.costMode='all_energy'
  elseif scenario==11 then fields.type='status';fields.id='burn';fields.cost=-2
  elseif scenario==12 then fields.type='power' end
  local card=proxy('card',fields)
  local modules={}
  for _,name in ipairs({'abyss_effects','abyss_curses','abyss_original_v4','abyss_watcher_final_cards'}) do
    modules[name]=setmetatable({},{__index=function(_,key) tick(name..'.'..key);return function(value)tick(name..'.call');return marker,false,nil,7 end end})
  end
  local env=setmetatable({require=function(name)tick('require.'..name);return modules[name]end},{__index=_G})
  local module=assert(load(source,'source','t',env))()
  trace={};n=0;armed=true
  local result=table.pack(pcall(module.isImplemented,card))
  local out={tostring(scenario),tostring(stop),table.concat(trace,','),tostring(result.n)}
  for i=1,result.n do out[#out+1]=result[i]==marker and 'marker' or result[i]==fault and 'fault' or tostring(result[i]) end
  all[#all+1]=table.concat(out,'|')
 end end
 results[version]=all
end
assert(#results[1]==612)
for i=1,#results[1] do assert(results[1][i]==results[2][i],i..'\\n'..results[1][i]..'\\n'..results[2][i])end
return #results[1]
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const status=lauxlib.luaL_dostring(L,to_luastring(program));if(status!==0)throw Error(to_jsstring(lua.lua_tostring(L,-1)));console.log('PASS paired trace/error/arity probes:',lua.lua_tonumber(L,-1));lua.lua_close(L);
