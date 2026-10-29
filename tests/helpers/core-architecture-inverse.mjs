import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {preBattleRefactorLayer} from './battle-refactor-projection.mjs';

// Strip only exact reviewed core tails. Each complete prior source identity
// remains mandatory; the upstream Battle inverse then restores the CEC oracle.
export function preCoreArchitectureSource(path,source) {
  if(path!=='config/architecture.json')return source;
  source=source.replaceAll('\r\n','\n');
  const header='  "layers": {\n',start=source.indexOf(header);
  if(start<0)return source;
  const groups=[
    {rows:['abyss_run_initialization','abyss_run_transition','abyss_run_rooms','abyss_run_settlement','abyss_run_potions'],
      priorSha256:'bab439c579d813dc91a631e29aac4bff41237030efdd33a90a5b84158df7367d'},
    {rows:['abyss_nodes_common','abyss_nodes_entry','abyss_nodes_events','abyss_nodes_sources'],
      priorSha256:'0c15a29fa24a4284eb0760b750356b658eb02e28b71d23b46839520777222cdb',battle:true},
  ];
  for(const {rows,priorSha256,battle} of groups){
    const end=source.indexOf('\n  },',start);
    const tail=',\n'+rows.map(name=>`    "${name}": "core"`).join(',\n');
    if(end<0||source.slice(end-tail.length,end)!==tail)continue;
    assert.equal(source.indexOf(header),source.lastIndexOf(header),'one reviewed layers object');
    let prior=source.slice(0,end-tail.length)+source.slice(end);
    if(battle)prior=preBattleRefactorLayer(path,prior);
    assert.equal(createHash('sha256').update(prior).digest('hex'),priorSha256,
      'unreviewed integrated core registration base');
    source=prior;
  }
  return source;
}
