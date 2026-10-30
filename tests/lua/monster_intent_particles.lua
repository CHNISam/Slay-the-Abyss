local M = require('abyss_monster_intent_particles')
local function eq(a, b) assert(a == b, tostring(a)..' != '..tostring(b)) end
local function near(a, b) assert(math.abs(a-b)<1e-9, tostring(a)..' != '..tostring(b)) end
local calls = 0
local function random() calls=calls+1; return 0.25 end
local function params(intent, dt)
    return {intent=intent, dt=dt, intentAlpha=1, x=100, y=200, scale=2, starWidth=20, starHeight=16}
end
local sequence = M.newSequence()
local a, b = M.newActor(), M.newActor()
M.createIntent(a); M.createIntent(b)
near(M.updateAlpha(a, 0.2), 0.2)
near(M.updateAlpha(a, 2), 1)
M.flashIntent(a); near(M.updateAlpha(a, 0.3), 0.8)
near(M.updateAlpha(a, 10), 0)
M.createIntent(a); eq(a.intentAlpha,0); eq(a.intentAlphaTarget,1)
-- Strict timer zero, no spawn. Then one left-side UNKNOWN.
eq(#M.update(a,sequence,params('UNKNOWN',0.5),random),0)
M.update(a,sequence,params('UNKNOWN',0.01),random)
eq(#a.effects,1); eq(calls,2)
local left = a.effects[1]
eq(left.centerX,52); eq(left.centerY,186); eq(left.rotationDeg,24)
eq(left.renderBehind,true); near(left.scale,0.01); near(left.duration,1.49)
-- Another actor receives shared CENTER phase, not a second left.
M.update(b,sequence,params('UNKNOWN',0.51),random)
eq(#b.effects,1); eq(sequence.unknownPhase,2); eq(calls,2)
eq(b.effects[1].centerX,100); eq(b.effects[1].renderBehind,false)
near(left.duration,1.49) -- No cross-actor ticking.
-- Same move repeated resets alpha/timer, does NOT clear old effects.
M.createIntent(a); eq(#a.effects,1); near(a.timer,0.5)
local moved = params('UNKNOWN',0.51); moved.x=900
M.update(a,sequence,moved,random)
eq(#a.effects,2); eq(sequence.unknownPhase,0)
eq(a.effects[1].centerX,52); eq(a.effects[2].centerX,948)
eq(a.effects[2].rotationDeg,-24); eq(a.effects[2].renderBehind,true)
-- dt catch-up must not loop; at most one spawn even for a huge frame.
local c=M.newActor(); M.update(c,sequence,params('UNKNOWN',4),random)
eq(c.nextId,1); eq(#c.effects,0); near(c.timer,0.5)
-- Exact duration zero stays until the following positive frame.
local d=M.newActor(); M.update(d,sequence,params('UNKNOWN',1.5),random)
eq(#d.effects,1); eq(d.effects[1].duration,0); eq(d.effects[1].color[4],0)
local hidden=params('NONE',0.001); hidden.intentAlpha=0; hidden.isDying=true
M.update(d,sequence,hidden,random); eq(#d.effects,0)
-- STUN source order: orbit from pre-dt duration, tint from post-dt duration.
local s=M.newActor(); M.createIntent(s)
M.update(s,sequence,params('STUN',0.6),random)
eq(#s.effects,1); local star=s.effects[1]
eq(star.textureKey,'TINY_STAR'); eq(star.renderBehind,false)
near(star.centerX,40); near(star.centerY,188); near(star.rotationDeg,54)
near(star.duration,1.4); near(star.color[4],1-0.4^5)
near(star.color[1],1-0.4^4)
local die=params('STUN',0.9); die.isDying=true
M.update(s,sequence,die,random); eq(s.nextId,1); near(star.duration,0.5)
near(star.color[1],0.75); near(star.color[4],0.96875)
eq(s.timer,0.67) -- Generation timer pauses, particles do not.
-- Alpha-zero and escaping suppress creation independently, no RNG consumed.
local before=calls; local e=M.newActor(); local p=params('UNKNOWN',0.1)
p.intentAlpha=0; M.update(e,sequence,p,random)
p.intentAlpha=1; p.isEscaping=true; M.update(e,sequence,p,random)
eq(e.nextId,0); eq(calls,before)
-- Rapid explicit createIntent calls retain every previous live effect, no cap.
local f=M.newActor()
for i=1,7 do
    M.createIntent(f); f.timer=0 -- Explicit test fixture clock, not production reset.
    M.update(f,sequence,params(i%2==0 and 'STUN' or 'UNKNOWN',0.01),random)
end
eq(#f.effects,7)
for i,effect in ipairs(f.effects) do eq(effect.effectId,i) end
-- Bounds and cosmetic RNG are not silently invented by the helper.
local z=M.newActor(); local bad=params('STUN',0.1); bad.starWidth=nil
eq(pcall(M.update,z,sequence,bad,random),false)
eq(pcall(M.update,M.newActor(),sequence,params('STUN',0.1),nil),false)
print('SOURCE_INTENT_PARTICLES_PASS')
