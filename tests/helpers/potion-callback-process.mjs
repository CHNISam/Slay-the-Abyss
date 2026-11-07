import {readFileSync} from 'node:fs';
import {potionVm} from './potion-callback-vm.mjs';
const {variant,fixture,options}=JSON.parse(readFileSync(process.argv[2],'utf8'));
process.stdout.write(JSON.stringify(potionVm(variant,fixture,options)));
