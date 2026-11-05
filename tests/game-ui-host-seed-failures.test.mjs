import test from 'node:test';
import {scenarios,windows,runPair} from './helpers/game-ui-host-equivalence.mjs';
for(const kind of ['clock', 'wide', 'full-source', 'map-failure', 'refresh-reentry', 'disable-live'])for(const [from,to]of windows(scenarios[kind]))test(`whole Host ${kind} boundaries ${from}-${to}`,()=>runPair({scenario:'short-'+kind,from,to,...(kind==='disable-live'&&to===7?{requiredBaselineMarker:'HOST_DISABLE_LIVE_INERT_PASS'}:{})}));
