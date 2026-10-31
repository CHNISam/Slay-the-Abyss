"""Pinned 319009d5 facts: independent XS128/shuffle and IEEE binary32.
No production Lua, float helpers, RNG clones or local card definitions.
"""
import hashlib,json,struct
from pathlib import Path
from sts1_potion_pool import Stream
from sts1_combat_shuffle import ShuffleRandom,room_seed
ROOT=Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source_identity(path,root):return path.relative_to(root).as_posix()
def f32(x):return struct.unpack('>f',struct.pack('>f',x))[0]
def build():
    # Printed costs read from the pinned source registration, never local data.
    registration=ROOT/'data/reference/sts1-card-pools/registration.json'
    rows={r['id']:r for r in json.loads(registration.read_text())['registration']}
    deck=['Strike_R','Defend_R','Bash','Anger','Impervious','Offering','Pommel Strike','Shrug It Off','Clash','Whirlwind','Burn','Wound']
    cases=[]
    for seed in ['0','1','3','42']:
        # Public explicit-ID replay: separate card RNG raw run seed; shuffle
        # receives seed+floor (floor1). This is not source-room seed propagation.
        rng=Stream(seed);shuffle=ShuffleRandom(room_seed(seed,1));pile=list(range(1,len(deck)+1));shuffle.shuffle(pile)
        trace=[];steps=[]
        for phase,count in [('opening',7),('swift',3)]:
            drawn=[]
            for _ in range(count):
                uid=pile.pop();source=deck[uid-1];base=rows[source]['cost']
                # Explicit temporary fixture for later draw: costForTurn=0,
                # freeToPlayOnce=true. Source equal-base roll preserves turn0.
                turn=0 if phase=='swift' else None
                cost=base;modified=False;free=phase=='swift'
                if base>=0:
                    before=rng.snapshot();roll=rng.integer(0,3)
                    trace.append(dict(maximum=3,value=roll,before=before,after=rng.snapshot()))
                    if roll!=base:cost=roll;turn=roll;modified=True
                    free=False
                drawn.append(dict(deckIndex=uid,sourceId=source,base=base,cost=cost,modified=modified,free=free,**({}if turn is None else {'turnCost':turn})))
            steps.append(dict(phase=phase,cards=drawn,after=rng.snapshot()))
        cases.append(dict(seed=seed,steps=steps,trace=trace))
    insect=[]
    for maximum in [1,2,3,5,50,101,16777215,16777216,16777217,16777219,2147483647]:
        for tier,trigger in [('normal',None),('elite',None),('boss',None),('elite',False),('normal',True)]:
            threshold=int(f32(f32(maximum)*f32(1-f32(.25))))
            active=trigger is True or tier=='elite'and trigger is not False
            insect.append(dict(maximum=maximum,tier=tier,hp=min(maximum,threshold)if active else maximum,**({}if trigger is None else {'eliteTrigger':trigger})))
        if maximum in [1,50]:
            insect.append(dict(maximum=maximum,tier='elite',neow=True,hp=min(1,int(f32(f32(maximum)*f32(.75))))))
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
      sourceFilesSha256={'relics/SneckoEye.java':'00edd6a0dfa78effb07ffae64138c4fd3f4312d583d6e69159b16d981289a5c8','powers/ConfusionPower.java':'b987912476db56c0521b93637717dc5bd3fd13a5a8537e7f5f19462b00a612c2','relics/PreservedInsect.java':'303c04bda8c9c7d94f540daf9db786a5cabb02761241f0680ed10a419a35abe9','actions/common/DrawCardAction.java':'67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18','characters/AbstractPlayer.java':'2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95'},
      generatorSha256=sha(__file__),inputSha256={source_identity(p,ROOT):sha(p)for p in [registration,ROOT/'tools/oracles/sts1_potion_pool.py',ROOT/'tools/oracles/sts1_combat_shuffle.py']},
      boundary='Controlled public explicit-ID Run battles and draw potion; not natural acquisition or original PC execution.',deck=deck,snecko=cases,insect=insect)
if __name__=='__main__':
    import sys
    result=json.dumps(build(),ensure_ascii=False,indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-snecko-insect.json'
    if '--check'in sys.argv:assert path.read_text()==result,'oracle fixture drift'
    else:path.write_text(result)
