-- Actual configured-source selection; controlled engine doubles, not device evidence.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Catalog,Original,C=require('abyss_run_card_catalog'),require('abyss_original_v4_profiles'),require('abyss_combat')
local Run=require('abyss_run')
local count=0
local function unchanged(root)
 local saved={}
 local function visit(value)
  if type(value)~='table'or saved[value]then return end
  local fields={};saved[value]=fields
  for key,entry in pairs(value)do fields[key]=entry;visit(key);visit(entry)end
 end
 visit(root)
 return function()
  for object,fields in pairs(saved)do
   for key,value in pairs(fields)do assert(object[key]==value,'configured source/selection edge changed')end
   for key in pairs(object)do assert(fields[key]~=nil,'configured source/selection gained an edge')end
  end
 end
end
local function fixture(source,profile)
 local focus,samples=nil,0
 local api={events={Confirm='confirm',Cancel='cancel',Focus='focus'},directions={Left='left',Right='right'},
  modes={Specified='specified'},getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end}
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=F.GameUI.new(root,source,F.Presentation,'click',{campaign=true,campaignProfile=profile or 'competition-two-act',
  imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,controllerApi=api,
  newSeed=function()samples=samples+1;return 3 end})
 assert(ui:start())
 return ui,root,function()return samples end
end
local invalid={
 {source=Catalog.prepareSelected(F.Data,'silent'),roles={'raiden','traveler'}},
 {source=Original.prepare(F.Data,'hutao'),roles={'raiden','traveler'}},
 {source=C.copy(F.Data),roles={'raiden','traveler'}},
 {source=Original.prepare(F.Data,'raiden'),roles={'raiden','traveler'}},
 {source=F.Data,roles={'raiden'}},
}
invalid[3].source.characterId,invalid[3].source.originalV4Role='ironclad','RD'
for index,scenario in ipairs(invalid)do local source=scenario.source;for _,role in ipairs(scenario.roles)do
 for _,route in ipairs({'direct','click','controller'})do
  local ui,root,samples=fixture(source)
  local verifySource,verifySelection=unchanged(source),unchanged(ui.characterSelection)
  local prepare,selected=Original.prepare,Catalog.prepareSelected
  local adaptations=0
  Original.prepare=function(...)adaptations=adaptations+1;return prepare(...)end
  Catalog.prepareSelected=function(...)adaptations=adaptations+1;return selected(...)end
  local hit=root:GetChild('characterPanel'):GetChild(role=='raiden'and 'character4'or 'traveler'):GetChild('hit')
  local called,accepted,reason=pcall(function()
   if route=='direct'then return ui:selectCharacter(role)
   elseif route=='click'then return hit.click()
   else return hit.navigationListeners.confirm()end
  end)
  Original.prepare,Catalog.prepareSelected=prepare,selected
  assert(called and accepted==false,'configured '..index..' '..role..' '..route..' escaped/refused late: '..tostring(accepted))
  if route=='direct'then assert(reason=='competition_character_unavailable')end
  assert(adaptations==0 and samples()==0 and not ui.run and not ui.map,'rejected source reached adaptation/seed/Run')
  verifySource();verifySelection();count=count+1
 end
end end
-- A caller can replace source identity while the same selection page is open.
local changed=C.copy(F.Data)
local ui,_,samples=fixture(changed)
assert(ui:selectCharacter('traveler'))
changed.characterId='silent'
local verify=unchanged(ui.characterSelection)
local called,accepted,reason=pcall(ui.selectElement,ui,'ironclad')
assert(called and not accepted and reason=='competition_character_unavailable')
verify();assert(samples()==0 and not ui.run);count=count+1
-- The source can change after a valid preview without another selection command.
local stale=C.copy(F.Data)
local staleUI,_,staleSamples=fixture(stale)
assert(staleUI:selectCharacter('traveler'))
stale.originalV4Role='RD'
local verifyStale,verifyStaleSource=unchanged(staleUI.characterSelection),unchanged(stale)
assert(not staleUI.characterSelection:canConfirm(),'changed RD source still confirms a Geo preview')
local confirmed,accepted,why=pcall(staleUI.confirmCharacter,staleUI)
assert(confirmed and not accepted and why=='competition_character_unavailable')
assert(staleSamples()==0 and not staleUI.run and not staleUI.map)
verifyStale();verifyStaleSource();count=count+1
-- Consistent caller identity markers still match the explicit visible choice.
for _,id in ipairs({'ironclad'})do
 local source=C.copy(F.Data);source.characterId=id
 local host=fixture(source)
 assert(host:selectCharacter(id=='ironclad'and 'traveler'or id))
 assert(host:confirmCharacter()and host.run)
 assert(id=='ironclad'and not host.run.characterProfile or host.run.character=='raiden')
 count=count+1
end
-- The future/development host explicitly restores the complete eight-role roster.
local development,developmentRoot,developmentSamples=fixture(F.Data,'full-source')
for _,id in ipairs({'hutao','arlecchino','furina','raiden','traveler'})do
 assert(development.characterSelection:allowsCharacter(id))
end
for _,id in ipairs({'ironclad','silent','defect','watcher'})do
 assert(development.characterSelection:allowsElement(id))
end
assert(development:selectCharacter('raiden'))
assert(development:confirmCharacter()and developmentSamples()==1 and development.run.character=='raiden')
assert(development.run.campaignProfile=='full-source'and development.run.characterProfile.role=='RD')
count=count+1
-- Direct legacy factories have no explicit UI Geo selection. Keep their
-- established omitted-options and explicit full-source behavior unchanged.
local preparedRaiden=Original.prepare(F.Data,'raiden')
for _,full in ipairs({false,true})do
 local options=full and {experimental=true,campaign=true,campaignProfile='full-source'}or nil
 local legacy=Run.new(preparedRaiden,'3',options)
 assert(legacy.data.originalV4Role=='RD'and not legacy.characterProfile)
 assert(legacy.deck[1].cardId=='RD2-001'and legacy.maxHp==72)
 count=count+1
end
print('COMPETITION_PREPARED_UI_PASS '..count..'; native/natural NOT_RUN')
