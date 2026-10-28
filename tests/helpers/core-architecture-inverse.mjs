import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {preBattleRefactorLayer} from './battle-refactor-projection.mjs';

// Historical UI snapshots retain their original complete-source hashes. Strip
// only this reviewed core registration tail; the existing UI oracle still
// rejects every other byte of architecture drift after this projection.
export function preCoreArchitectureSource(path,source) {
  if(path!=='config/architecture.json')return source;
  source=source.replaceAll('\r\n','\n');
  const header='  "layers": {\n',start=source.indexOf(header);
  if(start<0)return source;
  const end=source.indexOf('\n  },',start);
  const rows=['abyss_nodes_common','abyss_nodes_entry','abyss_nodes_events','abyss_nodes_sources'];
  const tail=',\n'+rows.map(name=>`    "${name}": "core"`).join(',\n');
  if(end<0||source.slice(end-tail.length,end)!==tail)return source;
  assert.equal(source.indexOf(header),source.lastIndexOf(header),'one reviewed layers object');
  // Let the upstream exact Battle witness recover its original architecture;
  // its frozen hashes and the original complete CEC oracle remain unchanged.
  const prior=preBattleRefactorLayer(path,source.slice(0,end-tail.length)+source.slice(end));
  assert.equal(createHash('sha256').update(prior).digest('hex'),
    '0c15a29fa24a4284eb0760b750356b658eb02e28b71d23b46839520777222cdb',
    'unreviewed integrated core registration base');
  return prior;
}
