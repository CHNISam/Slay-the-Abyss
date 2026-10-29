import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { preRetirementSource, retirementSources } from './helpers/presentation-announcement-retirement.mjs';
import {preMobileQaSource,requireMobileQaSource} from './helpers/mobile-qa-source-inverse.mjs';
import {preFormalEntrySource} from './support/formal-entry-source-inverse.mjs';

const entryPath = 'src/lua/abyss_ui.lua';
const historicalEntry = preFormalEntrySource(entryPath,readFileSync(entryPath, 'utf8'));
const entry = historicalEntry.replace('{ music = music, campaign = true, experimentalCharacters =',
  '{ music = music, campaign = true, campaignProfile = "competition-two-act", experimentalCharacters =');
const campaignHunk = '{ music = music, campaign = true, experimentalCharacters =';
const competitionHunk = '{ music = music, campaign = true, campaignProfile = "competition-two-act", experimentalCharacters =';
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
    live.replace('campaignProfile = "competition-two-act",', ''),
    live.replace('competition-two-act', 'full-source'),
    live.replace('campaignProfile = "competition-two-act",', 'campaignProfile = "competition-two-act", campaignProfile = "competition-two-act",'),
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
  assert.equal(digest(entry), '6a073dda56608f8d4e8f6b9c922a43041f42ded9923c4c3281a3dd8f98deb864');
  assert.equal(entry.split(competitionHunk).length, 2);
  const acceptedEntry = entry.replace(competitionHunk, campaignHunk);
  assert.equal(digest(acceptedEntry), '4fdb5660a96f00b3d24bfa5388d5eb9c364183996679d0b7aaaf772af1319677');
  assert.equal(digest(acceptedEntry.replace(campaignHunk, originalHunk)),
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
    entry.replace('competition-two-act', 'full-source'),
    entry.replace('campaignProfile = "competition-two-act", ', ''),
    entry.replace('campaignProfile = "competition-two-act", ', 'campaignProfile = "competition-two-act", campaignProfile = "competition-two-act", '),
    entry.replace(competitionHunk, originalHunk),
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

test('competition host projection preserves the original history/interaction witness and rejects drift', () => {
  const path = 'src/lua/abyss_game_ui.lua';
  const source = readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
  const projection = JSON.parse(readFileSync('tests/fixtures/competition-two-act-host-projection.json', 'utf8'));
  assert.equal(projection.base, '19f715aa5ada0fa7b04c7b7ba8e46971617b3004');
  assert.equal(projection.beforeSha256, '37b8c0b4bf1d39c2fca26867d5d90e523f6c6f0d2669bc543bc0d73f9c94995f');
  assert.equal(preRetirementSource(path, source), retirementSources.beforeSources[path]);
  assert.equal(preRetirementSource(path, source.replaceAll('\n', '\r\n')), retirementSources.beforeSources[path]);
  // The current opening is exercised below; preserve this historical complete
  // witness through the exact whole-source migration, never field filtering.
  requireMobileQaSource(path, source);
  const witness = preMobileQaSource(path, source);
  for (const edit of projection.edits) {
    assert.equal(witness.split(edit.after).length, 2);
    assert.throws(() => preRetirementSource(path, witness.replace(edit.after, edit.before)),
      /unreviewed integrated retirement source drift/);
  }
  assert.throws(() => preRetirementSource(path, source + '\n-- unrelated drift\n'));
});

test('formal OnStart reaches the two-act endpoint through claim/skip, honest results and new-run restart', () => {
  const result = runLua('tests/lua/formal_campaign_entry.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /FORMAL_CAMPAIGN_ENTRY_PASS 4; controlled room completions; native\/natural NOT_RUN/);
});

// Keep the original future-campaign scenario under an explicit test-only full-source profile.
test('explicit full-source future/test host retains the original Act3 and locked Act4 scenario', () => {
  const result = runLua('tests/lua/full_source_campaign_entry.lua');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /FULL_SOURCE_CAMPAIGN_ENTRY_PASS 3; controlled room completions; native\/natural NOT_RUN/);
});
