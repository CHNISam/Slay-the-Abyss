import { statSync } from 'node:fs';
import { resolve, relative, isAbsolute } from 'node:path';

export function requireStartupEvidence(status, startedAt) {
  if (status.state !== 'succeeded') throw new Error(status.error || `Run ${status.state}`);
  const subscribed = status.steps?.some(step => step.step === 'log-subscribed' && step.clientScripts === true);
  if (!subscribed) throw new Error('Client script log subscription was not verified');
  if (!status.runDir || !status.log?.file) throw new Error('No run-specific client log');
  const inside = relative(resolve(status.runDir), resolve(status.log.file));
  if (inside.startsWith('..') || isAbsolute(inside)) throw new Error('Log belongs to another run');
  const file = statSync(status.log.file);
  if (!file.isFile() || file.mtimeMs < startedAt) throw new Error('Stale log predates this run');
  const prints = status.log.prints ?? [];
  if (!prints.some(row => row.clientScript && row.text === 'ABYSS_UI ready')) throw new Error('Client startup never reached ready');
  if (prints.some(row => row.clientScript && /ABYSS_UI failed|stack traceback/.test(row.text))) throw new Error('Client runtime fault in this run');
  return true;
}
