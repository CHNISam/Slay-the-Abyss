-- Run-only native RED75 compatibility fingerprints, not card implementations.
-- Frozen data/cards.json (LF normalized) SHA256: 5f66a25e6a629861c8c6e005dd47b8d9372246cb4a667dee3b33d52e800514d3
-- Approved native data changes require source review and an explicit lock update.
-- Names, wording and caller extension graphs do not participate. No caller is cached.
local M={}
local fields={'condition','cost','costMode','effects','ethereal','exhaust','exhaustEnergy','healing','innate','rarity','repeatable','sourceId','strengthMultiplier','strikeBonus','strikeTag','target','type','upgrade'}
local signatures={
 strike='6de85f3c3ecf40d4',
 defend='7293733e3e85430d',
 bash='2b4500737f583c37',
 anger='0d4f51a61658aa34',
 armaments='62599c4927512f12',
 body_slam='595b212f6809ed69',
 clash='34c65c23450ff064',
 cleave='5f5f319b10dea357',
 clothesline='1e27f55f5203a514',
 flex='73640e0032e9d830',
 havoc='10a689436c425e46',
 headbutt='3c2de71b74b03912',
 heavy_blade='4bd1b5cd28f09d15',
 iron_wave='2f27707952380eb4',
 perfected_strike='6954a1a46b4853df',
 pommel_strike='379a6b6e4758c9a2',
 shrug_it_off='4562f8607321d88b',
 sword_boomerang='175a547079b993b2',
 thunderclap='0627e08827234812',
 true_grit='0adc7cc770bf024f',
 twin_strike='126cef932b647223',
 warcry='0c1e214823322bd3',
 wild_strike='00758b475299c372',
 battle_trance='39439d763644208d',
 blood_for_blood='1e84e2c376b35612',
 bloodletting='332a3298317ca8fe',
 burning_pact='6948b77442cacf1d',
 carnage='21c75e903e373dc8',
 combust='1eeb18b26451e39c',
 dark_embrace='6c77d9d15c1ecc53',
 disarm='609b99302dac9a47',
 dropkick='683c75eb4a3ef8a7',
 dual_wield='4c7783f0565ca596',
 entrench='4fa03b1f253c7d4f',
 evolve='334ed6e356130ef3',
 feel_no_pain='161caa0f42974381',
 fire_breathing='17c47ddd716844fa',
 flame_barrier='39c62b0a4ec8a09f',
 ghostly_armor='4cf86f2b36da92cb',
 hemokinesis='26d26e364e3dd82d',
 infernal_blade='43a0bb710552a3be',
 inflame='304b1a1a6d433bd6',
 intimidate='3ae3592e7c4482b9',
 metallicize='7e2854b1228c739d',
 power_through='2c0a1d7513d1fb72',
 pummel='517437ff25d9f301',
 rage='79d0c2fa266f0a25',
 rampage='7931b098620a1576',
 reckless_charge='03d3064b08ab83d3',
 rupture='188aaec131f22ed3',
 searing_blow='0f820c363bbb403d',
 second_wind='3fda7f407e755adf',
 seeing_red='061916a072dfd065',
 sentinel='2e4c1308601b8a96',
 sever_soul='191bdb3944fefdb5',
 shockwave='225bebe972cf049c',
 spot_weakness='1ea893ad00d53070',
 uppercut='6f26c13e75cb7b86',
 whirlwind='1160bc434a479a93',
 barricade='05dc924544682abc',
 berserk='5010cf1a177da44b',
 bludgeon='242d4e486f0c6ad7',
 brutality='14055f6b0e6d5fce',
 corruption='121172c732da07c6',
 demon_form='6ee71632094b5bf3',
 double_tap='2b466311750079ee',
 exhume='754d399a3a8d98e8',
 feed='1a40c8c171a0965b',
 fiend_fire='2a6e846a4f37d89b',
 immolate='4f024c4327f164e7',
 impervious='50b2a8c366d43ef7',
 juggernaut='47964c7f202552a3',
 limit_break='16e32cd21453cbf5',
 offering='1ab8601253b63a37',
 reaper='0004ebc146689dda',
}
local supported={};for _,key in ipairs(fields)do supported[key]=true end
local function pack(value)
 local kind=type(value)
 if kind=='string'then return 's'..#value..':'..value end
 if kind=='number'then return 'n'..string.format('%.17g',value)..';'end
 if kind=='boolean'then return value and 't'or 'f'end
 assert(kind=='table','invalid native red semantic field')
 local keys={};for key in pairs(value)do keys[#keys+1]=key end
 table.sort(keys,function(a,b)if type(a)~=type(b)then return type(a)=='number'end;return a<b end)
 local out={'{'};for _,key in ipairs(keys)do out[#out+1]=pack(key);out[#out+1]=pack(value[key])end
 out[#out+1]='}';return table.concat(out)
end
function M.fingerprint(card)
 local semantic={};for _,key in ipairs(fields)do if card[key]~=nil then semantic[key]=card[key]end end
 local value=pack(semantic);local first,second=1.0,7.0
 for i=1,#value do local byte=value:byte(i)
  first=(first*31.0+byte)%2147483647;second=(second*131.0+byte)%2147483629
 end
 return string.format('%08x%08x',first,second)
end
function M.isRed(id)return signatures[id]~=nil end
function M.matches(card,extraRuleKeys)
 for key in pairs(extraRuleKeys or{})do if not supported[key]and card[key]~=nil then return false end end
 return signatures[card.id]==M.fingerprint(card)
end
return M
