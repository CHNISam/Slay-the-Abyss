import test from 'node:test';
import {verify} from './helpers/merchant-chain.mjs';
test('independent merchant Courier and Membership sequential discounts',()=>verify('-1/both'));
