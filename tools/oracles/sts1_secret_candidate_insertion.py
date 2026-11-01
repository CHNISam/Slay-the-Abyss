"""Independent fixed319 Skill/AttackFromDeckToHand candidate construction."""
import hashlib,json
from pathlib import Path
from sts1_potion_pool import Stream
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build():
 cases=[]
 for count,seed in [(0,'0'),(1,'1'),(2,'42'),(3,'0'),(4,'2')]:
  room_seed=str(int(seed)+1) # Explicit standard floor1 combat seed, without wrapping in this small vector range.
  rng=Stream(room_seed);trace=[];uids=[];initial=rng.snapshot()
  for ordinal in range(1,count+1):
   if not uids:uids.append(ordinal)
   else:
    maximum=len(uids)-1;before=rng.snapshot();value=rng.integer(0,maximum)
    trace.append(dict(maximum=maximum,value=value,before=before,after=rng.snapshot()))
    uids.insert(value,ordinal)
  cases.append(dict(count=count,seed=seed,roomSeed=room_seed,initial=initial,order=uids,trace=trace,after=rng.snapshot()))
 return dict(sourceCommit='319009d5df0a82d9fb0f23cc22322286c6a87ec0',
  sourceFilesSha256={
   'actions/unique/SkillFromDeckToHandAction.java':'8012275a388020431660827399c12ef917e256b503949e8a399e96bc067b7b4c',
   'actions/unique/AttackFromDeckToHandAction.java':'9ae47d904fca90c61d6702dfe1b9a804fd3302d7243b00a1c913ed9a183e84a2',
   'cards/colorless/SecretTechnique.java':'46f62e4da6f86f6ba9e36a1ede06b6e0f58588aa668e77b65a7c05bb28f98de2',
   'cards/colorless/SecretWeapon.java':'34dc60ddebbb6c46548579b21daaffb09aec995b57f69eeff4b64335e6b936be',
   'cards/CardGroup.java':'03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8'},
  generatorSha256=sha(Path(__file__)),
  inputSha256={'tools/oracles/sts1_potion_pool.py':sha(ROOT/'tools/oracles/sts1_potion_pool.py')},
  rule='First eligible adds without RNG; each later eligible inserts at inclusive random(existingSize-1). Source draw group iteration, not top-down draw order.',cases=cases)
if __name__=='__main__':
 import sys
 output=json.dumps(build(),indent=2)+'\n';path=ROOT/'tests/fixtures/sts1-secret-candidate-insertion.json'
 if '--check'in sys.argv:assert path.read_text()==output,'secret candidate oracle fixture drift'
 else:path.write_text(output)
