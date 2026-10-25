import { statSync, readFileSync } from 'node:fs';
import { resolve, join, basename } from 'node:path';
import { fileRecord, inside, sha256 } from './evidence-files.mjs';

export function requireStartupEvidence(status, expected, {decodeLog,parserVersion} = {}) {
  if (status.state !== 'succeeded') throw new Error(status.error || `Run ${status.state}`);
  const subscribed = status.steps?.some(step => step.step === 'log-subscribed' && step.clientScripts === true);
  if (!subscribed) throw new Error('Client script log subscription was not verified');
  if (!status.runDir || !status.log?.file) throw new Error('No run-specific client log');
  if (!expected || typeof expected !== 'object' || !expected.runId || !expected.buildId || !Number.isFinite(expected.startedAt)) throw new Error('Expected run/candidate context is required');
  if (status.runId !== expected.runId || basename(status.runDir) !== expected.runId || resolve(status.runDir)!==resolve(expected.runDir)) throw new Error('Evidence belongs to another run');
  const log=fileRecord(status.log.file,status.runDir);
  if (!log.bytes) throw new Error('Empty raw client log');
  if (statSync(log.path).mtimeMs < expected.startedAt) throw new Error('Stale log predates this run');
  const request=JSON.parse(readFileSync(inside(status.runDir,join(status.runDir,'request.json')),'utf8'));
  if (request.clientScriptLog!==true || resolve(request.runDir)!==resolve(status.runDir) || fileRecord(request.mapPath).path!==fileRecord(expected.mapPath).path || fileRecord(request.mapPath).sha256!==expected.candidateHash) throw new Error('Request does not match expected candidate/subscription');
  if (typeof decodeLog!=='function'||!parserVersion) throw new Error('A supported raw-log decoder/version is required');
  const bytes=readFileSync(log.path),parsed=decodeLog(bytes);
  if (parsed.sourceHash!==sha256(bytes) || parsed.nextOffset!=null || !Array.isArray(parsed.prints)) throw new Error('Incomplete raw-log decoding');
  const prints=parsed.prints;
  const comparable=rows=>rows.map(row=>({text:row.text,clientScript:row.clientScript===true}));
  if(status.log.truncated || JSON.stringify(comparable(status.log.prints??[]))!==JSON.stringify(comparable(prints))) throw new Error('Claimed prints differ from the raw log');
  const marker=prints.findIndex(row=>row.clientScript && row.text===`ABYSS_BUILD ${expected.buildId}`);
  if(marker<0 || !prints.slice(marker+1).some(row => row.clientScript && row.text === 'ABYSS_UI ready')) throw new Error('Client startup never reached ready for this build');
  if (prints.some(row => row.clientScript && /ABYSS_UI failed|stack traceback/.test(row.text))) throw new Error('Client runtime fault in this run');
  return {schemaVersion:1,status:'pass',runId:expected.runId,buildId:expected.buildId,candidateHash:expected.candidateHash,
    startedAt:new Date(expected.startedAt).toISOString(),log,parser:parserVersion,printCount:prints.length,expected,statusSnapshot:status,
    scope:'startup only; gameplay and screenshot review remain required'};
}
