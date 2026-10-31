"""Fixed-source merchant consumption and shelf interpreter, STS 319009d5.
No production Lua/catalog imports. Pool traversal and initial queues are existing
independent source/host-Java receipts; controlled external MathUtils seed is separate.
"""
import copy,hashlib,json,math,struct,sys
from pathlib import Path
from sts1_potion_pool import Stream,POOL
ROOT=Path(__file__).resolve().parents[2]
INPUTS=['tests/fixtures/sts1-merchant-sources.json','data/reference/sts1-card-pools/pools.json','data/reference/sts1-card-pools/registration.json','tests/fixtures/sts1-relic-pool-vectors.json','docs/rules/evidence/sts1-relic-pool-catalog.json','tools/oracles/sts1_potion_pool.py','tests/fixtures/economy-relic-seeds.json']
def read(p):return json.loads((ROOT/p).read_text(encoding='utf8'))
def f32(x):return struct.unpack('!f',struct.pack('!f',x))[0]
def mul(a,b):return f32(f32(a)*f32(b))
def rounded(x):return math.floor(x+.5)
class Oracle:
 def __init__(self,seed,courier,membership,membership_purchase=False):
  self.streams={k:Stream(seed) for k in ['merchant','card','potion']};self.external=Stream('6');self.trace={k:[] for k in self.streams};self.courier=courier;self.membership=membership;self.membership_purchase=membership_purchase
  self.pools=read(INPUTS[1])['pools'];self.cards={c['id']:c for c in read(INPUTS[2])['registration']}
  self.queues=copy.deepcopy(read(INPUTS[6])['membership']['queues']if membership_purchase else read(INPUTS[3])['cases'][0]['queues']);self.facts={r['id']:r for r in read(INPUTS[4])['relics']}
  self.owned=['Burning Blood']+(['The Courier']if courier else[])+(['Membership Card']if membership else[])
  self.deck=[dict(type='ATTACK',rarity='BASIC'),dict(type='SKILL',rarity='BASIC')];self.steps=[]
 def draw(self,owner,kind,lo=0,hi=1):
  rng=self.streams[owner];before=rng.snapshot()
  if kind=='int':value=rng.integer(lo,hi)
  else:
   rng.counter+=1;value=(rng.raw()>>40)/(1<<24)
   if kind=='floatBetween':value=f32(f32(lo)+mul(value,f32(hi-lo)))
  self.trace[owner].append(dict(kind=kind,minimum=lo,maximum=hi,value=value,before=before,after=rng.snapshot()))
  return value
 def discount(self,p):
  if self.courier:p=rounded(mul(p,.8))
  if self.membership:p=rounded(mul(p,.5))
  return p
 def card(self,kind=None,colorless=None,previous=None,restock=False):
  while True:
   if colorless:rarity=colorless;pool=self.pools['colorlessShopByRarity'][rarity.upper()]
   else:
    n=self.draw('card','int',0,99)+5;rarity='rare'if n<9 else 'uncommon'if n<46 else 'common'
    if kind=='POWER'and rarity=='common':rarity='uncommon'
    pool=self.pools['redShopTyped'][rarity.upper()][kind]
   if restock and not colorless:
    index=self.external.integer(0,len(pool)-1);self.external.counter-=1 # MathUtils primitive has no STS wrapper counter
   else:index=self.draw('card','int',0,len(pool)-1)
   selected=pool[index]
   if selected!=previous:break
  price=mul({'common':50,'uncommon':75,'rare':150}[rarity],self.draw('merchant','floatBetween',f32(.9),f32(1.1)))
  if colorless:price=mul(price,1.2)
  if restock:
   price=mul(price,.8)
   if self.membership:price=mul(price,.5)
   price=math.floor(price)
  else:price=math.floor(price)
  return dict(sourceId=selected,rarity=rarity,type=self.cards[selected]['type'],price=price,sale=False)
 def eligible(self,id):
  gate=self.facts[id]['spawnGate'];k=gate['kind']
  if k=='always':return True
  if k=='max-floor':return 1<=gate['floor']and gate.get('excludeRoom')!='shop'
  if k=='max-act':return 1<=gate['act']
  if k=='owns-relic':return gate['id']in self.owned
  if k=='card-type':return any(c['type']==gate['cardType']for c in self.deck)
  if k=='nonbasic-card-type':return any(c['type']==gate['cardType']and c['rarity']!='BASIC'for c in self.deck)
  if k=='campfire-limit':return sum(i in ['Peace Pipe','Shovel','Girya']for i in self.owned)<gate['maxCampfireRelics']
  raise AssertionError(k)
 def relic(self,slot,restock=False):
  rejected=[]
  while True:
   if slot==3 and not restock:tier='shop'
   else:
    n=self.draw('merchant','int',0,99);tier='common'if n<48 else'uncommon'if n<82 else'rare'
   while True:
    assert self.queues[tier],'fixture intentionally avoids exhausted-tier fallback'
    selected=self.queues[tier].pop()
    if self.eligible(selected):break
   if not restock or selected not in ['Old Coin','Smiling Mask','MawBank','The Courier']:break
   rejected.append(selected)
  rarity=self.facts[selected]['tier'];price=self.discount(rounded(mul({'common':150,'uncommon':250,'rare':300,'shop':150}[rarity],self.draw('merchant','floatBetween',f32(.95),f32(1.05)))))
  return dict(sourceId=selected,rarity=rarity,price=price,rejected=rejected)
 def potion(self):
  n=self.draw('potion','int',0,99);rarity='common'if n<65 else'uncommon'if n<90 else'rare'
  while True:
   i=self.draw('potion','int',0,32)
   if POOL[i][1]==rarity:break
  return dict(sourceId=POOL[i][0],rarity=rarity,price=self.discount(rounded(mul({'common':50,'uncommon':75,'rare':100}[rarity],self.draw('merchant','floatBetween',f32(.95),f32(1.05))))))
 def snap(self,label):
  self.steps.append(dict(label=label,cards=copy.deepcopy(self.shelf['cards']),relics=copy.deepcopy(self.shelf['relics']),potions=copy.deepcopy(self.shelf['potions']),states={k:s.snapshot()for k,s in self.streams.items()},queues=copy.deepcopy(self.queues),traceCounts={k:len(v)for k,v in self.trace.items()},externalWords=self.external.snapshot()['words']))
 def run(self):
  cards=[]
  for i,kind in enumerate(['ATTACK','ATTACK','SKILL','SKILL','POWER']):cards.append(self.card(kind=kind,previous=cards[-1]['sourceId']if i in [1,3]else None))
  cards.extend(self.card(colorless=r)for r in ['uncommon','rare'])
  sale=self.draw('merchant','int',0,4);cards[sale]['price']//=2
  for i,c in enumerate(cards):c['sale']=i==sale;c['price']=self.discount(c['price'])
  self.shelf=dict(cards=cards,relics=[self.relic(i)for i in [1,2,3]],potions=[self.potion()for _ in range(3)]);self.snap('initial')
  if self.membership_purchase:
   assert self.shelf['relics'][2]['sourceId']=='Membership Card'
   self.membership=True;self.owned.append('Membership Card')
   for group in self.shelf.values():
    for item in group:item['price']=rounded(mul(item['price'],.5))
   self.snap('membership')
  if self.courier:
   old=self.shelf['cards'][0];self.deck.append(self.cards[old['sourceId']]);self.shelf['cards'][0]=self.card(kind=old['type'],restock=True);self.snap('colored')
   old=self.shelf['cards'][5];self.deck.append(self.cards[old['sourceId']]);rarity='rare'if self.draw('merchant','float')<f32(.3)else'uncommon';self.shelf['cards'][5]=self.card(colorless=rarity,restock=True);self.snap('colorless')
   self.shelf['potions'][0]=self.potion();self.snap('potion')
   self.owned.append(self.shelf['relics'][0]['sourceId']);self.shelf['relics'][0]=self.relic(1,True);self.snap('relic')
  return dict(steps=self.steps,trace=self.trace)
def build():
 cases=[]
 for seed,courier,membership,purchase in [('0',False,False,False),('1',True,False,False),('-1',True,True,False),('42',False,False,True)]:
  o=Oracle(seed,courier,membership,purchase);cases.append(dict(caseId=f'{seed}/{"membership-purchase"if purchase else"both"if membership else"courier"if courier else"ordinary"}',seed=seed,relicSeed='2'if purchase else'0',courier=courier,membership=membership,membershipPurchase=purchase,**o.run()))
 return dict(schemaVersion=1,sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),inputSha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in INPUTS},cases=cases)
if __name__=='__main__':
 text=json.dumps(build(),indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-merchant-chain.json'
 if '--check'in sys.argv:assert path.read_text(encoding='utf8')==text,'merchant fixture drift'
 else:path.write_bytes(text.encode('utf8'))
