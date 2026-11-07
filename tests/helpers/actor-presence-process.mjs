import {readFileSync} from 'node:fs';
import {actorPresenceVm} from './actor-presence-vm.mjs';
const {variant,fixture,options}=JSON.parse(readFileSync(process.argv[2],'utf8'));
process.stdout.write(JSON.stringify(actorPresenceVm(variant,fixture,options)));
