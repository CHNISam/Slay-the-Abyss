import test from 'node:test';
import{runRosterMutationPartition}from'./helpers/competition-roster-mutation-partition.mjs';
test('all original roster mutation assertions partition 2/4 (260 cases)',()=>runRosterMutationPartition(2));
