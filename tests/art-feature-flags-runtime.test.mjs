import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const source=readFileSync('src/lua/abyss_ui.lua','utf8');
function vm(code){const L=lauxlib.luaL_newstate();try {lualib.luaL_openlibs(L);
 const result=lauxlib.luaL_dostring(L,to_luastring(`ENTRY=${JSON.stringify(source)}\n${code}`));
 assert.equal(result,lua.LUA_OK,result===lua.LUA_OK?'':to_jsstring(lua.lua_tostring(L,-1)));
 } finally {lua.lua_close(L);}}
const setup=`
local modules,requested,options,updates,configured,cleared,views,dead,released,params,presentation,backgrounds,viewDeaths,cardDeaths
local flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false}
local function snapshot()local f={};for k,v in pairs(flags)do f[k]=v end;return {schemaVersion=2,flags=f}end
local function start(config,broken,previous)
 requested={};updates=false;configured=0;cleared=0;views=0;dead=0;released=0;params={};options=nil
 backgrounds={};viewDeaths=0;cardDeaths=0
 local function owner()return {release=function()released=released+1 end,onEngineDestroy=function()dead=dead+1 end}end
 modules={abyss_monster_actor_binding={templateIndex=31,containerTemplateIndex=32,powerTemplateIndex=33,enabled=true},abyss_art_features=config,abyss_data={},abyss_presentation={},abyss_theme={sound={}},
  abyss_viewport={apply=function()return {GetChild=function()error('all-off has no custom hosts')end}end},
  abyss_narrative={build={}},abyss_game_ui={new=function(_,_,p,_,o)presentation=p;options=o;views=views+1;return {
   resize=function()end,update=function()end,disable=function()end,
   onEngineDestroy=function()viewDeaths=viewDeaths+1;for _,art in ipairs(backgrounds)do art:onEngineDestroy()end end}end},
  abyss_menu_background={new=function(_,_,factory,_,config)
   assert(type(factory)=='function' and config.standalone==true,'egg must use independent background templates')
   local art=owner();backgrounds[#backgrounds+1]=art;return art end},abyss_traveler_portraits={new=function(_,_,f)
   assert(f.selectionAvatar==flags.selectionAvatar and f.battlePortrait==flags.battlePortrait);return owner()end,
   createController=function()error('entry mock must not create geometry')end},
  abyss_card_art_runtime={configure=function(v)if v then configured=configured+1 else cleared=cleared+1 end end,
   clear=function()cleared=cleared+1 end,update=function()end,onEngineDestroy=function()cardDeaths=cardDeaths+1 end},
  abyss_ready_card_binding={enabled=true,imageTemplateIndex=1234,containerTemplateIndex=5678},
  abyss_ready_card_assets={strike={runtime=true,cardId='strike'}},abyss_card_display={bindNativeAssets=function(_,a)assert(a.strike)end}}
 if broken then broken(modules)end
 package.loaded.abyss_card_art_runtime=previous and modules.abyss_card_art_runtime or nil
 require=function(name)requested[name]=(requested[name]or 0)+1;assert(modules[name]~=nil,'missing '..name);return modules[name]end
 game={GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return false end,
  InstantiateClientUIControl=function()error('unexpected custom creation')end,DestroyClientUIControl=function()end}
 Enum={CursorEventType={CursorClick=1},ImageSource={StaticReference=1}};Color=function()end
 script={object={},EnableUpdate=function(_,v)updates=v end,GetParam=function(_,p)params[#params+1]=p;return true end}
 assert(load(ENTRY))();OnStart();assert(updates and views==1,'art availability must not disable GameUI')
 assert(#params==1 and params[1]=='nativeBgmEnabled','art must not expose player parameters')
 return options
end
local function off()
 assert(not options.background and not options.portraits and not options.cardArt and not options.createEasterEggArt and not options.nativeMonsterArtEnabled)
 for _,n in ipairs({'abyss_menu_background','abyss_traveler_portraits','abyss_ready_card_assets','abyss_ready_card_binding'})do
  assert(not requested[n],'disabled art eagerly loaded '..n)
 end
 assert(configured==0)
end
`;
test('entry snapshots all thirty-two release combinations without requiring disabled controllers or card data',()=>vm(setup+`
for mask=0,31 do
 flags.cards=mask%2==1;flags.menuBackground=math.floor(mask/2)%2==1
 flags.selectionAvatar=math.floor(mask/4)%2==1;flags.battlePortrait=math.floor(mask/8)%2==1;flags.monsters=math.floor(mask/16)%2==1
 start(snapshot())
 assert(options.background==nil,'custom art must never bind as an eager page background')
 assert((type(options.createEasterEggArt)=='function')==flags.menuBackground)
 assert(options.nativeMonsterArtEnabled==flags.monsters)
 -- cards also owns the low-poly select fan through the portrait owner.
 assert((options.portraits~=nil)==(flags.selectionAvatar or flags.battlePortrait or flags.cards))
 assert((options.cardArt~=nil)==flags.cards and configured==(flags.cards and 1 or 0))
 assert((requested.abyss_ready_card_assets~=nil)==flags.cards)
 assert((requested.abyss_ready_card_binding~=nil)==flags.cards)
 assert(requested.abyss_menu_background==nil and #backgrounds==0,'victory art loaded before an explicit action')
 assert((requested.abyss_traveler_portraits~=nil)==(flags.selectionAvatar or flags.battlePortrait or flags.cards))
 if mask==0 then off()end
 local calls=requested.abyss_art_features;modules.abyss_art_features=snapshot();OnUpdate(.1)
 assert(requested.abyss_art_features==calls,'config must not poll')
 assert(requested.abyss_menu_background==nil and #backgrounds==0,'update eagerly loaded victory art')
 if flags.menuBackground then
  assert(type(options.createEasterEggArt())=='table' and #backgrounds==1,'explicit lazy factory did not construct art')
  assert(requested.abyss_menu_background==1 and requested.abyss_traveler_portraits~=nil)
 end
 OnDestroy();assert(not updates and dead==(flags.menuBackground and 1 or 0)+((flags.selectionAvatar or flags.battlePortrait or flags.cards) and 1 or 0))
 assert(viewDeaths==1 and cardDeaths==(flags.cards and 1 or 0),'entry must retire view and enabled card runtime')
end
`));
test('missing and malformed configuration fail closed and default world retires old card runtime',()=>vm(setup+`
start(nil,nil,true);off();assert(cleared==1,'default world must release old custom card ownership')
for _,bad in ipairs({true,'true',{}, {schemaVersion=1,flags=flags}, {schemaVersion=3,flags=flags},{schemaVersion=2,flags={cards=true}},
 {schemaVersion=1,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false}},
 {schemaVersion=2,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false}},
 {schemaVersion=2,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters='true'}},
 {schemaVersion=2,flags={cards='true',menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false}},
 {schemaVersion=2,flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false,unknown=true}},
 {schemaVersion=2,flags={cards=true,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false},extra=true}})do
 start(bad);off();OnDestroy()
end
`));
test('enabled missing binding or payload cannot stop official UI or activate the dynamic runtime',()=>vm(setup+`
flags.cards=true
for _,breakIt in ipairs({
 function(m)m.abyss_ready_card_binding=nil end,function(m)m.abyss_ready_card_binding={}end,
 function(m)m.abyss_ready_card_binding.enabled='true'end,function(m)m.abyss_ready_card_binding.imageTemplateIndex=0 end,
 function(m)m.abyss_ready_card_binding.enabled=false end,function(m)m.abyss_ready_card_assets=nil end,
 function(m)m.abyss_ready_card_assets=true end})do
 start(snapshot(),breakIt);assert(not options.cardArt and configured==0);OnUpdate(.1);OnDestroy()
end
flags.menuBackground=true;flags.selectionAvatar=true;flags.battlePortrait=true
start(snapshot(),function(m)m.abyss_menu_background=nil;m.abyss_traveler_portraits=nil end)
assert(not options.background and not options.portraits and options.cardArt)
assert(type(options.createEasterEggArt)=='function' and #backgrounds==0,'broken optional art must remain lazy')
assert(not pcall(options.createEasterEggArt),'missing enabled art must fail at the explicit lazy boundary')
OnDestroy();assert(viewDeaths==1 and dead==0)
`));

test('real native entry starts without custom hosts, keeps official selection usable and loads no custom asset data',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const result=runLua('tests/lua/support/art_feature_flags_entry.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/ART_FEATURE_FLAGS_ENTRY_PASS/);
});


test('disabled or invalid snapshot suppresses embedded legacy static art without mutating cached presentation',()=>vm(setup+`
local embedded={strike={name='Strike',nativeArt={slots={{image=100001}},capacity=1}}}
local function staticCandidate(m)m.abyss_presentation=embedded;m.abyss_ready_card_binding.enabled=false end
start(snapshot(),staticCandidate);off()
assert(presentation.strike.nativeArt==nil and presentation.strike.name=='Strike','disabled static art reached the card renderer')
assert(embedded.strike.nativeArt~=nil,'candidate snapshot must not mutate cached source presentation')
start(nil,staticCandidate);assert(presentation.strike.nativeArt==nil)
start({schemaVersion=0,flags=flags},staticCandidate);assert(presentation.strike.nativeArt==nil)
flags.cards=true;start(snapshot(),staticCandidate)
assert(presentation.strike.nativeArt==embedded.strike.nativeArt and configured==0,'explicit legacy static route must remain available')
`));


test('native custom require without the standard package library still resets old art and starts official UI',()=>vm(setup+`
start(snapshot());local standardPackage=package;package=nil
assert(load(ENTRY))();OnStart();assert(updates and views==2,'native startup must not depend on package.loaded')
assert(cleared==2,'each world resets the shared runtime');off();OnDestroy();package=standardPackage
`));
