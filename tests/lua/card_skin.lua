local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Skin=require('abyss_card_skin')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local face=root:GetChild('battlePanel'):GetChild('card1')
local platform={imageSource='static',color=function(r,g,b,a)assert(r==math.floor(r) and g==math.floor(g) and b==math.floor(b),'native Color channels must be integers');return {r=r,g=g,b=b,a=a}end}
local function encode(v)
 if type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','')..'"' end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v)end
 local fields={};for k,x in pairs(v)do fields[#fields+1]=encode(tostring(k))..':'..encode(x)end
 return '{'..table.concat(fields,',')..'}'
end
local function capture(c)
 local result={children={}}
 for _,k in ipairs({'visible','text','imageId','imageColor','fontColor','fontSize'})do if c[k]~=nil then result[k]=c[k]end end
 for k,child in pairs(c.children)do result.children[k]=capture(child)end
 return result
end
for i,case in ipairs({
 {role='HT',type='attack',rarity='common',cost=1,base=2},
 {role='FR',type='skill',rarity='uncommon',cost=2,base=1},
 {role='RD',type='power',rarity='rare',cost=1,base=1},
 {role='AR',type='attack',rarity='basic',cost=1,base=1,dim=true},
 {role='traveler',type='skill',rarity='basic',cost=-2,base=-2},
 {role='colorless',type='power',rarity='rare',cost=0,base=1},
})do
 local definition={originalV4={role=case.role},type=case.type,rarity=case.rarity,cost=case.cost}
 Skin.apply(face,definition,platform,{cost=case.cost,baseCost=case.base,dim=case.dim})
 for _,kind in ipairs({'attack','skill','power'})do assert(face:GetChild('skin'):GetChild(kind).visible==(kind==case.type))end
 for role in pairs(F.Theme.cardSkin.roles)do assert(face:GetChild('roleMark'):GetChild(role).visible==(role==case.role))end
 assert(face:GetChild('costHalo').visible==(case.cost>=0 and case.cost~=case.base))
 assert(face:GetChild('costDisc').visible==(case.cost~=-2))
 assert(face:GetChild('blockedReason').visible==(case.dim==true))
 face:GetChild('name').text=({'蝶舞回身','恰到好处的停顿','雷光常驻','月下之刃','防御','静心'})[i]
 require('abyss_card_display').writeTitle(face:GetChild('name'),face:GetChild('name').text,false,nil,face:GetChild('type'),'')
 face:GetChild('type').text=({attack='攻击',skill='技能',power='能力'})[case.type]
 face:GetChild('label').text='获得 5 点格挡。\n造成 7 点伤害。'
 face:GetChild('cost').text=case.cost==-2 and '' or tostring(case.cost)
 Skin.tick(face,.45);assert(face:GetChild('costHalo').localScaleX>=.9199 and face:GetChild('costHalo').localScaleX<=1.0501)
 print('SKIN_PREVIEW '..encode(capture(face)))
end
Skin.apply(face,{type='attack',rarity='common',cost=1},platform,{cost=1,baseCost=1})
assert(not face:GetChild('costHalo').visible and not face:GetChild('costDirection').visible and not face:GetChild('blockedReason').visible)
print('LUA_CARD_SKIN_PASS six roles, three shapes, rarity, up/down/absent costs, pulse and recycled state')
