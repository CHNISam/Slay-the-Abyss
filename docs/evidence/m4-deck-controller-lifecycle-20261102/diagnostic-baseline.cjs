const {execFileSync,spawnSync}=require('child_process');
const ref='origin/develop'; const source=p=>execFileSync('git',['show',`${ref}:${p}`],{encoding:'utf8'});
const preload=(name,s)=>`package.preload[${JSON.stringify(name)}]=function()\n${s}\nend\n`;
let code=`
local colour={r=1,g=1,b=1,a=1}
package.preload.abyss_theme=function()return {layout={cardDrag={threshold=4},deckView={columns=6}},cardSkin={text={title=colour}},color={rarity={},rarityBand={basic=colour},cardType={},line=colour,panelRaised=colour}}end
package.preload.abyss_combat=function()
 local function copy(x)if type(x)~='table'then return x end;local out={};for k,v in pairs(x)do out[k]=copy(v)end;return out end
 return {copy=copy,cardDefinition=function(s,c)return s.catalog.cards[c.cardId]end,canUpgrade=function()return false end}
end
package.preload.abyss_original_v4_display=function()return {}end
package.preload.abyss_card_skin=function()return {apply=function()end,tick=function()end}end
package.preload.abyss_card_display=function()return {
 writeTitle=function(c,t)c.text=t end,writeBody=function(c,t)c.text=t end,
 permanentText=function()return 'text'end,writeArt=function()end,writeNativeArt=function()end,clearNativeArt=function()end}end
`;
code+=preload('abyss_controller',source('src/lua/abyss_controller.lua'));
code+=preload('abyss_deck_ui',source('src/lua/abyss_deck_ui.lua'));
code+=`
local Controller=require('abyss_controller')
local alive=setmetatable({},{__mode='k'})
local function kill(c)alive[c]=false;for _,child in pairs(c.children)do kill(child)end end
local function control(name,parent)
 local c={name=name,parent=parent,children={},items={},visible=true,raycastTarget=true,listeners={}}
 alive[c]=true
 setmetatable(c,{__index=function(t,k)if k=='alive'then return alive[t]end end})
 function c:GetChild(n)assert(self.alive,'invalid object');if not self.children[n]then self.children[n]=control(n,self)end;return self.children[n]end
 function c:SetVisible(x)assert(self.alive);self.visible=x end
 function c:SetAsLastSibling()end
 function c:AddCursorEventListener(e,f)self.listeners[e]=f end
 function c:AddNavigationEventListener(e,f)self.listeners[e]=f end
 function c:RefreshItems(n,fn)
  for _,item in pairs(self.items)do kill(item)end;self.items={}
  for i=0,n-1 do local item=control('item'..i,self);self.items[i]=item;fn(item,i)end
 end
 return c
end
local manager=Controller.new({events={Confirm='confirm',Cancel='cancel'},getFocus=function()return nil end,setFocus=function()end,isController=function()return false end})
local root=control('deck')
local deck=require('abyss_deck_ui').new(root,{strike={name='Strike'}},'click',{controller=manager,imageSource='static',color=function(...)return {...}end},function()end)
local run={deck={},data={cards={cards={{id='strike',cost=1,type='attack',rarity='basic'}}}}}
for i=1,12 do run.deck[i]={uid=i,cardId='strike'}end
local baseline=#manager.records
local function counts()
 local dead=0;for _,record in ipairs(manager.records)do if record.control.alive==false then dead=dead+1 end end
 return #manager.records,dead
end
print('baseline records',baseline)
for i=1,20 do
 assert(deck:open(run));deck:update(.01);deck:update(.01);assert(deck:close())
 manager:sync('map')
 if i==1 or i==10 or i==20 then print('closed cycles',i,'records/dead',counts())end
end
local visits=0;local eligible=manager.eligible
manager.eligible=function(self,record)visits=visits+1;return eligible(self,record)end
for i=1,300 do manager:sync('map')end
print('300 mobile sync visits',visits,'baseline equivalent',baseline*300)
local total,dead=counts();assert(dead==260 and total==baseline+260)
print('READONLY_DECK_CONTROLLER_RETENTION_REPRODUCED')
`;
const cli=require.resolve('fengari-node-cli/src/lua-cli.js');const r=spawnSync(process.execPath,[cli,'-e',code],{encoding:'utf8',timeout:30000,maxBuffer:100000});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exitCode=r.status??1;
