"""Pinned 319009d5 Chaos targets -> actual card/relic consumers.
Independent XS128 and frozen source registration; no production imports.
"""
import hashlib,json
from pathlib import Path
from sts1_potion_pool import Stream
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_identity(p,root):return p.relative_to(root).as_posix()
def build():
    base=ROOT/'data/reference/sts1-card-pools'
    inputs=[base/'registration.json',base/'pools.json',ROOT/'tools/oracles/sts1_potion_pool.py']
    rows={r['id']:r for r in json.loads(inputs[0].read_text())['registration']}
    pools=json.loads(inputs[1].read_text())['pools']
    pool=[id for rarity in ['COMMON','UNCOMMON','RARE'] for id in pools['srcRed'][rarity] if 'HEALING' not in rows[id]['tags']]
    cases=[]
    for seed in ['0','1','2']:
        rng=Stream(seed);trace=[];initial=rng.snapshot()
        def draw(purpose,maximum=None):
            before=rng.snapshot()
            if maximum is None:rng.counter+=1;value=bool(rng.raw()&1)
            else:value=rng.integer(0,maximum)
            trace.append(dict(purpose=purpose,boolean=maximum is None,value=value,before=before,after=rng.snapshot(),**({}if maximum is None else {'maximum':maximum})))
            return value
        # DistilledChaosPotion.use constructs all three targets before playing.
        targets=[draw('Chaos target '+str(i),1)+1 for i in range(1,4)]
        after_targets=rng.snapshot()
        zeroed=['Defend_R','Bash'][draw('Mummified Hand after Inflame',1)]
        spoon=draw('Strange Spoon after Impervious')
        generated=None if spoon else pool[draw('Dead Branch after Impervious',len(pool)-1)]
        cases.append(dict(seed=seed,initial=initial,targets=targets,afterTargets=after_targets,zeroed=zeroed,spoonProc=spoon,after=rng.snapshot(),trace=trace,**({}if generated is None else {'generated':generated})))
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
      sourceFilesSha256={
       'potions/DistilledChaosPotion.java':'293b4e80fb584be6d409e3b857dc7e45f1a83f18c4234edb9191c96e2e9967d9',
       'actions/common/PlayTopCardAction.java':'dc0bae486cfa50d1470b54917d08ae240b014d96566e5cf32f3d5b0f4aabfd34',
       'actions/utility/NewQueueCardAction.java':'8a49f78ae34c588f8d9c0f8243d24950b4945b915e20da5ad7ec026c3e6f3747',
       'actions/utility/UseCardAction.java':'90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f',
       'relics/MummifiedHand.java':'48d8f5909f56fdbe6cf216bd60bcabeafe10082a3d3a760a769a855428db06a8',
       'relics/StrangeSpoon.java':'e319dca794cae7abfa9ecc18cedd3cb32ac6fd041d4c947e6ad012d03246526d',
       'relics/DeadBranch.java':'dbace8181345b67bb9c704b83dea61c9754c3268fc5d93c192f1bd47908c2d6f',
       'monsters/MonsterGroup.java':'535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221',
       'dungeons/AbstractDungeon.java':'8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26',
       'cards/red/Inflame.java':'ac42810d2c107c0185b96d58fbe8f01d425f0485dcd81e2e8bd3480e57a590cc',
       'cards/red/Impervious.java':'f2cfabe529afb63089116a31d836c616f0fc14062d765118f0d16dcc4404b74f',
       'cards/red/Strike_Red.java':'e419fefb5b1bcc34175570fbafb8b68cc2a014ec4e7d974674586057dd22d37b'},
      generatorSha256=sha(Path(__file__)),inputSha256={source_identity(p,ROOT):sha(p)for p in inputs},
      boundary='Controlled legal acquired deck/pile order in a public two-enemy replay battle; not natural acquisition, source-room propagation or PC frame replay.',fullPool=pool,cases=cases)
if __name__=='__main__':
    import sys
    result=json.dumps(build(),ensure_ascii=False,indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-chaos-shared-chain.json'
    if '--check'in sys.argv:assert path.read_text()==result,'oracle fixture drift'
    else:path.write_text(result)
