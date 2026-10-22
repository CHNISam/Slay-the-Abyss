// Build source only. The caller supplies the graph returned by scene_add_graph;
// compiling, writing the test copy and checking it belong to the candidate build.
export function settlementGraphSource({ id, name } = {}) {
  if (!Number.isSafeInteger(id) || id <= 0) throw new TypeError('settlement graph id must be a positive safe integer from scene_add_graph');
  if (typeof name !== 'string' || !name.trim()) throw new TypeError('settlement graph name is required');
  return `/// <reference types="genshin-ts" />
import { g } from 'genshin-ts/runtime/core'
import { SettlementStatus } from 'genshin-ts/definitions/enum'

g.server({id:${id},name:${JSON.stringify(name)},variables:{settlementRequested:false}})
.onSignal('ABYSS_WIN',(evt,f)=>{
  if(f.get('settlementRequested'))return;
  f.set('settlementRequested',true);
  for(const player of f.getListOfPlayerEntitiesOnTheField())f.setPlayerSettlementSuccessStatus(player,SettlementStatus.Victory);
  f.printString('ABYSS_SETTLEMENT_VICTORY');
  f.settleStage();
})
.onSignal('ABYSS_LOSE',(evt,f)=>{
  if(f.get('settlementRequested'))return;
  f.set('settlementRequested',true);
  for(const player of f.getListOfPlayerEntitiesOnTheField())f.setPlayerSettlementSuccessStatus(player,SettlementStatus.Defeat);
  f.printString('ABYSS_SETTLEMENT_DEFEAT');
  f.settleStage();
})
`;
}
