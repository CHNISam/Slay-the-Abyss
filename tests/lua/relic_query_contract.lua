-- Input keys only, extracted from the complete six-source 391306af witness.
-- Expected mappings come from independently executed pinned source, never a copied alias oracle.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local aliasInputs={{"Bloody Idol","MutagenicStrength","Necronomicon","Enchiridion","Nilry's Codex","Nloth's Gift","NlothsGift","CultistMask","FaceOfCleric","GremlinMask","NlothsMask","SsserpentHead","FossilizedHelix","Pantograph","SacredBark","White Beast Statue","Old Coin","Frozen Egg 2","Coffee Dripper","Fusion Hammer","NeowsBlessing","Darkstone Periapt","Omamori","CeramicFish","Potion Belt","MealTicket","MawBank","Blood Vial","Bag of Marbles","Orichalcum","Ectoplasm","Strawberry","Pear","Mango","Lee's Waffle","Regal Pillow","Toy Ornithopter","Whetstone","War Paint","Happy Flower","Ancient Tea Set","Art of War","Boot","Akabeko","Pen Nib","Nunchaku","PreservedInsect","Red Skull","Centennial Puzzle","Tiny Chest","Juzu Bracelet","Dream Catcher","WarpedTongs","Spirit Poop","Circlet","TungstenRod","Red Mask","Toxic Egg 2","Molten Egg 2","Snake Skull","DataDisk","Damaru","Mark of the Bloom","Lizard Tail"},{"Bottled Tornado","Sundial","Kunai","Blue Candle","Eternal Feather","StrikeDummy","Singing Bowl","Matryoshka","InkBottle","Ornamental Fan","Bottled Lightning","Gremlin Horn","HornCleat","Letter Opener","Question Card","Bottled Flame","Shuriken","Meat on the Bone","Mummified Hand","Mercury Hourglass","Self Forming Clay","Paper Frog"},{"Ginger","Bird Faced Urn","Unceasing Top","Torii","StoneCalendar","Shovel","WingedGreaves","Thread and Needle","Turnip","Ice Cream","Calipers","Prayer Wheel","Girya","Dead Branch","Du-Vu Doll","Pocketwatch","Incense Burner","Gambling Chip","Peace Pipe","CaptainsWheel","Magic Flower","Charon's Ashes","Champion Belt"},{"Velvet Choker","Runic Dome","Snecko Eye","Pandora's Box","Cursed Key","Busted Crown","Ectoplasm","Tiny House","Philosopher's Stone","Astrolabe","Empty Cage","Runic Pyramid","Calling Bell","Mark of Pain","Runic Cube"},{"Sling","HandDrill","Toolbox","Chemical X","Orrery","DollysMirror","OrangePellets","PrismaticShard","ClockworkSouvenir","Frozen Eye","TheAbacus","Medical Kit","Cauldron","Strange Spoon","Brimstone"}}
local function eq(a,b,label)assert(a==b,'[RELIC_QUERY] '..(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local H,U,R,B,S,P=require('abyss_relic_hooks'),require('abyss_uncommon_relics'),require('abyss_rare_relics'),require('abyss_boss_relics'),require('abyss_shop_relics'),require('abyss_card_pool')
local modules={H,U,R,B,S};local total=0
for index,ids in ipairs(aliasInputs)do
 for _,id in ipairs(ids)do
  local own=table.pack(modules[index].localId(id));eq(own.n,1,'normalizer return arity')
  eq(type(own[1]),'string','alias normalizes to string')
  eq(modules[index].localId(own[1]),own[1],'canonical identity stable')
  print(string.format('RELIC_QUERY_ALIAS %d %q %q %q',index,id,own[1],H.localId(id)));total=total+1
 end
end
eq(total,139,'all five frozen alias input sets')
local family={U,R,B,S};local saved,trace={},{}
for i,mod in ipairs(family)do saved[i]=mod.localId;local stage=i
 mod.localId=function(id)trace[#trace+1]=stage..':'..id;return 'stage'..stage end
end
eq(H.localId('query_probe'),'stage4','ordered composition');eq(table.concat(trace,','),'1:query_probe,2:stage1,3:stage2,4:stage3','exact ordered arguments')
trace={};eq(H.localId('Red Skull'),'red_skull','local alias short circuit');eq(#trace,0,'no family stage on local alias')
for i,mod in ipairs(family)do mod.localId=saved[i]end
print('RELIC_QUERY_COMPOSITION order=uncommon,rare,boss,shop shortCircuit=0')
for i,mod in ipairs(modules)do
 local old=mod.localId;mod.localId=nil;eq(mod.localId,nil,'nil method read');mod.localId=old;eq(mod.localId,old,'ordinary nil restore')
 mod.localId=function(id)return id=='query_probe'and 'query_target'or old(id)end
 if mod.owns then eq(mod.owns({relics={'query_probe'}},'query_target'),i~=5,'owns dispatches according to original namespace')end
 mod.localId=old
end
-- Shop.owns deliberately reads aliases, not its publicly replaceable localId.
local oldAliases,oldLocalId=S.aliases,S.localId
oldAliases.query_probe='query_target';eq(H.localId('query_probe'),'query_target','alias element write visible');oldAliases.query_probe=nil
local replacement={query_probe='query_replacement'};S.aliases=replacement
eq(S.aliases,replacement,'alias table replacement identity');eq(S.localId('query_probe'),'query_replacement');eq(S.owns({relics={'query_probe'}},'query_replacement'),true)
local enumerated=0;for id,value in pairs(S.aliases)do eq(id,'query_probe');eq(value,'query_replacement');enumerated=enumerated+1 end;eq(enumerated,1,'real alias table enumerates')
S.aliases=nil;eq(S.aliases,nil,'alias nil read');S.aliases=oldAliases;eq(S.aliases,oldAliases,'original alias identity restored')
S.localId=function()return 'wrong_normalizer'end;eq(S.owns({relics={'Sling'}},'sling'),true,'Shop owns bypasses localId replacement');S.localId=oldLocalId
print('RELIC_QUERY_ALIAS_TABLE identity,element-write,replacement,nil-restore,pairs PASS')
for _,mod in ipairs({H,U,R,S})do
 local old=mod.owns;mod.owns=nil;eq(mod.owns,nil,'nil owns read');mod.owns=old
 local sentinel={};mod.owns=function()error(sentinel)end;local called,why=pcall(mod.owns,{relics={}},'probe');eq(called,false);eq(why,sentinel,'exact thrown object');mod.owns=old
end
local owns,localId=R.owns,R.localId
R.owns=function()return false end
local player={};eq(R.owns({relics={'Ginger'}},'ginger'),false,'public Rare owns replaced')
eq(R.blockPower({relics={'Ginger'},player=player},player,'weak'),true,'private Rare owns remains original')
R.localId=function()return 'ginger'end;eq(R.blockPower({relics={'query_probe'},player=player},player,'weak'),true,'private owns still dynamically reads localId')
R.localId,R.owns=localId,owns
local old=U.owns;U.owns=function()return true end;eq(U.rewardCardCount({relics={}},3),4,'Uncommon internal public owns remains dynamic');U.owns=old
local old=H.owns;H.owns=function(_,id)return id=='question_card'end;eq(P.rewardCount({relics={}},3),4,'Pool reads public owns each call');H.owns=nil;eq(H.owns,nil);H.owns=old
local old=B.cardRewardCount;B.cardRewardCount=function(_,n)return n+9 end;eq(P.rewardCount({relics={}},3),12,'Pool reads Boss count each call');B.cardRewardCount=nil;eq(B.cardRewardCount,nil);B.cardRewardCount=old
eq(B.owns,nil,'Boss owns is not public');B.owns=function()return false end
eq(B.cardRewardCount({relics={'Busted Crown'}},3),1,'new facade field cannot replace Boss private owns');B.owns=nil
eq(B.cardRewardCount(nil,3),3,'Boss private owns nil-owner semantics')
local old=H.owns;local failure={};H.owns=function()error(failure)end
local called,why=pcall(P.rewardCount,{relics={}},3);eq(called,false);eq(why,failure,'query preserves thrown object');H.owns=old
print('RELIC_QUERY_DYNAMIC reads,nil-restore,private-Rare-owns,thrown-object PASS')
-- Use the real public Run command to inspect its existing adapter snapshot.
local Run,Loss,D=require('abyss_run'),require('abyss_relic_loss'),require('abyss_data')
local run=Run.new(D,'42');local loss,normalize=Loss.lose,H.localId;local inspected=false
Loss.lose=function(staged,id,api)
 inspected=true;eq(api.localId,normalize,'Run takes original function value')
 H.localId=function(key)if key=='late_query_probe'then return 'sling'end;return normalize(key)end
 eq(api.localId('late_query_probe'),'late_query_probe','existing adapter keeps captured function')
 eq(api.definition(staged,'late_query_probe').id,'sling','definition closure still reads live method')
 return true,'query_snapshot'
end
local called,ok,detail=pcall(Run.loseRelic,run,'query_probe');Loss.lose,H.localId=loss,normalize
assert(called,ok);eq(ok,true);eq(detail,'query_snapshot');eq(inspected,true)
print('RELIC_QUERY_RUN_SNAPSHOT function-value/live-definition PASS')
print('RELIC_QUERY_CONTRACT_PASS 139 aliases')
