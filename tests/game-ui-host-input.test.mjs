import test from 'node:test';
import {mainWindows,runPair} from './helpers/game-ui-host-equivalence.mjs';
for(const index of [0, 1])for(const seed of [1,6]){const [from,to]=mainWindows[index];test(`whole Host input seed ${seed} boundaries ${from}-${to}`,()=>runPair({seed,from,to}));}
for(const scenario of ['deck','battle','map','node','potion','egg'])test(`whole Host synchronous ${scenario} constructor partial writes`,()=>runPair({scenario,from:1,to:1}));
