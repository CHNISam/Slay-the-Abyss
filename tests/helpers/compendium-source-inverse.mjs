// Exact test-only outer projection of the reviewed read-only compendium slice.
// Historical hashes and archived sources are not refreshed.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {architectureSourceFormat} from './architecture-source-format.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
const read=p=>normalize(readFileSync(new URL('../../'+p,import.meta.url),'utf8'));
const owners={
 'src/lua/abyss_game_ui.lua':'165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933',
 'src/lua/abyss_compendium_catalog.lua':'d6594b4d276ab2f02983429227102282e51565acceca266c8971adfa9e32706a',
 'src/lua/abyss_relic_text.lua':'b0c64b6f06ece16b2f3ddbc39d2b0e6ba0f78b2b67c4836c4829ded94c69fe79',
 'src/lua/abyss_node_ui_faces.lua':'0ab8654addf095b7c00980aab325fe12f496b109f47714f78abfab8adacdfbd4',
};
const oldRelicBody="        if id=='membership_card' then return '所有商店商品半价。' end\n        if id=='courier' then return '商店商品八折，购买后补货。' end\n        if id=='smiling_mask' then return '商店删牌服务固定为50金币。' end\n        local definition = find(data.relics.relics, id)\n        if not definition then return \"\" end\n        if definition.description then return definition.description end\n        local parts\n        local function describeRelicEffects()\n            parts = {}\n            for _, effect in ipairs(definition.effects or {}) do\n                local value = number(effect.value)\n                if effect.op == \"heal\" then parts[#parts + 1] = \"回复 \" .. value .. \" 点生命\"\n                elseif effect.op == \"block\" then parts[#parts + 1] = \"获得 \" .. value .. \" 点格挡\"\n                elseif effect.op == \"draw\" then parts[#parts + 1] = \"抽 \" .. value .. \" 张牌\"\n                elseif effect.op == \"energy\" then parts[#parts + 1] = \"获得 \" .. value .. \" 点能量\"\n                elseif effect.op == \"gainStatus\" then\n                    local status = find(data.statuses.statuses, effect.status)\n                    parts[#parts + 1] = \"获得 \" .. value .. \" 层\" .. (status and status.name or effect.status)\n                end\n            end\n        end\n        describeRelicEffects()\n        if #parts == 0 then return \"\" end\n        return (triggers[definition.trigger] or \"\") .. table.concat(parts, \"，\") .. \"。\"";
// Only the two reviewed M9 core registrations are outside this UI proof.
// Keep the original whole-file identities and every detached owner check.
function preM9ProtocolRegistrations(source){
 const {formatted,tokensEqual}=architectureSourceFormat('config/architecture.json',source);
 if(!tokensEqual||hash(formatted)!=='e943e856195cb00a904d11a57fa49332df69a2101dae79cb7b47718b6c54bf0b')return source;
 const live=read('config/architecture.json');
 if(hash(live)!=='3cc15d6f573fa5a5c637c2d2a4ef9086f444bb761a64ee1e6aef80dad40d0cc5')return source;
 const hunk=',\n    "abyss_combat_native_play": "core",\n    "abyss_combat_queued_play": "core"';
 assert.equal(live.split(hunk).length,2,'one complete reviewed M9 registration block');
 const previous=live.replace(hunk,'');
 assert.equal(hash(previous),'037ff11d8894f6f68b0abb68420b74c05c7a38f2a4e5db58853930d56adc4e55','complete pre-M9 architecture');
 return previous;
}
// Only the complete reviewed Runtime host may enter the old compendium proof.
// Apply this equally to explicit inputs and each fresh detached-owner read.
function preRuntimeGameUi(path,source){
 if(path!=='src/lua/abyss_game_ui.lua'||hash(source)!=='4ab3ec613f79b1507c7c529c57547d42f93fa7eafc89aeb9afb1b8c64ab34c25')return source;
 const call='            suspendBattle(run,deckOpen,potionOpen),self.mode == "battle")';
 const comment='        -- Paint after every page visibility setter, which may re-enter state.\n';
 assert.equal(source.split(call).length,2,'one complete reviewed Runtime activation call');
 assert.equal(source.split(comment).length,2,'one complete reviewed Runtime paint comment');
 const previous=source.replace(call,'            suspendBattle(run,deckOpen,potionOpen))').replace(comment,'');
 assert.equal(hash(previous),owners[path],'complete pre-Runtime compendium host');
 return previous;
}
export function preCompendiumSource(path,source,overrides={}){
 if(typeof source!=='string')return source;
 const current=preRuntimeGameUi(path,normalize(source));let previous;
 if(path==='config/architecture.json'){
  try{
   const {formatted,tokensEqual}=architectureSourceFormat(path,preM9ProtocolRegistrations(current));
   if(!tokensEqual||hash(formatted)!=='33b50b45093ae6d2fcc23f81784f338541aa8c1daba0ba4f431dba2a3ffc4b20')return source;
  }catch{return source;}
  const live=preM9ProtocolRegistrations(read(path));
  if(hash(live)!=='037ff11d8894f6f68b0abb68420b74c05c7a38f2a4e5db58853930d56adc4e55')return source;
  previous=live.replace('    "abyss_compendium_catalog": "ui",\n    "abyss_relic_text": "core",\n','');
  assert.equal(hash(previous),'8c6e10716cb4ba38d49f9164d6349e8eb2a80ca13b6c364f69181a056b7bfdbf','complete pre-compendium architecture');
 }else if(path==='src/lua/abyss_game_ui.lua'){
  if(hash(current)!==owners[path])return source;
  previous=current.replace("    -- Read-only Production data service; no navigation or eager catalogue build.\n    function self.productionCompendium(_)\n        return require('abyss_compendium_catalog').new(data,presentation)\n    end\n",'');
  assert.equal(hash(previous),'7beb2208633cef99b31bdae7d0729b31d9776724df2a6cbd532683eaf4b60c46','complete pre-compendium host API');
 }else if(path==='src/lua/abyss_node_ui_faces.lua'){
  if(hash(current)!==owners[path])return source;
  previous=current.replace('local function find(entries, id, key)',
   'local triggers = { combat_start = "战斗开始时，", combat_end = "战斗结束时，" }\nlocal function find(entries, id, key)')
   .replace("        return require('abyss_relic_text').describe(data,id)",oldRelicBody);
  assert.equal(hash(previous),'285281e48bcd5dfeb20bc03c8c2be526eda57e169689ba2e09b10d5babd3986a','complete pre-compendium relic descriptions');
 }else return source;
 for(const [owner,expected]of Object.entries(owners))
  assert.equal(hash(preRuntimeGameUi(owner,Object.hasOwn(overrides,owner)?normalize(overrides[owner]):read(owner))),expected,'reviewed compendium owner: '+owner);
 return previous;
}
