local Theme=require('abyss_theme')
local Display=require('abyss_card_display')
local marker='<color=#8DE08A>＋</color>'
local sentinel={r=17,g=31,b=47,a=63}
local title,kind={fontColor=sentinel},{fontColor=sentinel}
local plain,font,fits,relocated=Display.title('防御',true)
assert(plain=='防御＋' and fits and relocated=='','fitting must use unmarked title text')
assert(Display.writeTitle(title,'防御',true,nil,kind,'技能'))
assert(title.text=='防御'..marker,'only the upgrade marker should carry approved green ink')
assert(kind.text=='技能' and title.fontSize==font,'markup must not change fit or add a type marker')
assert(title.fontColor==sentinel and kind.fontColor==sentinel,'writer must preserve native parent font colours')
assert(sentinel.r==17 and sentinel.g==31 and sentinel.b==47 and sentinel.a==63,'writer must not mutate parent colour channels')
print('CARD_TITLE_INLINE '..title.text)

assert(Display.writeTitle(title,'灼热攻击',true,999,kind,'攻击'))
assert(title.text=='灼热攻击<color=#8DE08A>＋999</color>','repeat upgrade count stays with its marker')
assert(Display.writeTitle(title,'恰到好处的停顿',true,nil,kind,'技能'))
assert(title.text=='恰到好处的停顿' and kind.text=='技能 '..marker,'long full title keeps the coloured marker in the type line')
assert(title.fontSize>=Theme.font.minimum,'never shrink below the readable floor')
assert(Display.writeTitle(title,'防御',false,nil,kind,'技能'))
assert(title.text=='防御' and kind.text=='技能','recycled unupgraded card clears both rich-text marker locations')
local ink=Theme.cardSkin.text.upgrade
Theme.cardSkin.text.upgrade={r=1,g=2,b=3,a=255}
Display.writeTitle(title,'防御',true,nil,kind,'技能')
assert(title.text=='防御<color=#010203>＋</color>','upgrade ink must come from the shared theme')
Theme.cardSkin.text.upgrade=ink

-- Exercise the real deck fill entrypoint, not a copied title assignment.
local function copy(v)
 if type(v)~='table'then return v end
 local result={};for k,x in pairs(v)do result[k]=copy(x)end;return result
end
package.loaded.abyss_combat={copy=copy,cardDefinition=function(state,instance)return state.catalog.cards[instance.cardId]end}
package.loaded.abyss_card_skin={apply=function()end,tick=function()end}
package.loaded.abyss_original_v4_display={}
package.loaded.abyss_controller={bind=function()end,pointerBlocked=function()return false end}
local function control()
 local c={children={}}
 function c:GetChild(name)
  if name=='artSamples'then return nil end
  if not self.children[name]then self.children[name]=control()end
  return self.children[name]
 end
 function c:SetVisible(v)self.visible=v end
 function c:SetAsLastSibling()end
 function c:AddCursorEventListener()end
 function c:SetImage()end
 function c:SetSizeDelta()end
 return c
end
local root=control()
local item=control()
function root:GetChild(name)
 if not self.children[name]then self.children[name]=control()end
 return self.children[name]
end
local grid=root:GetChild('grid')
function grid:RefreshItems(count,callback)
 if count>0 then callback(item,0)end
end
local definition={id='defend',type='skill',rarity='basic',cost=1,effects={}}
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local deck=require('abyss_deck_ui').new(root,{defend={name='防御',text='获得 5 点格挡。',upgradeText='获得 8 点格挡。'}},'click',platform,function()end)
assert(deck:open({deck={{uid=1,cardId='defend',upgraded=true}},data={cards={cards={definition}}}}))
local name=item:GetChild('face'):GetChild('name')
assert(name.text=='防御'..marker,'deck must use the shared marker formatter')
assert(name.fontColor.r==255 and name.fontColor.g==255 and name.fontColor.b==255,'deck must not colour the full upgraded name green')
assert(deck:close())
print('CARD_TITLE_INK_PASS short/repeated/relocated/recycled/plain-fit/native-parent-ink/real-deck-fill')
