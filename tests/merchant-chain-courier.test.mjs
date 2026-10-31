import test from 'node:test';
import {verify} from './helpers/merchant-chain.mjs';
test('independent merchant Courier initial and all four replacement classes',()=>verify('1/courier'));
