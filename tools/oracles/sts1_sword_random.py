"""Fixed STS 319009d5 SwordBoomerang queued per-hit targeting interpretation.
No local gameplay catalog, Lua implementation or production RNG imports.
AttackDamageRandomEnemyAction (not DamageRandomEnemyAction) is the card's action.
Constant damage 3; no powers, block, half-dead revivals or timing/platform claims.
"""
import hashlib,json,sys
from pathlib import Path
from sts1_potion_pool import Stream
ROOT=Path(__file__).resolve().parents[2]
INPUT='tests/fixtures/sts1-sword-random-sources.json'
def build():
    cases=[]
    for seed in ['0','1','42','-1']:
        for upgraded in [False,True]:
            for label,hp in [('survive',[30,30,30]),('kill_reselect',[3,3,3]),('stop_after_last',[3,3,0])]:
                rng=Stream(seed);initial=rng.snapshot();remaining=hp.copy();hits=[]
                for hit in range(4 if upgraded else 3):
                    alive=[i for i,n in enumerate(remaining) if n>0]
                    if not alive:break
                    before=rng.snapshot();value=rng.integer(0,len(alive)-1);target=alive[value]
                    remaining[target]=max(0,remaining[target]-3)
                    hits.append(dict(hit=hit+1,eligible=[i+1 for i in alive],maximum=len(alive)-1,value=value,target=target+1,before=before,after=rng.snapshot(),hp=remaining.copy()))
                cases.append(dict(caseId=f"{seed}/{'upgraded' if upgraded else 'base'}/{label}",seed=seed,floor=6,upgraded=upgraded,scenario=label,hp=hp,hits=hits,initial=initial,after=rng.snapshot(),finalHp=remaining))
    return dict(schemaVersion=1,sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',sourceFiles=json.loads((ROOT/INPUT).read_text()),
        generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        inputSha256={INPUT:hashlib.sha256((ROOT/INPUT).read_bytes()).hexdigest(),'tools/oracles/sts1_potion_pool.py':hashlib.sha256((ROOT/'tools/oracles/sts1_potion_pool.py').read_bytes()).hexdigest()},
        boundary='Explicit replay encounter uses runSeed (not a natural floor stream). Controlled HP, hand, powers and seed. Public Run.play; not natural acquisition or device execution.',cases=cases)
if __name__=='__main__':
    result=json.dumps(build(),ensure_ascii=False,indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-sword-random.json'
    if '--check' in sys.argv:assert path.read_text()==result,'Sword oracle fixture drift'
    else:path.write_text(result)
