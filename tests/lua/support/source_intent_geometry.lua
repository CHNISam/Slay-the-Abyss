-- Independent sts@319009d5 constructor facts. Do not call the UI geometry owner.
local facts={
 cultist={0,-10,0,0,-8,10,230,240},gremlin_nob={0,0,0,0,-70,-10,270,380},
 guardian={-50,-100,0,0,0,95,440,350},automaton={-50,20,0,0,0,-30,270,400},
 bronze_orb={0,0,0,0,0,0,160,160},collector={60,135,0,0,15,-40,300,390},
 torch_head={0,0,0,0,-5,-20,145,240},awakened_one={100,15,0,0,40,-30,460,250},
 spike_slime_l={0,0,0,0,0,-30,300,180},acid_slime_l={0,0,0,0,0,0,300,180},
 spike_slime_m={0,0,0,0,0,-25,170,130},acid_slime_m={0,0,0,0,0,0,170,130},
 gremlin_leader={35,0,0,0,0,-15,200,310},mad_gremlin={0,0,0,0,-4,12,130,194},
 sneaky_gremlin={0,0,0,0,0,0,120,160},reptomancer={-20,10,0,0,0,-30,220,320},
 snake_dagger={0,0,0,0,0,-50,140,130},
}
return function(box,actor)
 local theme=require('abyss_theme');local width,height=theme.canvas.base[1],theme.canvas.base[2]
 local sx,sy=width/1920,height/1080
 local f=assert(facts[actor.definitionId],'missing independent source geometry fact')
 local p=actor.sourcePosition or {x=f[1],y=f[2]}
 local x=(1440+p.x+f[3])*sx-width/2
 -- Frozen source floor 340 plus the approved 60px native-hand clearance.
 -- Do not borrow the geometry owner's output as this oracle's expected value.
 local bottom=(400+p.y+f[4])*sy-height/2
 local h=actor.definitionId=='guardian' and actor.aiPhase=='defense' and 250 or f[8]
 local portrait=math.max(f[7]*sx,h*sy)
 local rootY=bottom+portrait/2
 local iconX=f[5]*sx+(actor.definitionId=='gremlin_nob' and -30*sx or 0)
 -- The source horizontal anchor is preserved. Full-bleed native glyphs and
 -- native 40px damage text sit above BOTH source art and source hitbox.
 local bodyTop=math.max(rootY+portrait/2,bottom+(f[6]+h)*sy)
 local line=theme.layout.nativeText.lineHeight
 local iconY=bodyTop+math.max(line,theme.layout.intent.size)/2+theme.space.xs-rootY
 local function eq(got,want,label)assert(math.abs(got-want)<.001,label..': '..got..' ~= '..want)end
 eq(box.x,x,'source actor x');eq(box.y,rootY,'source actor y')
 local icon,hit=box:GetChild('intentIcon'),box:GetChild('intentHit')
 local glyph=math.min(128*sx,theme.layout.intent.size)
 eq(hit.x,iconX,'source intent x');eq(hit.y,iconY,'source intent y')
 eq(icon.x,iconX,'source intent x');eq(icon.y,iconY,'native intent row clears art and hitbox')
 eq(icon.sizeDeltaX,glyph,'readable intent glyph width');eq(icon.sizeDeltaY,glyph,'readable intent glyph height')
 eq(hit.sizeDeltaX,64*sx,'source help width');eq(hit.sizeDeltaY,64*sy,'source help height')
 local value=box:GetChild('intent')
 eq(value.x-value.sizeDeltaX/2,iconX+glyph/2+theme.space.xs,'damage starts after the full-bleed glyph')
 eq(value.y,iconY,'damage shares the native intent row')
 eq(value.sizeDeltaY,line,'complete native damage text line')
 assert(rootY+icon.y-glyph/2>=bodyTop+theme.space.xs-.001,'intent glyph overlaps body')
 assert(rootY+value.y-line/2>=bodyTop+theme.space.xs-.001,'intent damage overlaps body')
end
