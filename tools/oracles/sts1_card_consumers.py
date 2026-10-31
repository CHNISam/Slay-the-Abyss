"""Independent source cardRng identities, retries and rarity interleaving.
Uses frozen source pool traversal and an independent XS128 interpreter, never
production Lua/card definitions/samplers. Fixed STS319009d5, A0/Act1, no mods.
"""
import hashlib,json,runpy,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
INPUT=ROOT/'data/reference/sts1-card-pools'
Random=runpy.run_path(str(ROOT/'tools/sts1-card-rng-oracle.py'))['Random']
def f32(n):return struct.unpack('>f',struct.pack('>f',n))[0]
def integer(rng,maximum):
    rng.counter+=1
    while True:
        raw=rng.raw();bits=raw>>1;value=bits%(maximum+1)
        if bits-value+maximum<1<<63:return value

def scenario(seed,pools):
    rng=Random(seed);offset=5;trace=[];stages=[];phase='neow';reward_retries=0;shop_retries=0
    def snapshot():return dict(cardRng=rng.snapshot(),cardRarityOffset=offset)
    def draw(maximum,kind='int'):
        before=rng.snapshot();value=integer(rng,maximum)
        row=dict(phase=phase,kind=kind,maximum=maximum,value=value,before=before,after=rng.snapshot())
        if kind=='between':row['minimum']=0
        trace.append(row);return value
    def upgrade():
        before=rng.snapshot();rng.counter+=1;sample=f32((rng.raw()>>40)*2**-24)
        trace.append(dict(phase=phase,kind='chance',chance=0.0,value=sample<0.0,before=before,after=rng.snapshot()))
        return False
    def rarity(context):
        value=draw(99)+offset
        rare,uncommon=(10,50)if context=='elite'else(9,46)if context=='shop'else(3,40)
        return 'RARE'if value<rare else'UNCOMMON'if value<uncommon else'COMMON'
    def reward(context,count):
        nonlocal offset,reward_retries
        cards=[];rarities=[];attempts=[]
        for slot in range(count):
            tier=rarity(context)
            if tier=='COMMON':offset=max(-40,offset-1)
            elif tier=='RARE':offset=5
            pool=pools['redReward'][tier];accepted=False
            while not accepted:
                card=pool[draw(len(pool)-1)];accepted=card not in cards
                attempts.append(dict(slot=slot+1,rarity=tier,sourceId=card,accepted=accepted))
                if not accepted:reward_retries+=1
            cards.append(card);rarities.append(tier)
        upgrades=[upgrade()if tier!='RARE'else False for tier in rarities]
        return dict(cards=cards,rarities=rarities,upgrades=upgrades,attempts=attempts,after=snapshot())
    initial=snapshot()
    ids=[];attempts=[]
    for slot in range(3):
        accepted=False
        while not accepted:
            card=pools['colorlessShopByRarity']['UNCOMMON'][draw(19,'between')];accepted=card not in ids
            attempts.append(dict(slot=slot+1,sourceId=card,accepted=accepted))
        ids.append(card)
    stages.append(dict(phase=phase,cards=ids,attempts=attempts,after=snapshot()))
    phase='orrery';groups=[reward('normal',3)for _ in range(5)]
    stages.append(dict(phase=phase,groups=groups,after=snapshot()))
    phase='shop';cards=[];attempts=[]
    for slot,kind in enumerate(['ATTACK','ATTACK','SKILL','SKILL','POWER']):
        accepted=False
        while not accepted:
            tier=rarity('shop')
            if kind=='POWER'and tier=='COMMON':tier='UNCOMMON'
            pool=pools['redShopTyped'][tier][kind];card=pool[draw(len(pool)-1)]
            accepted=slot not in [1,3]or card!=cards[slot-1]['sourceId']
            attempts.append(dict(slot=slot+1,rarity=tier,sourceId=card,accepted=accepted))
            if not accepted:shop_retries+=1
        cards.append(dict(sourceId=card,rarity=tier.lower()))
    for tier in ['UNCOMMON','RARE']:
        pool=pools['colorlessShopByRarity'][tier];cards.append(dict(sourceId=pool[draw(len(pool)-1)],rarity=tier.lower()))
    stages.append(dict(phase=phase,cards=cards,attempts=attempts,after=snapshot()))
    phase='wheel';groups=[reward('normal',4)for _ in range(2)] # real Question Card
    stages.append(dict(phase=phase,groups=groups,after=snapshot()))
    phase='elite_crown';groups=[reward('elite',2)] # Question Card + Crown:3+1-2
    stages.append(dict(phase=phase,groups=groups,after=snapshot()))
    return dict(seed=str(seed),initial=initial,stages=stages,trace=trace,rewardDuplicateRetries=reward_retries,shopDuplicateRetries=shop_retries)

def build():
    pools=json.loads((INPUT/'pools.json').read_text(encoding='utf-8'))['pools']
    seed=CHOSEN_SEED
    first=Random(seed);assert integer(first,5)==5,'controlled history must expose first-offer RANDOM_COLORLESS'
    case=scenario(seed,pools)
    assert case['rewardDuplicateRetries']>0 and case['shopDuplicateRetries']>0
    paths=['tools/sts1-card-rng-oracle.py','data/reference/sts1-card-pools/pools.json','data/reference/sts1-card-pools/registration.json']
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
        sourceFilesSha256={'dungeons/AbstractDungeon.java': '8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26', 'cards/CardGroup.java': '03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8', 'shop/Merchant.java': '2722226c13cfac4ee0cb6832c6f9e0b7dd4f9af713785faa38327972f80f967e', 'shop/ShopScreen.java': '5637a90f12386df48a323969ddf0c17b06e0288884a1b124fa62994822853855', 'rooms/ShopRoom.java': 'f8cadde291ebe73918166aa05ba9f5006c4aec7b80add7a39e03eb469699e988', 'rooms/AbstractRoom.java': '020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05', 'screens/CombatRewardScreen.java': '7929ca75599e96c076f9abe2c90576a606c87984174328d10533ada8ee37e70b', 'relics/Orrery.java': 'fdce89eb48ad1b0239a675ca329d1369ecea9bff9d049210df4d079394562d90', 'relics/PrayerWheel.java': '619a8d3903cd520d4fd5c94b0c4f690865686dc7a944254ba824d31447389473', 'neow/NeowEvent.java': '0ac56abd6001eb1452b06b9ccaefba3de3fc9e2d88588ac907be0a0afafa5a83', 'neow/NeowReward.java': 'b3a61dcf11b694d9dae54ad0a57f972388593051793097e5eb7204090af17f36'},
        generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        inputSha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
        pools={k:pools[k]for k in ['redReward','redShopTyped','colorlessShopByRarity']},case=case,
        boundary='Controlled public Run/Nodes chain; no PC binary/natural acquisition/current-device or arbitrary-modifier acceptance.')
CHOSEN_SEED=49
if __name__=='__main__':
    import sys
    path=ROOT/'tests/fixtures/sts1-card-consumers.json'
    expected=json.dumps(build(),ensure_ascii=False,indent=2)+'\n'
    if '--check'in sys.argv:assert path.read_text(encoding='utf-8')==expected,'card consumer fixture drift'
    else:path.write_text(expected,encoding='utf-8')
