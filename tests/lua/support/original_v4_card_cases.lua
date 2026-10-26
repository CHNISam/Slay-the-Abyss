-- Independent frozen expectations, compared against real production C.play.
local M={}
local C=require('abyss_combat')
local Profiles=require('abyss_original_v4_profiles')
local function equal(a,b,path)
    if type(b)=='table'then
        assert(type(a)=='table',path..' expected table')
        for key,value in pairs(b)do equal(a[key],value,path..'.'..tostring(key))end
    else assert(a==b,path..' expected '..tostring(b)..' got '..tostring(a))end
end
function M.run(role,upgraded,scenario,vectors)
    local frozen=require('abyss_original_v4_data')
    assert(vectors.version==frozen.version and #vectors.cases==75)
    local prepared=Profiles.prepare(require('abyss_data'),role)
    local template=C.new(prepared,{seed=73,deck={},hp=40,enemies={'cultist','cultist'}})
    local count=0
    for _,sample in ipairs(vectors.cases)do if sample.role==role and sample.upgraded==upgraded and sample.scenario==scenario then
        local s=C.copy(template,{[template.catalog]=template.catalog,[template.rules]=template.rules,[template.originalV4Rules]=template.originalV4Rules,[template.events]={}})
        local v=s.originalV4
        for key,value in pairs(sample.input)do
            if key=='hp' or key=='block'then s.player[key]=value
            elseif key=='energy'then s.energy=value
            elseif key~='enemies'then v[key]=C.copy(value)end
        end
        for i,enemy in ipairs(s.enemies)do
            enemy.hp=sample.input.enemies[i].hp;enemy.maxHp=sample.input.enemies[i].maxHp;enemy.block=0
            if scenario=='rich' and role=='HT'then enemy.v4Bloom={strength=3,ticks=2}end
            if scenario=='rich' and role=='AR'then enemy.v4Directive={mature=true}end
        end
        s.hand={{uid=1,cardId=sample.id,upgraded=upgraded}};s.draw={};s.discard={};s.exhaust={};s.nextUid=1000
        for i=1,10 do s.draw[i]={uid=99+i,cardId=role..'2-001',upgraded=false}end
        local ok,why=C.play(s,1,1,'vector');assert(ok,sample.id..' rejected '..tostring(why))
        local got={hp=s.player.hp,block=s.player.block,energy=s.energy,enemies={},piles={}}
        for key in pairs(sample.expected)do if v[key]~=nil then got[key]=v[key]end end
        for _,key in ipairs({'hand','draw','discard','exhaust'})do got.piles[key]=#s[key]end
        for i,enemy in ipairs(s.enemies)do got.enemies[i]={hp=enemy.hp,block=enemy.block,
            bloom=enemy.v4Bloom and {strength=enemy.v4Bloom.strength,ticks=enemy.v4Bloom.ticks} or false,
            directive=enemy.v4Directive and (enemy.v4Directive.mature and 2 or 1) or 0}end
        equal(got,sample.expected,sample.id..(upgraded and '+' or '')..'/'..scenario)
        count=count+1
    end end
    assert(count==75,'all 75 definitions required');print('ORIGINAL_V4_VECTORS_PASS '..role..' '..(upgraded and 'upgrade' or 'base')..' '..scenario..' '..count)
end
return M
