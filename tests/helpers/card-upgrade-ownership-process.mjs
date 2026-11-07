import {readFileSync} from 'node:fs';
import {cardUpgradeVm} from './card-upgrade-ownership-vm.mjs';
const {variant,fixture,options}=JSON.parse(readFileSync(process.argv[2],'utf8'));
process.stdout.write(JSON.stringify(cardUpgradeVm(variant,fixture,options)));
