"""Independent shared cardRandomRng consumer chain from STS 319009d5.
Uses the frozen source registration/pool traversal and independent XS128 model;
never imports production Lua, local card definitions or production samplers.
Controlled combat inputs, not a natural campaign replay or frame-time oracle.
"""
import hashlib,json
from pathlib import Path
from sts1_potion_pool import Stream
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'data/reference/sts1-card-pools'

def build():
    pools=json.loads((BASE/'pools.json').read_text())['pools']
    rows=json.loads((BASE/'registration.json').read_text())['registration']
    cards={r['id']:r for r in rows}
    full=[i for rarity in ['COMMON','UNCOMMON','RARE'] for i in pools['srcRed'][rarity] if 'HEALING' not in cards[i]['tags']]
    attacks=[i for i in full if cards[i]['type']=='ATTACK']
    cases=[]
    for seed in ['0','1','42','-1','505']:
        rng=Stream(seed);trace=[];steps=[]
        def draw(purpose,maximum,boolean=False):
            before=rng.snapshot()
            if boolean:
                rng.counter+=1;value=bool(rng.raw()&1)
            else:value=rng.integer(0,maximum)
            trace.append(dict(purpose=purpose,boolean=boolean,value=value,before=before,after=rng.snapshot(),**({} if maximum is None else {'maximum':maximum})))
            return value
        def snapshot(label,**kw):steps.append(dict(label=label,after=rng.snapshot(),**{k:v for k,v in kw.items() if v is not None}))
        def discovery(purpose):
            out=[]
            while len(out)<3:
                card=attacks[draw(purpose,len(attacks)-1)]
                if card not in out:out.append(card)
            return out
        initial=rng.snapshot()
        # Controlled hand order; the played power is absent from eligible hand.
        eligible=['Defend_R','Bash','Impervious']
        zeroed=eligible[draw('Mummified Hand',2)];snapshot('power',zeroed=zeroed)
        proc=draw('Strange Spoon',None,True)
        first=None
        if not proc:first=full[draw('Dead Branch after played exhaust',len(full)-1)]
        snapshot('played_exhaust',spoonProc=proc,generated=first)
        offers=discovery('Discovery open');snapshot('discovery_open',offers=offers)
        retrieval=discovery('Discovery retrieval');snapshot('discovery_resolve',unusedRetrieval=retrieval)
        second=full[draw('Dead Branch after Elixir',len(full)-1)];snapshot('elixir',generated=second)
        # Burn and X-cost Whirlwind stay in hand but never consume cost rolls.
        hand=['Bash','Burn','Whirlwind','Anger']+([first] if first else [])+[offers[1],second]
        costs=[]
        for index,card in enumerate(hand):
            base=cards[card]['cost'];before=0 if (index==0 and zeroed=='Bash') or index==len(hand)-2 else base
            if base>=0:
                roll=draw('Snecko Oil',3);cost=before if roll==base else roll
            else:cost=base
            costs.append(dict(sourceId=card,cost=cost))
        snapshot('snecko',hand=costs)
        cases.append(dict(seed=seed,initial=initial,steps=steps,trace=trace))
    return dict(schemaVersion=1,sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
        sourceFilesSha256={'relics/StrangeSpoon.java': 'e319dca794cae7abfa9ecc18cedd3cb32ac6fd041d4c947e6ad012d03246526d', 'relics/DeadBranch.java': 'dbace8181345b67bb9c704b83dea61c9754c3268fc5d93c192f1bd47908c2d6f', 'relics/MummifiedHand.java': '48d8f5909f56fdbe6cf216bd60bcabeafe10082a3d3a760a769a855428db06a8', 'actions/unique/DiscoveryAction.java': '6d6832207fab2c93f725c990c8a12cb035cfb2b66f3e59f569bcee727d762478', 'actions/utility/UseCardAction.java': '90213939af6d7ec83dea01bb2feef4ba762a93400dc1535732e2eebcdb6cab0f', 'potions/SneckoOil.java': '64c9e9b9a632868db2e4e2409cc83cb76f21b8d92035ae8adc1d6c588c43c74a', 'actions/unique/RandomizeHandCostAction.java': 'a5c85fbd3fdfe510642f3c3f95de21ae93fc06d119a7ed65c9d9ca5679f1c887', 'dungeons/AbstractDungeon.java': '8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26'},
        boundary='Controlled combat chain only; public commands, source draw/identity projection, no natural acquisition or full PC frame execution.',
        generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        inputSha256={p:hashlib.sha256((BASE/p).read_bytes()).hexdigest() for p in ['pools.json','registration.json']},
        fullPool=full,attackPool=attacks,cases=cases)
if __name__=='__main__':
    import sys
    result=json.dumps(build(),ensure_ascii=False,indent=2)+'\n'
    path=ROOT/'tests/fixtures/sts1-card-random-chain.json'
    if '--check' in sys.argv:assert path.read_text()==result,'oracle fixture drift'
    else:path.write_text(result)
