"""Fixed-source ColorlessPotion -> DiscoveryAction independent RNG projection.
Source-only input: audited registration and srcColorless traversal. No production
Lua/card definitions/samplers are imported. Models open + one retrieval update,
not arbitrary PC waiting frames or the global UUID/cosmetic random source.
"""
import hashlib,json
from pathlib import Path
from sts1_potion_pool import Stream
ROOT=Path(__file__).resolve().parents[2]
INPUT=ROOT/'data/reference/sts1-card-pools'

def vectors():
    registration=json.loads((INPUT/'registration.json').read_text())['registration']
    cards={row['id']:row for row in registration}
    raw=json.loads((INPUT/'pools.json').read_text())['pools']['srcColorless']
    pool=[card for card in raw if 'HEALING' not in cards[card]['tags']]
    assert len(raw)==35 and len(pool)==34 and 'Bandage Up' not in pool
    rng=Stream('23');initial=rng.snapshot();uses=[];trace=[]
    def group(phase):
        chosen=[];attempts=[]
        while len(chosen)<3:
            before=rng.snapshot();index=rng.integer(0,len(pool)-1)
            card=pool[index];accepted=card not in chosen
            trace.append(dict(phase=phase,maximum=len(pool)-1,value=index,before=before,after=rng.snapshot()))
            attempts.append(dict(index=index,sourceId=card,accepted=accepted))
            if accepted:chosen.append(card)
        return dict(cards=chosen,attempts=attempts,after=rng.snapshot())
    for number in [1,2]:
        opened=group('open'+str(number))
        selection=next(i+1 for i,card in enumerate(opened['cards']) if cards[card]['cost']>0)
        retrieval=group('retrieval'+str(number))
        uses.append(dict(open=opened,selection=selection,selectedSourceId=opened['cards'][selection-1],
                         selectedBaseCost=cards[opened['cards'][selection-1]]['cost'],retrieval=retrieval))
    assert any(not a['accepted'] for u in uses for a in u['open']['attempts'])
    assert any(not a['accepted'] for u in uses for a in u['retrieval']['attempts'])
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
        sourceFilesSha256={
            'potions/AbstractPotion.java':'10b76a57d36ae4714928fe4c21ce8f352e8c0739eaa675bed5f199480886d888',
            'potions/ColorlessPotion.java':'014768bbe8eb8f20ff6653d18bdcf00b0aa2991eaabbf9c739500d5a7d798feb',
            'actions/unique/DiscoveryAction.java':'6d6832207fab2c93f725c990c8a12cb035cfb2b66f3e59f569bcee727d762478',
            'dungeons/AbstractDungeon.java':'8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26'},
        generatorSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        inputSha256={name:hashlib.sha256((INPUT/name).read_bytes()).hexdigest() for name in ['pools.json','registration.json']},
        seed='23',pool=pool,excludedHealing=[i for i in raw if i not in pool],initial=initial,uses=uses,trace=trace,
        boundary='Controlled public-use fixture. Not natural acquisition, complete PC frame replay, or official device acceptance.')
if __name__=='__main__':
    import sys
    path=ROOT/'tests/fixtures/sts1-colorless-potion-vectors.json'
    expected=json.dumps(vectors(),ensure_ascii=False,indent=2)+'\n'
    if '--check' in sys.argv:assert path.read_text()==expected,'colorless oracle fixture drift'
    else:path.write_text(expected)
