"""Independent pinned-source maximum-health acquisition and source-queue oracle.

No production Lua/definitions imports or original game execution. Optional
--source-root verifies cached exact Git member bytes; never performs a fetch.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from sts1_combat_shuffle import ShuffleRandom
from sts1_combat_gold import Random
from sts1_treasure import ChestRandom, f32
from sts1_class_relic_pools import lua

ROOT=Path(__file__).resolve().parents[2]
TIERS=['common','uncommon','rare','shop','boss']
STARTING_MAXIMUM={'ironclad':80,'silent':70,'defect':75,'watcher':72}
# Reuse the independently sourced, committed CHARACTER_PROFILES facts, not
# the production profile function or the observed result under test.
FACTS=[('strawberry','Strawberry','common',7),('pear','Pear','uncommon',10),('mango','Mango','rare',14),('lees_waffle',"Lee's Waffle",'shop',7)]

def sha(path):
    return hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()

def source_check(directory):
    lock=json.loads((ROOT/'tests/fixtures/max-hp-relics-source.json').read_text(encoding='utf-8'))
    texts={}
    for path,expected in lock['files'].items():
        raw=(directory/path).read_bytes()
        assert len(raw)==expected['bytes'] and hashlib.sha256(raw).hexdigest()==expected['sha256'],path
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==expected['gitBlob'],path
        texts[path]=raw.decode()
    for cls,source_id,tier,amount in [('Strawberry','Strawberry','COMMON',7),('Pear','Pear','UNCOMMON',10),('Mango','Mango','RARE',14),('Waffle',"Lee's Waffle",'SHOP',7)]:
        text=texts['relics/'+cls+'.java']
        assert 'ID = "'+source_id+'"' in text and 'RelicTier.'+tier in text
        assert f'increaseMaxHp({amount}, '+('false' if cls=='Waffle' else 'true')+');' in text
        assert 'canSpawn' not in text
    assert texts['relics/Waffle.java'].index('increaseMaxHp(7, false)')<texts['relics/Waffle.java'].index('heal(AbstractDungeon.player.maxHealth)')
    core=texts['core/AbstractCreature.java']
    assert 'this.maxHealth += amount;' in core and 'this.heal(amount, true);' in core
    assert 'if (this.isDying)' in core
    assert 'healAmount = r.onPlayerHeal(healAmount);' in core and 'healAmount = p.onHeal(healAmount);' in core
    assert 'return 0;' in texts['relics/MarkOfTheBloom.java']
    assert 'AbstractRoom.RoomPhase.COMBAT' in texts['relics/MagicFlower.java']
    print('MAX_HP_SOURCE_MATCH 9 exact Git members; Strawberry7/Pear10/Mango14/Waffle7->newMax')

def healing(amount,relics,combat):
    for relic in relics:
        if relic=='mark_of_bloom':amount=0
        elif relic=='magic_flower' and combat:amount=math.floor(f32(f32(amount)*f32(1.5))+.5)
    return amount

def health_cases():
    rows=[]
    for local_id,source_id,tier,amount in FACTS:
        for combat in [False,True]:
            for hp,maximum in [(30,80),(80,80),(1,1),(20,16777219)]:
                for relics in [[],['magic_flower'],['mark_of_bloom'],['magic_flower','mark_of_bloom'],['mark_of_bloom','magic_flower']]:
                    new_max=maximum+amount
                    current=min(new_max,hp+healing(amount,relics,combat))
                    steps=[{'requested':amount,'maximum':new_max,'hp':current}]
                    if local_id=='lees_waffle':
                        current=min(new_max,current+healing(new_max,relics,combat))
                        steps.append({'requested':new_max,'maximum':new_max,'hp':current})
                    rows.append({'id':local_id,'sourceId':source_id,'combat':combat,'hp':hp,'maximum':maximum,'relics':relics,'expectedHp':current,'expectedMaximum':new_max,'steps':steps})
    return rows

def source_shop_draw(queues,tier,gates,character):
    # AbstractDungeon returnRandomRelic(...,true): ineligible IDs are spent;
    # same-tier retries use the tail, exhausted fallback uses next-tier front.
    owned={'ironclad':'Burning Blood','silent':'Ring of the Snake','defect':'Cracked Core','watcher':'PureWater'}[character]
    def eligible(ident):
        gate=gates.get(ident,{'kind':'always'});kind=gate['kind']
        if kind=='always':return True
        if kind=='max-floor':return 1<=gate['floor'] and gate.get('excludeRoom')!='shop'
        if kind=='max-act':return 1<=gate['act']
        if kind=='owns-relic':return owned==gate['id']
        if kind=='campfire-limit':return 1<gate['maxExclusiveFloor']
        if kind=='card-type':return gate['cardType']in ['ATTACK','SKILL']
        if kind=='nonbasic-card-type':return False # each ordinary source starter card has BASIC rarity
        raise AssertionError(kind)
    trace=[]
    def take(requested,tail):
        queue=queues[requested]
        if not queue:
            if requested in ['common','shop']:return take('uncommon',False)
            if requested=='uncommon':return take('rare',False)
            return 'Circlet'
        ident=queue.pop()if tail else queue.pop(0)
        trace.append({'tier':requested,'end':tail,'id':ident})
        return ident if eligible(ident)else take(requested,True)
    return take(tier,True),trace

def queue_cases():
    catalogs={'ironclad':json.loads((ROOT/'data/catalogs/sts1-relic-queues.json').read_text())}
    catalogs.update(json.loads((ROOT/'data/catalogs/sts1-class-relic-queues.json').read_text()))
    cases=[]
    # Bound search is an authoring assertion, not a gameplay retry/filter.
    for character,catalog in catalogs.items():
        wanted={(channel,target)for _,target,tier,_ in FACTS[1:]for channel in (['shop']if tier=='shop'else ['shop','chest','elite'])}
        for seed in range(5000):
            if not wanted:break
            relic=ShuffleRandom(seed);queues={}
            for tier in TIERS:
                queues[tier]=list(catalog['queues'][tier]);relic.shuffle(queues[tier])
            elite=Random(seed);elite.a,elite.b,elite.counter=relic.a,relic.b,relic.counter
            elite_roll=elite.integer(0,99);elite_tier='common'if elite_roll<50 else'uncommon'if elite_roll<83 else'rare'
            chest=ChestRandom(seed);kind_roll=chest.integer(0,99);reward_roll=chest.integer(0,99)
            kind='small'if kind_roll<50 else'medium'if kind_roll<83 else'large'
            a,b,chance,base={'small':(75,100,50,25),'medium':(35,85,35,50),'large':(0,75,50,75)}[kind]
            chest_tier='common'if reward_roll<a else'uncommon'if reward_roll<b else'rare'
            gold=math.floor(chest.floating(f32(base*f32(.9)),f32(base*f32(1.1)))+.5)if reward_roll<chance else 0
            merchant=ChestRandom(seed)
            for _ in range(7):merchant.floating(f32(.9),f32(1.1))
            sale=merchant.integer(0,4)
            shop=[];post_queues={k:list(v)for k,v in queues.items()}
            for slot in range(1,4):
                roll=None if slot==3 else merchant.integer(0,99)
                tier='shop'if slot==3 else'common'if roll<48 else'uncommon'if roll<82 else'rare'
                source_id,trace=source_shop_draw(post_queues,tier,catalog['spawnGates'],character)
                multiplier=merchant.floating(f32(.95),f32(1.05));price=math.floor(f32({'common':150,'uncommon':250,'rare':300,'shop':150}[tier]*multiplier)+.5)
                offer={'slot':slot,'sourceId':source_id,'tier':tier,'price':price,'trace':trace}
                if roll is not None:offer['roll']=roll
                shop.append(offer)
            for channel,target in list(sorted(wanted)):
                tier=next(t for _,n,t,_ in FACTS if n==target)
                slot=next((x['slot']for x in shop if x['sourceId']==target),None)
                yes=slot is not None if channel=='shop' else (elite_tier if channel=='elite' else chest_tier)==tier and queues[tier][0]==target
                if not yes:continue
                wanted.remove((channel,target))
                row={'character':character,'startingMaximum':STARTING_MAXIMUM[character],'sourceId':target,'id':next(i for i,n,t,v in FACTS if n==target),'tier':tier,'seed':str(seed),'channel':channel,'queues':queues,'rawLongHex':[step['rawHex']for step in relic.trace],'afterInitialization':relic.snapshot()}
                if channel=='shop':row.update({'slot':slot,'offers':shop,'afterQueues':post_queues})
                elif channel=='elite':row.update({'roll':elite_roll,'afterRng':elite.snapshot()})
                else:row.update({'kindRoll':kind_roll,'rewardRoll':reward_roll,'kind':kind,'gold':gold,'afterRng':chest.snapshot()})
                cases.append(row)
        assert not wanted,(character,wanted)
    return cases

def build():
    inputs=['docs/rules/CHARACTER_PROFILES.md','data/catalogs/sts1-relic-queues.json','data/catalogs/sts1-class-relic-queues.json','tests/fixtures/max-hp-relics-source.json','tools/oracles/sts1_combat_shuffle.py','tools/oracles/sts1_combat_gold.py','tools/oracles/sts1_treasure.py','tools/oracles/sts1_class_relic_pools.py']
    cases={'health':health_cases(),'channels':queue_cases()}
    return {'sourceCommit':'319009d5df0a82d9fb0f23cc22322286c6a87ec0','generatorSha256':sha('tools/oracles/sts1_max_hp_relics.py'),'inputs':{p:sha(p)for p in inputs},'cases':cases}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source-root',type=Path);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.source_root:source_check(args.source_root)
    result=build();path=ROOT/'tests/fixtures/max-hp-relics-vectors.json';lua_path=ROOT/'tests/fixtures/max-hp-relics-vectors.lua'
    generated='return '+lua(result['cases'])+'\n'
    result['luaSha256']=hashlib.sha256(generated.encode()).hexdigest()
    if args.check:
        assert json.loads(path.read_text(encoding='utf-8'))==result,'max HP oracle changed'
        assert lua_path.read_bytes()==generated.encode(),'max HP Lua oracle changed'
        print('MAX_HP_ORACLE_MATCH',len(result['cases']['health']),'health;',len(result['cases']['channels']),'full source channel cases')
    else:
        path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');lua_path.write_text(generated,encoding='utf-8')
