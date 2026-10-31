import test from'node:test';import{execFileSync}from'node:child_process';
import{prismaticCase}from'./helpers/prismatic-rewards.mjs';
test('Prismatic public reward chain matches independent full identity/retry/upgrade source trace',()=>{
 execFileSync('python',['tools/oracles/sts1_prismatic_rewards.py','--check']);prismaticCase();
});
