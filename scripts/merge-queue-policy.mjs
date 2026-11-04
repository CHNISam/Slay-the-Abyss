import {createHash} from 'node:crypto';

const canonical=value=>Array.isArray(value)?value.map(canonical):
 value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])])):value;

// Only the coordinator's ruleset-write authority can observe bypass_actors.
// CI may reconstruct this digest from the redacted read view ONLY to compare
// it with that coordinator's exact-HEAD authorization. updated_at binds hidden
// changes too; a missing timestamp or an explicitly nonempty bypass never passes.
export function queueRulesFingerprint(ruleset,{allowRedacted=false}={}) {
 if(ruleset?.id!==25870651||typeof ruleset.updated_at!=='string'||
  !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(ruleset.updated_at)||
  !Number.isFinite(Date.parse(ruleset.updated_at))||
  !Array.isArray(ruleset.rules)||!ruleset.conditions||
  (Object.hasOwn(ruleset,'bypass_actors')?
   !Array.isArray(ruleset.bypass_actors)||ruleset.bypass_actors.length!==0:!allowRedacted))
  throw Error('Queue rules require a versioned, explicitly empty bypass authorization');
 const {id,target,enforcement,conditions,rules}=ruleset,updated_at=new Date(ruleset.updated_at).toISOString();
 return createHash('sha256').update(JSON.stringify(canonical({id,target,enforcement,conditions,rules,updated_at,bypass_actors:[]}))).digest('hex');
}

export function queueRulesAttested(ruleset,admission) {
 try {
  const fingerprint=queueRulesFingerprint(ruleset,{allowRedacted:true}),members=JSON.parse(admission);
  return Array.isArray(members)&&members.length>0&&members.every(member=>member.rulesFingerprint===fingerprint);
 } catch {return false;}
}
