"""STS319009d5 source-only Prismatic reward interpreter; no production imports.
CardLibrary reward overload includes HEALING. CardGroup.shuffle spends one long,
then getRandomCard sorts by source cardID, erasing the shuffled permutation.
"""
import hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
Random=runpy.run_path(str(ROOT/'tools/sts1-card-rng-oracle.py'))['Random']
def f32(x):return struct.unpack('>f',struct.pack('>f',x))[0]
def scenario(seed,pools):
    rng=Random(seed);offset=5;trace=[];stages=[];retries=0
    initial=dict(cardRng=rng.snapshot(),cardRarityOffset=offset)
    for phase,tier,chance in [('boss','boss',0.0),('transition',None,0.0),('normal_act2','normal',.25),('elite_act2','elite',.25)]:
        def draw(kind,maximum=None):
            before=rng.snapshot();rng.counter+=1
            if kind=='long':value=f'{rng.raw():016x}'
            elif kind=='boolean':value=(rng.raw()&1)!=0
            elif kind=='chance':value=f32((rng.raw()>>40)*2**-24)<f32(chance)
            else:
                while True:
                    bits=rng.raw()>>1;value=bits%(maximum+1)
                    if bits-value+maximum<1<<63:break
            row=dict(phase=phase,kind=kind,value=value,before=before,after=rng.snapshot())
            if kind=='int':row['maximum']=maximum
            if kind=='chance':row['chance']=chance
            trace.append(row);return value
        if phase=='transition':
            target=250 if 0<rng.counter<250 else 500 if 250<rng.counter<500 else 750 if 500<rng.counter<750 else rng.counter
            while rng.counter<target:draw('boolean')
            stages.append(dict(phase=phase,traceEnd=len(trace),after=dict(cardRng=rng.snapshot(),cardRarityOffset=offset)))
            continue
        cards=[];rarities=[];attempts=[]
        for slot in range(3):
            roll=draw('int',99)+offset
            rare,uncommon=(10,50)if tier=='elite'else(3,40)
            rarity='RARE'if tier=='boss'or roll<rare else'UNCOMMON'if roll<uncommon else'COMMON'
            if rarity=='COMMON':offset=max(-40,offset-1)
            elif rarity=='RARE':offset=5
            while True:
                shuffle=draw('long');pool=pools[rarity];index=draw('int',len(pool)-1)
                card=pool[index];accepted=card not in cards
                attempts.append(dict(slot=slot+1,rarity=rarity,shuffleLong=shuffle,index=index,sourceId=card,accepted=accepted))
                if accepted:break
                retries+=1
            cards.append(card);rarities.append(rarity)
        upgrades=[draw('chance')if rarity!='RARE'else False for rarity in rarities]
        stages.append(dict(phase=phase,cards=cards,rarities=rarities,attempts=attempts,upgrades=upgrades,traceEnd=len(trace),
            after=dict(cardRng=rng.snapshot(),cardRarityOffset=offset)))
    return dict(seed=str(seed),initial=initial,stages=stages,trace=trace,duplicateRetries=retries)
def build():
    source=json.loads((ROOT/'data/reference/sts1-card-pools/pools.json').read_text())['pools']['allColorRewardByRarity']
    registration=json.loads((ROOT/'data/reference/sts1-card-pools/registration.json').read_text())
    assert registration['source']['CardLibrarySha256']=='ac123d5376862fb1d1d382284e14a9dc0e955395f415265ae29f9aa8a2b6237a'
    pools={rarity:sorted(c['id']for c in registration['registration']if c['rarity']==rarity and c['type']not in ['CURSE','STATUS'])for rarity in ['COMMON','UNCOMMON','RARE']}
    assert pools=={rarity:rows['identitySelection']for rarity,rows in source.items()},'independent registration and frozen complete pools differ'
    assert [len(pools[k])for k in ['COMMON','UNCOMMON','RARE']]==[76,160,84]
    case=scenario(CHOSEN_SEED,pools)
    assert case['duplicateRetries']>0 and any(any(s.get('upgrades',[]))for s in case['stages'][1:])
    paths=['tools/sts1-card-rng-oracle.py','data/reference/sts1-card-pools/pools.json','data/reference/sts1-card-pools/registration.json']
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',sourceFilesSha256={
        'helpers/CardLibrary.java':'ac123d5376862fb1d1d382284e14a9dc0e955395f415265ae29f9aa8a2b6237a',
        'cards/CardGroup.java':'03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8',
        'dungeons/AbstractDungeon.java':'8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26',
        'random/Random.java':'476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172',
        'dungeons/TheCity.java':'16a79d6922e3f2eaeb72c09beb177682319fda6b85302470c8d955b673260e3b',
        'relics/PrismaticShard.java':'e9813b8cbf06ca83e9e81a4c7896c93f26f36afe3b25c6bdd38645091e00c809'},
        generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        inputSha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        pools=pools,case=case,boundary='Controlled public relic acquisition and reward/claim chain, not natural route or official binary/device evidence.')
CHOSEN_SEED=7
if __name__=='__main__':
    import sys
    path=ROOT/'tests/fixtures/sts1-prismatic-rewards.json'
    expected=json.dumps(build(),ensure_ascii=False,indent=2)+'\n'
    if '--check'in sys.argv:assert path.read_text(encoding='utf-8')==expected,'Prismatic source fixture drift'
    else:path.write_text(expected,encoding='utf-8')
