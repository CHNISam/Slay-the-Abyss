import test from 'node:test';import{execFileSync}from'node:child_process';
import{cardConsumerCase}from'./helpers/card-consumers-source.mjs';
test('public Neow/Orrery/shop/Wheel/Crown identities preserve independent complete cardRng interleaving',()=>{
 execFileSync('python',['tools/oracles/sts1_card_consumers.py','--check']);cardConsumerCase();
});
