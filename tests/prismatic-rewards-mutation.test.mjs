import test from'node:test';import{prismaticCase}from'./helpers/prismatic-rewards.mjs';
test('omitting precisely Prismatic shuffle-long consumption is rejected',()=>prismaticCase({omitLong:true}));
test('omitting only the duplicate retry Prismatic long is rejected',()=>prismaticCase({omitRetryLong:true}));
