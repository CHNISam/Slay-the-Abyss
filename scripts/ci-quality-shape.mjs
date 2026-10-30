// One hosted Full shape for matrix expansion and current delivery evidence.
export const qualityShardMatrices=Object.freeze({
  windows:Object.freeze(Array.from({length:11},(_,i)=>i+1)),
  posix:Object.freeze(Array.from({length:9},(_,i)=>i+1)),
});
export const qualityShardJobs=Object.freeze([
  ...qualityShardMatrices.windows.map(i=>`rules (${i}/${qualityShardMatrices.windows.length})`),
  ...qualityShardMatrices.posix.map(i=>`engineering-posix (${i}/${qualityShardMatrices.posix.length})`),
]);
