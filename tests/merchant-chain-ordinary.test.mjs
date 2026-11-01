import test from 'node:test';
import {verify} from './helpers/merchant-chain.mjs';
test('independent merchant initial ordinary shop and sold-repeat rejection',()=>verify('0/ordinary'));
