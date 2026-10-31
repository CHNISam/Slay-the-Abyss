"""Fixed319009 DeepBreath / EmptyDeckShuffle / Soul / ShuffleAction model.
Independent Java48/XS128 shuffle interpretation; never imports product Lua.
"""
import hashlib,json
from pathlib import Path
from sts1_combat_shuffle import ShuffleRandom
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source_identity(p,root):return p.relative_to(root).as_posix()
def build():
    model=ROOT/'tools/oracles/sts1_combat_shuffle.py';cases=[]
    for seed in ['7','42','-1']:
        for upgraded in [False,True]:
            for shape,draw,discard in [('draw-only',list(range(2,8)),[]),('mixed',list(range(5,8)),list(range(2,5))),('discard-only',[],list(range(2,8))),('singleton',list(range(3,8)),[2])]:
                rng=ShuffleRandom(seed);rng.shuffle([]);initial=rng.snapshot();trace=[]
                def shuffle(pile):
                    before=rng.snapshot();cards=list(pile);rng.shuffle(pile);row=rng.trace[-1]
                    trace.append(dict(before=before,beforeCards=cards,cards=list(pile),rawHex=row['rawHex'],after=rng.snapshot()))
                original_draw=list(draw);original_discard=list(discard)
                hooks=bool(discard)
                if discard:
                    shuffle(discard)
                    # EmptyDeck iterator removes from index0. Soul.shuffle calls
                    # addToTop immediately (ArrayList.add/end); Soul.update only
                    # animates/clears powers. No reversal or deferred insertion.
                    draw.extend(discard);discard=[]
                    shuffle(draw) # ShuffleAction(draw,false) has no callback.
                hand=[draw.pop()for _ in range(2 if upgraded else 1)]
                relics=['the_abacus','sundial']if upgraded else ['sundial','the_abacus']
                order=['block','energy']if upgraded else ['energy','block']
                cases.append(dict(seed=seed,upgraded=upgraded,shape=shape,relics=relics,effectOrder=order if hooks else [],drawBefore=original_draw,discardBefore=original_discard,initial=initial,trace=trace,hand=hand,draw=draw,discard=[1],after=rng.snapshot(),hooks=int(hooks),sundial=0 if hooks else 2,energy=7 if hooks else 5,block=6 if hooks else 0))
    return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',sourceFiles=SOURCE_FILES,
      generatorSha256=sha(Path(__file__)),inputSha256={source_identity(model,ROOT):sha(model)},
      boundary='Controlled real Combat.play and Inventory opening, not natural acquisition or PC frame timing.',cases=cases)
SOURCE_FILES={'cards/CardGroup.java': {'sha256': '03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8', 'gitBlob': '546405eea9d7dcbd855fe47471c55c92d086987c'}, 'cards/Soul.java': {'sha256': '8e4105a9df83d93ad4f66d35c54b63720e90f71b80c7594a6faa454d19b545c0', 'gitBlob': '1a8dd9aef1fff6140524b45063b89ea7bb69fcc8'}, 'cards/SoulGroup.java': {'sha256': 'c3b44b69f2ebcff77b8a1d49c492973900cc42d597d66c651c4f41399af031cb', 'gitBlob': '6cb6517e2fda3af6590cddd3053a6cc0bc12f78f'}, 'cards/colorless/DeepBreath.java': {'sha256': '53a9ccecf580f8b984f28689ae7eb8709e3cbb25dcfe044e567c67bce83fe4e3', 'gitBlob': '64681afcae64888129663a2e8749602cd167121f'}, 'actions/common/EmptyDeckShuffleAction.java': {'sha256': 'b4fc6be1df7caa1906705469500c40e81135a41614b54448346ddb0fec0bb2b2', 'gitBlob': '14cb880060af4f609ab3887048c4e02518bc5671'}, 'actions/common/ShuffleAction.java': {'sha256': '778652e6f1d1db01ceb83b906d0c15548a14aa4464244f5e82198524fb5405c3', 'gitBlob': '8def85d739f5124557cb652b9328c86658760b13'}, 'relics/Sundial.java': {'sha256': '98fc50fbc8a0f3baaa161f858d6de3d1efd89b29762785d9e65efbec10f8eda1', 'gitBlob': '4fba8af973b3338ecea8a480edc5ba57e59b3481'}, 'relics/Abacus.java': {'sha256': '5274d6820601725bb16b93154a3bd934c4e13a31b1b6f2889fa456c08991ef8d', 'gitBlob': '7dcf3160a1deabe5a9c97ffce8a610a8b2831814'}}
if __name__=='__main__':
    import sys
    result=json.dumps(build(),ensure_ascii=False,indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-deep-breath.json'
    if '--check'in sys.argv:assert path.read_text()==result,'oracle fixture drift'
    else:path.write_text(result)
