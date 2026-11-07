import {readFileSync} from 'node:fs';
import {beforeNativeMergeQueueWorkflow} from './merge-queue-workflow.mjs';
import {beforePosixConcurrencyWorkflow} from './posix-concurrency-workflow.mjs';
// Invert only complete reviewed bootstrap additions. Unknown/partial blocks are
// retained for the original immutable workflow and package guards to reject.
const {edits}=JSON.parse(readFileSync(new URL('./auto-merge-workflow.json',import.meta.url),'utf8'));
// Restore only the reviewed execution slack for immutable historical guards.
// Performance targets are not current execution deadlines. Partial or unrelated
// changes remain visible to the old whole-source identities.
export function beforeExecutionTimeoutWorkflow(text){
 const eol=text.includes('\r\n')?'\r\n':'\n';
 const changes=[
  ["    timeout-minutes: ${{ inputs.runner_pool == 'local-special' && 75 || 30 }}",
   "    # Thirty minutes is a performance target; allow host variance before killing work.\n    timeout-minutes: ${{ inputs.runner_pool == 'local-special' && 75 || 45 }}"],
  ['    # Separate hosted VMs keep generated files isolated and retain the original\n    # 20-minute budget. Weighted files execute once, serially per VM.',
   '    # Separate hosted VMs keep generated files isolated. Twenty minutes is a\n    # performance target; the hard guard allows host variance. Files execute once.'],
  ['    runs-on: ubuntu-24.04\n    timeout-minutes: 20\n','    runs-on: ubuntu-24.04\n    timeout-minutes: 30\n'],
  ['    needs: [impact, rules, fast, presentation, engineering-posix]\n    if: always()\n',
   '    needs: [impact, rules, fast, presentation, engineering-posix]\n    if: ${{ !cancelled() }}\n'],
  ['    needs: [impact, engineering-posix-shards, fast]\n    if: always()\n',
   '    needs: [impact, engineering-posix-shards, fast]\n    if: ${{ !cancelled() }}\n'],
 ].map(pair=>pair.map(value=>value.replaceAll('\n',eol)));
 if(changes.every(([,after])=>text.split(after).length===2))
  for(const [before,after]of changes)text=text.replace(after,before);
 return text;
}
export function beforeAutoMergeWorkflow(text){
 text=beforeExecutionTimeoutWorkflow(text);
 text=beforePosixConcurrencyWorkflow(text);
 if(text===null)return null;
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
