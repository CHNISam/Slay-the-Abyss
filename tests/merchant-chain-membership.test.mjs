import test from 'node:test';
import {verify} from './helpers/merchant-chain.mjs';
test('independent merchant Membership purchase halves existing shelf without RNG',()=>verify('42/membership-purchase'));
