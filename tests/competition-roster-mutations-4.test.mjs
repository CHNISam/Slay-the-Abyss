import test from 'node:test';
import{runRosterMutationPartition}from'./helpers/competition-roster-mutation-partition.mjs';
test('all original roster mutation assertions partition 4/4 (256 cases)',()=>runRosterMutationPartition(4));
