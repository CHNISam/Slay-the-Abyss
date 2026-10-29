import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
// Exact TASK-76-only inverse, before approved UI/PostNode source bindings.
// Historical and approved-UI complete witnesses stay explicit; unknown/partial sources are untouched
// for the existing strict guards to reject. No runtime or frozen archive changes.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
const hash=value=>createHash('sha256').update(value).digest('hex');
// Additive exact port layer: recover accepted PR311 modules, then let its
// unchanged frozen composition guard validate every responsibility module.
const moduleBytes=readFileSync(new URL('../fixtures/task76-battle-modules-layer.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(moduleBytes),'19f7e4f24760ea8e2a1b2b7c686461e9320beef932afe20505da46b4a90b6e8f','complete TASK-76 Battle module port identity');
export const task76BattleModuleLayer=JSON.parse(moduleBytes);
function beforeBattleModule(path,source){
  const binding=task76BattleModuleLayer.files[path];
  if(!binding||hash(source)!==binding.afterSha256)return source;
  const lines=source.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact TASK-76 Battle module hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const before=lines.join('\n');
  assert.equal(hash(before),binding.beforeSha256,'complete accepted PR311 module recovered: '+path);
  return before;
}
const sources={
  '676abfb20f92539b4af8ed2692388d9d2fbb29176d1069931e3afb0926211cfa':{
    path:'src/lua/abyss_battle_ui.lua',before:'3ad8ad013a4bcd67d29f4dcee30093819725088d78b9d53681df161d46de7e06',potion:'usePotion'},
  '067b6761d5f02477ec2aeb848b2a00eb2b4191517d30096f7cb8dc84e3f0b382':{
    path:'src/lua/abyss_battle_ui.lua',before:'a1d68a1fcba74fff54fb22cb4641cd400e4c76e2d3a7e22d69e352efeb8e7d91',potion:'openPotionMenu',adapter:true},
  'c530888e8afe4c98120fa51b459b1724c7be93fa76f48334ac368031806e08bd':{
    path:'src/lua/abyss_battle_potion_popup.lua',before:'d50f03654abd678719f610bce920f67c5b7bc45656103231fae04f3c3761ceba',popup:true},
  '6adf9566320c60e8b68fb8854ccbf9dffb0eb34f7510d5a32309d4a3461d7590':{
    path:'tests/lua/support/battle_ui_cases.lua',before:'874ad3cf102493953104fe3d556e6839b5599a249d37679b5a2fad862517375d',fixture:true},
};
const fixtureEdits=[["    click(\"enemy1\") -- queued release click must never select or play a target\n", "    local cancelledTarget=ui.target\n    event(\"enemy1\",\"click\",stage.children.enemy1.x,stage.children.enemy1.y,0) -- queued same-origin release click\n    assert(not ui.info and not ui.gesture and ui.selected==nil and ui.carry==nil\n        and ui.target==cancelledTarget and battle.energy==energy and #battle.hand==1 and battle.enemies[2].hp==hp2,\n        'queued touch0 Click must remain inert rather than open details')\n"]];
const popupEdits=[["                if ready()then held={selection=owner.potionMenu,generation=popup.generation,touch=event and event.touchId}end\n", "                if ready()then\n                    if actions.pointerDown then actions.pointerDown(event)end\n                    held={selection=owner.potionMenu,generation=popup.generation,touch=event and event.touchId}\n                end\n"], ["            return act(name)\n", "            if actions.pointerClick and not actions.pointerClick(event)then return false end\n            return act(name)\n"]];
const adapter="        pointerDown=function(event)\n            if self.active and not self.busy and not self.gesture then\n                if event and event.touchId==releasedDragTouch then releasedDragTouch=nil end\n                self.suppressClick=false\n            end\n        end,\n        pointerClick=function(event)\n            return not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture\n        end,\n";
export function preCardDragClickSource(path,source){
  if(Object.hasOwn(task76BattleModuleLayer.files,path)||['src/lua/abyss_battle_ui.lua','src/lua/abyss_battle_potion_popup.lua','tests/lua/support/battle_ui_cases.lua'].includes(path))source=preAcceptedPr323Source(path,source);
  if(source===null)return source;
  source=beforeBattleModule(path,source.replaceAll('\r\n','\n'));
  const binding=sources[hash(source)];
  if(!binding || binding.path!==path)return source;
  const edits=binding.popup?popupEdits:binding.fixture?fixtureEdits:[
    ["    local cardInputs, pointerObserved = {}, false\n","    local cardInputs, pointerObserved, releasedDragTouch = {}, false, nil\n"],
    ["        self.help=nil\n        if not self.gesture then self.suppressClick = false end\n","        self.help=nil\n        if self.active and not self.busy and not self.gesture and event and event.touchId == releasedDragTouch then\n            releasedDragTouch = nil -- a new physical sequence owns this touch again\n        end\n        if not self.gesture then self.suppressClick = false end\n"],
    ["                self.gesture, self.selected, self.hover, self.handHover = nil, nil, nil, nil\n","                releasedDragTouch = g.touch\n                self.gesture, self.selected, self.hover, self.handHover, self.suppressClick = nil, nil, nil, nil, g\n"],
    ["        self.suppressClick,self.selected = true,action ~= 'cancel' and g.uid or nil\n","        -- Keep the trailing Click bound to this drag, not a persistent global lock.\n        releasedDragTouch = g.touch\n        self.suppressClick,self.selected = g,action ~= 'cancel' and g.uid or nil\n"],
    ["    local function listen(control, fn, input)\n","    -- Click-only controls must not inherit the latest completed drag's named\n    -- touch, even after an independent action. A fresh Down retires that origin.\n    -- Anonymous origins consume one ambiguous Click without a permanent lock.\n    local function consumeReleasedDragClick(event)\n        if not self.active or self.busy or self.gesture then return false end\n        local touch = event and event.touchId\n        if touch ~= nil and touch == releasedDragTouch then return true end\n        local g = self.suppressClick\n        if type(g) ~= 'table' then return false end\n        self.suppressClick = nil\n        return g.touch == touch\n    end\n    local function listen(control, fn, input)\n"],
    ["if not self.suppressClick and not self.gesture then return fn(event) end","if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return fn(event) end"],
    [`if not self.suppressClick and not self.gesture then return self:${binding.potion}(slot) end`,`if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return self:${binding.potion}(slot) end`],
    ["if not self.suppressClick and not self.gesture then return chooseEnemy() end","if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return chooseEnemy() end"]
  ];
  for(const[before,after]of edits){
    const count=after.endsWith('return fn(event) end')?2:1;
    assert.equal(source.split(after).length,count+1,'exact TASK-76 drag suppression hunks');
    source=source.replaceAll(after,before);
  }
  if(binding.adapter){
    assert.equal(source.split(adapter).length,2,'exact TASK-76 popup pointer adapter');
    source=source.replace(adapter,'');
  }
  assert.equal(hash(source),binding.before,'complete pre-TASK-76 source recovered');
  return source;
}

function editsFor(binding){
  return binding.popup?popupEdits:binding.fixture?fixtureEdits:[
    ["    local cardInputs, pointerObserved = {}, false\n","    local cardInputs, pointerObserved, releasedDragTouch = {}, false, nil\n"],
    ["        self.help=nil\n        if not self.gesture then self.suppressClick = false end\n","        self.help=nil\n        if self.active and not self.busy and not self.gesture and event and event.touchId == releasedDragTouch then\n            releasedDragTouch = nil -- a new physical sequence owns this touch again\n        end\n        if not self.gesture then self.suppressClick = false end\n"],
    ["                self.gesture, self.selected, self.hover, self.handHover = nil, nil, nil, nil\n","                releasedDragTouch = g.touch\n                self.gesture, self.selected, self.hover, self.handHover, self.suppressClick = nil, nil, nil, nil, g\n"],
    ["        self.suppressClick,self.selected = true,action ~= 'cancel' and g.uid or nil\n","        -- Keep the trailing Click bound to this drag, not a persistent global lock.\n        releasedDragTouch = g.touch\n        self.suppressClick,self.selected = g,action ~= 'cancel' and g.uid or nil\n"],
    ["    local function listen(control, fn, input)\n","    -- Click-only controls must not inherit the latest completed drag's named\n    -- touch, even after an independent action. A fresh Down retires that origin.\n    -- Anonymous origins consume one ambiguous Click without a permanent lock.\n    local function consumeReleasedDragClick(event)\n        if not self.active or self.busy or self.gesture then return false end\n        local touch = event and event.touchId\n        if touch ~= nil and touch == releasedDragTouch then return true end\n        local g = self.suppressClick\n        if type(g) ~= 'table' then return false end\n        self.suppressClick = nil\n        return g.touch == touch\n    end\n    local function listen(control, fn, input)\n"],
    ["if not self.suppressClick and not self.gesture then return fn(event) end","if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return fn(event) end"],
    [`if not self.suppressClick and not self.gesture then return self:${binding.potion}(slot) end`,`if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return self:${binding.potion}(slot) end`],
    ["if not self.suppressClick and not self.gesture then return chooseEnemy() end","if not consumeReleasedDragClick(event) and not self.suppressClick and not self.gesture then return chooseEnemy() end"]
  ];
}
export function postApprovedCardDragClickSource(source){
  source=source.replaceAll('\r\n','\n');
  const [after,binding]=Object.entries(sources).find(([,b])=>b.adapter&&b.before===hash(source))||[];
  assert.ok(binding,'only the complete approved monolith may gain the reviewed TASK-76 layer');
  for(const[before,next]of editsFor(binding)){
    const count=next.endsWith('return fn(event) end')?2:1;
    assert.equal(source.split(before).length,count+1,'exact TASK-76 forward hunk');
    source=source.replaceAll(before,next);
  }
  const anchor="    potionPopup=PotionPopup.new(stage:GetChild('potionHelp'):GetChild('potionPopup'),self,platform,clickEvent,{\n";
  assert.equal(source.split(anchor).length,2,'exact approved popup adapter anchor');
  source=source.replace(anchor,anchor+adapter);
  assert.equal(hash(source),after,'complete reviewed TASK-76 monolith reconstructed');
  return source;
}
