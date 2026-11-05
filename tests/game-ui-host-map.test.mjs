import test from 'node:test';
import {mainWindows,runPair} from './helpers/game-ui-host-equivalence.mjs';
for(const index of [2, 3])for(const seed of [1,6]){const [from,to]=mainWindows[index];test(`whole Host map seed ${seed} boundaries ${from}-${to}`,()=>runPair({seed,from,to}));}
