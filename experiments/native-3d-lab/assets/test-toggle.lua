local Sample=dofile('experiments/native-3d-lab/assets/runtime.lua')
local function node(children,was)
 local c={children=children or {},visible=was~=false,alive=true}
 function c:GetChild(name)return self.children[name]end
 function c:SetVisible(value)assert(self.alive);self.visible=value end
 return c
end
local hp,card,original,previouslyHidden,sample=node(),node(),node(),node(nil,false),node(nil,false)
local stage=node({labMaterialBackdrop=sample,officialBackground=original,officialBattleBackdrop=previouslyHidden,
 battlePanel=node({hp=hp,card1=card,backdrop=node()}),menuPanel=node({backdrop=node(nil,false)})})
local root=node({stage=stage})
assert(Sample.toggle(root,true):find('107134',1,true));assert(sample.visible and not original.visible)
assert(hp.visible and card.visible,'all battle HUD and card controls must survive')
Sample.toggle(root,true);Sample.toggle(root,false)
assert(not sample.visible and original.visible and not previouslyHidden.visible)
assert(not stage:GetChild('menuPanel'):GetChild('backdrop').visible,'original false state must restore as false')
Sample.toggle(root,false);Sample.toggle(root,true);Sample.destroy(root)
assert(not sample.visible and original.visible and hp.visible and card.visible)
print('material specimen: idempotent toggle, exact background visibility restore and HUD preservation passed')
