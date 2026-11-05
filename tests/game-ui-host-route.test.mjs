import test from 'node:test';
import {scenarios,windows,runPair} from './helpers/game-ui-host-equivalence.mjs';
for(const kind of ['route','chapters'])for(const [from,to]of windows(scenarios[kind]))test(`whole Host ${kind} boundaries ${from}-${to}`,()=>runPair({scenario:'short-'+kind,from,to}));
