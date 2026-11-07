import {readFileSync} from 'node:fs';
import {colorlessCatalogVm} from './colorless-catalog-vm.mjs';
const {variant,fixture,options}=JSON.parse(readFileSync(process.argv[2],'utf8'));
process.stdout.write(JSON.stringify(colorlessCatalogVm(variant,fixture,options)));
