-- Source Proceed is a terminal page, not an EventPool event or a reward owner.
local Nodes=require('abyss_nodes')
local M={}
local header={'hpIcon','hp','goldIcon','gold','deckIcon','deck','relics','potions'}
function M.header(self,child,ending)
 if ending then
  if not self.endingHeader then
   self.endingHeader={}
   for _,name in ipairs(header)do self.endingHeader[name]=child(name).visible~=false end
  end
  for _,name in ipairs(header)do child(name):SetVisible(false)end
 elseif self.endingHeader then
  for _,name in ipairs(header)do child(name):SetVisible(self.endingHeader[name])end
  self.endingHeader=nil
 end
end
function M.render(panel,optionCount)
 panel:GetChild('name').text='腐化之心已击败'
 panel:GetChild('caption').text='终幕 · 等待继续'
 panel:GetChild('body').text='继续进入真结局。'
 for i=1,optionCount do panel:GetChild('option'..i):SetVisible(false)end
 return '确认继续后进入真结局。'
end
local function ancestry(control)
 local links={}
 while control do links[#links+1]={control=control,parent=control.parent};control=control.parent end
 return links
end
local function attached(links)
 for _,link in ipairs(links)do
  if link.control.parent~=link.parent or link.control.visible==false or link.control.activeInHierarchy==false then return false end
 end
 return true
end
local function sameSource(self,source)
 return self.root==source.root and rawequal(self.run,source.run)and rawequal(self.map,source.map)and rawequal(self.view,source.view)
  and self.visible and not self.busy and self.mode=='main'and source.run.phase=='ending_proceed'
  and rawequal(source.run.nodeFlow,source.flow)and rawequal(source.run.endingProceed,source.owner)
end
function M.footer(self,control,commit)
 local owner=Nodes.endingProceedSource(self.run,self.map)
 local source={root=self.root,run=self.run,map=self.map,view=self.view,flow=self.run.nodeFlow,owner=owner}
 local hit=control:GetChild('hit');local links=ancestry(hit)
 local handler,retired
 local function owned()
  local current=source.root:GetChild('confirm')
  local currentHit=current and current:GetChild('hit')
  local entry=self.actions.confirm
  return owner~=nil and current==control and currentHit==hit and attached(links)and sameSource(self,source)
   and entry and entry.enabled and entry.handler==handler
 end
 local function observe()
  if retired or not owned()then retired=true;return false end
  local current=Nodes.endingProceedSource(source.run,source.map)
  if not rawequal(current,owner)or not owned()then retired=true;return false end
  return true
 end
 handler=function()
  if not observe()then return false,'stale_action'end
  return commit('proceedEnding',owner,function()return '真结局已达成。'end)
 end
 return nil,'继续',owner~=nil,handler,nil,observe
end
return M
