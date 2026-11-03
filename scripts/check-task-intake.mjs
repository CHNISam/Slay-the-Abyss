import {readFileSync,readdirSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

function isDate(value) {
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
  const parsed=new Date(value+'T00:00:00Z');
  return !Number.isNaN(parsed.valueOf())&&parsed.toISOString().slice(0,10)===value;
}
function validPolicy(policy) {
  const sprint=policy?.sprint;
  const order=policy?.milestoneOrder;
  const ids=value=>value===undefined||Array.isArray(value)&&value.every(id=>/^TASK-\d+(?:\.\d+)*$/.test(id));
  return !!sprint&&typeof sprint.id==='string'&&!!sprint.id.trim()
    &&isDate(sprint.start)&&isDate(sprint.end)&&sprint.start<=sprint.end
    &&Array.isArray(order)&&JSON.stringify(order)===JSON.stringify(['m-7','m-8','m-9'])
    &&order.includes(sprint.primaryMilestone)
    &&ids(policy.parallelTaskIds)&&Array.isArray(policy.blockedUntilOwnerApproval)
    &&ids(policy.blockedUntilOwnerApproval)&&ids(policy.historicalM8TaskIds);
}
export function evaluateIntake({id,task,policy,today}) {
  const errors=[];
  if(!/^TASK-\d+(?:\.\d+)*$/.test(id||''))errors.push('invalid task identity');
  if(!task||task.id!==id)errors.push('task not found or identity mismatch');
  if(!validPolicy(policy)||!isDate(today))return {decision:'HOLD',reasons:[...errors,'sprint policy or current date invalid']};
  if(today<policy.sprint.start||today>policy.sprint.end)errors.push('sprint window expired/not started; Owner must refresh');
  if((policy.blockedUntilOwnerApproval||[]).includes(id))errors.push('explicit Owner approval required');
  if(task?.status!=='To Do')errors.push('already active, blocked or completed; inspect existing PR instead of duplicating');
  const phase=task?.milestone==='m-5'&&(policy.historicalM8TaskIds||[]).includes(id)?'m-8':task?.milestone;
  const isPrimary=phase===policy.sprint.primaryMilestone;
  const isParallel=!!task&&(policy.parallelTaskIds||[]).includes(id)
    &&task.milestone===policy.milestoneOrder[1];
  if(task&&!isPrimary&&!isParallel)errors.push('outside current Sprint intake lane');
  return {decision:errors.length?'HOLD':'ALLOW',reasons:errors};
}
export function localToday(timezone='Asia/Shanghai',date=new Date()) {
  const parts=new Intl.DateTimeFormat('en-US',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(date);
  const field=k=>parts.find(x=>x.type===k)?.value;
  return field('year')+'-'+field('month')+'-'+field('day');
}
export function loadTask(id,root='.') {
  const names=readdirSync(join(root,'backlog/tasks')).filter(n=>n.startsWith(id.toLowerCase()+' - ')&&n.endsWith('.md'));
  if(names.length!==1)return null;
  const s=readFileSync(join(root,'backlog/tasks',names[0]),'utf8');
  const header=s.replace(/^\uFEFF/,'').split(/^---\s*$/m)[1]||'';
  const scalar=k=>header.match(new RegExp('^'+k+':\\s*([^\\r\\n]+)','m'))?.[1].trim().replace(/^['"]|['"]$/g,'')||null;
  return {id:scalar('id'),status:scalar('status'),milestone:scalar('milestone')};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  const id=process.argv[2]||'';
  const policy=JSON.parse(readFileSync('config/sprint-intake.json','utf8'));
  const result=evaluateIntake({id,task:loadTask(id),policy,today:localToday(policy.timezone)});
  console.log(result.decision+' '+id);
  if(result.reasons.length){console.error(result.reasons.join('\n'));process.exitCode=1}
  else console.log('Still check open PRs, task claims and file ownership; this command does not claim the task.');
}
