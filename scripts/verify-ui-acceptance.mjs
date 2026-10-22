import { existsSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Critical information/actions from the approved PR19 specification. Decoration
// and animations may remain in the parity ledger; missing HP may not.
export const criticalUiChecks = {
  menu: ['start', 'instructions'], map: ['route', 'currentFloor', 'reachableNodes'],
  battle: ['actorHpAndMaxHp', 'block', 'energy', 'intent', 'cardText', 'enemyAction'],
  rewards: ['gold', 'cardAddedOrSkipped', 'returnToMap'],
  cardChoice: ['readableChoices', 'clearSelection'],
  camp: ['healOrUpgrade', 'upgradeInformation'],
  shop: ['readableGoods', 'separatePrice', 'soldOrUnaffordable', 'leave'],
  event: ['readableText', 'clearChoices', 'result'], treasure: ['reward', 'continue'],
  result: ['outcome', 'statistics', 'restart', 'platformSettlement'],
  deck: ['ownedCards', 'upgrades', 'close'],
};

export function reviewUiAcceptance(manifest, candidateHash, fileExists = existsSync) {
  const errors = [];
  for (const [screen, required] of Object.entries(criticalUiChecks)) {
    const row = manifest.screens?.[screen];
    if (!row || row.status !== 'pass') { errors.push(`${screen}: ${row?.status || 'no review'}`); continue; }
    if (row.candidateHash !== candidateHash) errors.push(`${screen}: evidence belongs to another candidate`);
    if (!row.baseline || !fileExists(row.baseline)) errors.push(`${screen}: approved baseline missing`);
    if (!row.screenshot || !fileExists(row.screenshot)) errors.push(`${screen}: actual game screenshot missing`);
    if (!row.reviewer || !row.reviewedAt) errors.push(`${screen}: screenshot comparison has not been reviewed`);
    for (const field of required) if (row.checks?.[field] !== true) errors.push(`${screen}: ${field} not verified in game`);
  }
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [manifestFile = 'docs/design/ui-acceptance.json', candidateFile] = process.argv.slice(2);
  if (!candidateFile) throw new Error('Usage: node scripts/verify-ui-acceptance.mjs <review.json> <candidate.gil>');
  const manifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
  const hash = createHash('sha256').update(readFileSync(candidateFile)).digest('hex');
  const errors = reviewUiAcceptance(manifest, hash);
  if (errors.length) { console.error('UI acceptance incomplete:\n' + errors.map(row => `- ${row}`).join('\n')); process.exitCode = 1; }
  else console.log('Critical UI information/actions accepted against approved baseline for this exact candidate.');
}
