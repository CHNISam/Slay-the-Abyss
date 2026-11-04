import {readFileSync} from 'node:fs';
import {beforeNativeMergeQueueWorkflow} from './merge-queue-workflow.mjs';
// Invert only complete reviewed bootstrap additions. Unknown/partial blocks are
// retained for the original immutable workflow and package guards to reject.
const {edits}=JSON.parse(readFileSync(new URL('./auto-merge-workflow.json',import.meta.url),'utf8'));
export function beforeAutoMergeWorkflow(text){
 text=beforeNativeMergeQueueWorkflow(text);
 if(text===null)return null;
 for(const runner of ['ubuntu-slim','ubuntu-24.04']){
  const variant=edits.map(e=>({before:e.before.replaceAll('runs-on: ubuntu-slim','runs-on: '+runner),after:e.after.replaceAll('runs-on: ubuntu-slim','runs-on: '+runner)}));
  if(variant.every(e=>text.split(e.after).length===2)){
   for(const edit of variant)text=text.replace(edit.after,edit.before);
   return text;
  }
 }
 // Earlier immutable snapshots have different matrices/routing. Pass them
 // through unchanged; their own frozen hash guards retain responsibility.
 return /full-quality|Publish exact Full regression status|types: \[opened, synchronize, reopened, ready_for_review/.test(text)?null:text;
}
