import test from 'node:test';import{cardConsumerCase}from'./helpers/card-consumers-source.mjs';
test('complete cardRng witness rejects one omitted duplicate identity retry draw',()=>cardConsumerCase({omitRetry:true}));
