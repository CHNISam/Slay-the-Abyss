import {existsSync,readFileSync} from 'node:fs';
import {dirname,join} from 'node:path';
import {fileRecord} from './evidence-files.mjs';
export function reusableUi(base,generated) {
 const receiptPath=join(dirname(base.path),'candidate.json');
 if(!existsSync(receiptPath))return null;
 const receipt=JSON.parse(readFileSync(receiptPath,'utf8'));
 if(receipt.candidate?.sha256!==base.sha256||receipt.statuses?.staticCheck!=='pass'
  ||receipt.productionManifest?.layout?.sha256!==fileRecord(join(generated,'game-ui.json')).sha256
  ||receipt.productionManifest?.templates?.sha256!==fileRecord(join(generated,'game-ui-templates.json')).sha256)return null;
 const image=receipt.readyCardArt?.imageTemplateIndex,group=receipt.readyCardArt?.containerTemplateIndex,
  background=receipt.officialBackground?.templateIndex;
 if(![image,group,background].every(n=>Number.isSafeInteger(n)&&n>0)||image===group)return null;
 if(receipt.officialPortraits?.imageTemplateIndex!==image||receipt.officialPortraits?.containerTemplateIndex!==group)return null;
 return {receipt:fileRecord(receiptPath),templateResults:{AbyssReadyCardImage:{templateIndex:image},
  AbyssReadyCardGroup:{templateIndex:group},AbyssOfficialBackgroundImage:{templateIndex:background}}};
}
