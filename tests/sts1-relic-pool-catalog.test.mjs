import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {canSpawn, drawRelic, rollTier, javaShuffle, screenlessReject, nonCampfireReject, tiers} from '../tools/oracles/sts1_relic_queues.mjs';

const read = path => readFileSync(path, 'utf8');
const json = path => JSON.parse(read(path));
const sha = text => createHash('sha256').update(text.replaceAll('\r\n', '\n')).digest('hex');
const catalog = json('docs/rules/evidence/sts1-relic-pool-catalog.json');
const identity = json('docs/rules/evidence/sts1-relic-source-identity.json');
const vectors = json('tests/fixtures/sts1-relic-pool-vectors.json');
const registration = read('tests/fixtures/sts1-relic-library-registration.tsv').trim().split(/\r?\n/).map(line => {
  const [library, tier, id] = line.split('\t'); return {library, tier, id};
});
const byId = new Map(catalog.relics.map(row => [row.id, row]));
const emptyQueues = () => Object.fromEntries(tiers.map(tier => [tier, []]));
const ids = rows => rows.map(row => row.id).sort();

function validateFacts(value) {
  assert.deepEqual(value.registrationOrder, registration.map(row => row.id));
  assert.deepEqual(value.relics.map(({id, library, tier}) => ({id, library, tier})), registration);
  assert.equal(new Set(value.relics.map(row => row.id)).size, registration.length);
  for (const row of value.relics) {
    assert.ok(identity.files[row.source], `${row.id} source identity`);
    assert.ok(row.dependencyGroups.length, `${row.id} effect dependency group`);
    assert.ok(row.scope === 'later-act-only' ? row.channels.length === 0 : row.channels.length > 0);
    for (const channel of row.channels) assert.ok(identity.files[value.acquisitionChannels[channel]?.source], `${row.id} channel ${channel}`);
    assert.equal(row.status, row.projectId ? 'existing-local-effect-not-full-pool-parity' : 'unimplemented');
  }
}

test('complete original registration facts retain all IDs, tiers, class boundaries and pending evidence', () => {
  validateFacts(catalog);
  assert.equal(catalog.sourceCommit, '319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.equal(identity.sourceCommit, catalog.sourceCommit);
  assert.equal(vectors.sourceCommit, catalog.sourceCommit);
  assert.deepEqual(catalog.queueInitializationOrder, tiers);
  assert.deepEqual(catalog.profile, {class: 'IRONCLAD', ascension: 0, act: 1, allRelicUnlocks: true, dailyMods: false, endless: false});
  for (const key of ['implementationEvidence', 'pcBinaryAuthentication', 'liveEvidence']) assert.equal(catalog[key], 'pending');
  assert.deepEqual(Object.fromEntries(tiers.map(tier => [tier, catalog.relics.filter(r => r.tier === tier).length])),
    {common: 33, uncommon: 30, rare: 28, shop: 17, boss: 22});
  assert.equal(catalog.relics.filter(r => r.scope === 'act1-special').length, 10);
  assert.equal(catalog.relics.filter(r => r.scope === 'later-act-only').length, 8);
  assert.equal(catalog.relics.filter(r => r.library === 'red').length, 11);
  assert.equal(catalog.relics.length, 149);
  for (const file of Object.values(identity.files)) {
    assert.match(file.sha256, /^[0-9a-f]{64}$/); assert.match(file.gitBlob, /^[0-9a-f]{40}$/); assert.ok(file.bytes > 0);
  }
  for (const path of ['helpers/RelicLibrary.java', 'dungeons/AbstractDungeon.java', 'rooms/MonsterRoomElite.java',
    'rewards/chests/AbstractChest.java', 'rewards/chests/BossChest.java', 'shop/ShopScreen.java', 'shop/StoreRelic.java',
    'neow/NeowReward.java', 'helpers/CardLibrary.java', 'rooms/CampfireUI.java', 'map/MapRoomNode.java']) assert.ok(identity.files[path]);
});

test('removing an unsupported relic, changing its tier or marking a missing effect implemented fails the fact guard', () => {
  for (const mutate of [
    value => value.relics.splice(value.relics.findIndex(row => row.id === 'PrismaticShard'), 1),
    value => {value.relics.find(row => row.id === 'WingedGreaves').tier = 'special';},
    value => {value.relics.find(row => row.id === 'Girya').status = 'implemented';},
  ]) {
    const changed = structuredClone(catalog); mutate(changed);
    assert.throws(() => validateFacts(changed));
  }
});

test('existing project effects are mapped honestly and the exact missing set is the original set difference', () => {
  const data = json('data/relics.json').relics;
  const mapped = catalog.relics.filter(row => row.projectId);
  assert.deepEqual(mapped.map(row => row.projectId).sort(), data.map(row => row.id).sort());
  for (const row of mapped) assert.equal(data.find(item => item.id === row.projectId).rarity, row.tier);
  const missingQueue = catalog.relics.filter(row => row.scope === 'act1-queue' && !row.projectId);
  assert.equal(missingQueue.length, 118);
  assert.equal(catalog.relics.filter(row => row.scope !== 'later-act-only' && !row.projectId).length, 128);
  assert.equal(catalog.relics.filter(row => row.tier === 'rare' && row.projectId).length, 0);
  assert.ok(missingQueue.some(row => row.id === 'PrismaticShard'));
  assert.ok(missingQueue.some(row => row.id === 'WingedGreaves'));
  assert.equal(catalog.summary.queueMissing, missingQueue.length);
});

test('host Java HashMap order and shuffle vectors keep provenance, all members and five RNG consumptions', () => {
  assert.equal(sha(read(vectors.generator)), vectors.generatorSha256);
  assert.equal(sha(read('tests/fixtures/sts1-relic-library-registration.tsv')), vectors.registrationSha256);
  const rng = json(vectors.rngInputFixture).seeded;
  assert.equal(vectors.cases.length, 12);
  for (const tier of tiers) {
    assert.deepEqual([...vectors.unshuffled[tier]].sort(), ids(catalog.relics.filter(row => row.tier === tier)));
    assert.notDeepEqual(vectors.unshuffled[tier], catalog.relics.filter(row => row.tier === tier).map(row => row.id));
  }
  for (const sample of vectors.cases) {
    assert.deepEqual(sample.randomLongHex, rng.find(row => row.seed === sample.seed).case.raw.slice(0, 5));
    assert.equal(sample.relicRngCounterAfter, 5);
    for (const tier of tiers) {
      const unlocked = vectors.unshuffled[tier].filter(id => !sample.locked.includes(id));
      const expected = javaShuffle(unlocked, sample.randomLongHex[tiers.indexOf(tier)]).filter(id => !sample.removedAfterShuffle.includes(id));
      assert.deepEqual(sample.queues[tier], expected, `${sample.seed} ${sample.profile} ${tier}`);
    }
  }
  const original = vectors.cases.find(row => row.seed === '0' && row.profile === 'all-unlocked');
  const owned = vectors.cases.find(row => row.profile === 'remove-owned-after-shuffle');
  for (const tier of tiers) assert.deepEqual(owned.queues[tier], original.queues[tier].filter(id => !owned.removedAfterShuffle.includes(id)));
  assert.equal(original.queues.common[0], 'MealTicket');
});

test('acquisition channels retain shop bans, Neow replacement, screenless exclusions and Act1 special reachability', () => {
  for (const id of ['The Courier', 'Smiling Mask', 'MawBank', 'Old Coin']) {
    assert.equal(byId.get(id).spawnGate.excludeRoom, 'shop');
    assert.ok(!byId.get(id).channels.includes('shop-normal'));
  }
  assert.deepEqual(byId.get('Black Blood').channels, ['boss-chest']);
  assert.ok(byId.get('Ectoplasm').channels.includes('neow-swap'));
  assert.equal(byId.get('NeowsBlessing').scope, 'act1-special');
  assert.deepEqual(byId.get('NeowsBlessing').channels, ['neow-lament']);
  assert.equal(catalog.relics.filter(row => row.channels.includes('face-trader')).length, 5);
  for (const id of screenlessReject) assert.ok(!byId.get(id).channels.includes('random-event-screenless'));
  for (const id of nonCampfireReject) assert.ok(!byId.get(id).channels.includes('black-star-extra'));
  for (const id of ["Nilry's Codex", "Nloth's Gift", 'Red Mask', 'Mark of the Bloom']) assert.equal(byId.get(id).scope, 'later-act-only');
  for (const id of ['PrismaticShard', 'WingedGreaves', 'Girya', 'Peace Pipe', 'Shovel', 'Question Card', 'Busted Crown', 'Prayer Wheel', 'Singing Bowl'])
    assert.ok(byId.get(id).dependencyNote.length > 30, `${id} explicit host dependency`);
});

test('spawn gates depend on real deck, room, starter replacement and campfire inventory', () => {
  const spawn = (id, context = {}) => canSpawn(byId.get(id).spawnGate, context);
  assert.equal(spawn('Bottled Flame', {deck: [{type: 'ATTACK', rarity: 'BASIC'}]}), false);
  assert.equal(spawn('Bottled Flame', {deck: [{type: 'ATTACK', rarity: 'COMMON'}]}), true);
  assert.equal(spawn('Bottled Lightning', {deck: [{type: 'SKILL', rarity: 'BASIC'}]}), false);
  assert.equal(spawn('Bottled Tornado', {deck: [{type: 'POWER', rarity: 'BASIC'}]}), true);
  assert.equal(spawn('Black Blood'), false); assert.equal(spawn('Black Blood', {owned: ['Burning Blood']}), true);
  assert.equal(spawn('The Courier', {room: 'shop'}), false); assert.equal(spawn('The Courier'), true);
  assert.equal(spawn('Ectoplasm', {act: 2}), false);
  for (const id of nonCampfireReject) {
    assert.equal(spawn(id, {owned: ['Girya', 'Peace Pipe']}), false);
    assert.equal(spawn(id, {owned: ['Girya']}), true);
    assert.equal(spawn(id, {floor: 48}), false);
    assert.equal(spawn(id, {floor: 48, endless: true}), true);
  }
  assert.equal(spawn('WingedGreaves', {floor: 40}), true); assert.equal(spawn('WingedGreaves', {floor: 41}), false);
});

test('complete 0..99 rarity partitions preserve original boundaries without renormalizing supported subsets', () => {
  const expected = {elite: [50, 33, 17], event: [50, 33, 17], shovel: [50, 33, 17], shop: [48, 34, 18],
    'small-chest': [75, 25, 0], 'medium-chest': [35, 50, 15], 'large-chest': [0, 75, 25]};
  for (const [channel, counts] of Object.entries(expected)) {
    const actual = ['common', 'uncommon', 'rare'].map(tier => Array.from({length: 100}, (_, roll) => rollTier(channel, roll)).filter(value => value === tier).length);
    assert.deepEqual(actual, counts, channel);
  }
  assert.equal(rollTier('elite', 82), 'uncommon'); assert.equal(rollTier('elite', 83), 'rare');
  assert.equal(rollTier('shop', 82), 'rare'); assert.throws(() => rollTier('shop', 100));
});

test('queue draw spends front/tail candidates, rejected IDs and empty-tier fallback in original direction', () => {
  const queues = {...emptyQueues(), common: ['front-rejected', 'middle', 'tail'], boss: ['boss-front', 'boss-tail']};
  assert.deepEqual(drawRelic(queues, 'common', {eligible: id => id !== 'front-rejected'}).consumed.map(row => row.id), ['front-rejected', 'tail']);
  assert.deepEqual(queues.common, ['middle']);
  assert.equal(drawRelic(queues, 'boss', {end: true}).requestedId, 'boss-front');
  const fallback = {...emptyQueues(), uncommon: ['upgraded-front', 'upgraded-tail']};
  assert.equal(drawRelic(fallback, 'shop', {end: true}).requestedId, 'upgraded-front');
  assert.deepEqual(fallback.uncommon, ['upgraded-tail']);
  const screenless = {...emptyQueues(), common: ['Whetstone', 'Anchor', 'Vajra']};
  assert.deepEqual(drawRelic(screenless, 'common', {reject: screenlessReject}).consumed.map(row => row.id), ['Whetstone', 'Anchor']);
  assert.deepEqual(screenless.common, ['Vajra']);
  const rejected = {...emptyQueues(), rare: ['Girya', 'Shovel', 'Calipers']};
  assert.deepEqual(drawRelic(rejected, 'rare', {reject: nonCampfireReject}).consumed.map(row => row.id), ['Girya', 'Shovel', 'Calipers']);
  assert.equal(drawRelic(emptyQueues(), 'rare').resolvedId, 'Circlet');
  assert.deepEqual(drawRelic(emptyQueues(), 'boss'), {requestedId: 'Red Circlet', resolvedId: 'Circlet', consumed: [{tier: 'boss', end: false, id: 'Red Circlet'}]});
});
