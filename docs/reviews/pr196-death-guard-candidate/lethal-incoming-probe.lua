package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local R=require('abyss_run');local data=require('abyss_data')
local r=R.new(data,'99');r.floor=16;r.deck={};r.relics={}
assert(R.startRoomCombat(r,'boss'));local s=r.combat;s.energy=20
local function play(id)
  local c={uid=s.nextUid,cardId=id,upgraded=false};s.nextUid=s.nextUid+1;s.hand[#s.hand+1]=c
  assert(R.play(r,c.uid,1))
end
play('bludgeon');assert(s.enemies[1].aiPhase=='defense');assert(R.endTurn(r))
assert(C.intent(s,1).id=='guardian_6');assert(R.endTurn(r));assert(C.intent(s,1).id=='guardian_7')
s.player.hp=7;C.addStatus(s.player,'frail',1);s.energy=3;s.hand={};s.draw={};s.discard={};s.exhaust={}
play('flame_barrier');assert(s.player.block==9 and s.player.statuses.flame_barrier==4)
local before=s.enemies[1].hp;s.events={}
assert(R.endTurn(r))
local reactions=0
for _,e in ipairs(s.events) do
  if e.kind=='damage' or e.kind=='status_damage' then
    print(e.kind..' source='..e.detail.source..' target='..e.detail.target..' hpLost='..e.detail.amount..' blocked='..(e.detail.blocked or 0)..' playerHP='..e.frame.player.hp..' guardianHP='..e.frame.enemies[1].hp)
  end
  if e.kind=='status_damage' and e.detail.target==s.enemies[1].id then reactions=reactions+1 end
end
print('EXPECTED playerHP=0 guardianHP='..(before-4)..' reactions=1 RunPhase=defeat')
print('ACTUAL playerHP='..s.player.hp..' guardianHP='..s.enemies[1].hp..' reactions='..reactions..' RunPhase='..r.phase)
assert(s.player.hp==0 and r.phase=='defeat' and r.rewards==nil)
assert(reactions==1 and s.enemies[1].hp==before-4,'queued Flame Barrier must not resolve after the lethal second hit opens death screen')
