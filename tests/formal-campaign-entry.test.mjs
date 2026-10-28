import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { preRetirementSource, retirementSources } from './helpers/presentation-announcement-retirement.mjs';
import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';

const entryPath = 'src/lua/abyss_ui.lua';
const entry = preFormalEntrySource(entryPath,readFileSync(entryPath, 'utf8'));
const campaignHunk = '{ music = music, campaign = true, experimentalCharacters =';
const originalHunk = '{ music = music, experimentalCharacters =';
const digest = value => createHash('sha256').update(value).digest('hex');

test('current native entry rejects campaign and startup drift before historical projection', () => {
  const live = readFileSync(entryPath, 'utf8').replaceAll('\r\n', '\n');
  assert.notEqual(live, entry, 'the live selection entry is distinct from the historical entry');
  assert.equal(preRetirementSource(entryPath, live), retirementSources.beforeSources[entryPath]);
  assert.equal(preRetirementSource(entryPath, live.replaceAll('\n', '\r\n')),
    retirementSources.beforeSources[entryPath]);
  for (const mutation of [
    live.replace('campaign = true', 'campaign = false'),
    live.replace('campaign = true,', ''),
    live.replace('campaign = true,', 'campaign = true, campaign = true,'),
    live.replace('script:EnableUpdate(true)', 'script:EnableUpdate(false)'),
    live + '\n-- unrelated live drift\n',
  ]) {
    assert.notEqual(mutation, live, 'negative control must actually change the live source');
    assert.throws(() => preRetirementSource(entryPath, mutation),
      /unreviewed integrated retirement source drift: src\/lua\/abyss_ui\.lua/);
  }
});

test('formal campaign source proof reverses only the complete accepted entry opt-in', () => {
  assert.equal(digest(entry), '4fdb5660a96f00b3d24bfa5388d5eb9c364183996679d0b7aaaf772af1319677');
  assert.equal(entry.split(campaignHunk).length, 2);
  assert.equal(digest(entry.replace(campaignHunk, originalHunk)),
    'a362aec4bd440e1712c323ca3cc9007cc9cd232527520989b160e41b7366f3fb');
  assert.equal(retirementSources.afterSha256[entryPath],
    'a362aec4bd440e1712c323ca3cc9007cc9cd232527520989b160e41b7366f3fb');
  // Historical source provenance only: the live OnStart test below owns the
  // campaign behavior. Replaying old presentation bytes cannot certify it.
  assert.equal(preRetirementSource(entryPath, entry), retirementSources.beforeSources[entryPath]);
  assert.equal(preRetirementSource(entryPath, entry.replaceAll('\n', '\r\n')),
    retirementSources.beforeSources[entryPath]);
});

test('formal campaign source proof rejects disabled, missing, duplicate and unrelated source drift', () => {
  const mutations = [
    entry.replace('campaign = true', 'campaign = false'),
    entry.replace(campaignHunk, originalHunk),
    entry.replace('campaign = true,', 'campaign = true, campaign = true,'),
    entry.replace('originalCharacters = not', 'originalCharacters ='),
    entry.replace('script:EnableUpdate(true)', 'script:EnableUpdate(false)'),
    entry + '\n-- unrelated drift\n',
    null,
  ];
  for (const mutation of mutations) {
    assert.notEqual(mutation, entry);
    assert.throws(() => preRetirementSource(entryPath, mutation),
      /unreviewed integrated retirement source drift: src\/lua\/abyss_ui\.lua/);
  }
});

test('formal OnStart reaches Act2/3 and switches characters; missing history and keys keep Act4 locked', () => {
  const result = runLua('tests/lua/formal_campaign_entry.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /FORMAL_CAMPAIGN_ENTRY_PASS 3; controlled room completions; native\/natural NOT_RUN/);
});
