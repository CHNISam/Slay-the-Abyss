import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { quoteCard, multiplierFromUint24, discountExistingPrice } from '../scripts/candidates/sts1-shop-card-price.mjs';

function checkLua(body) {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-price-'));
  const script = join(directory, 'case.lua');
  try {
    writeFileSync(script, `for _, module in ipairs({'tools/candidates/sts1_shop_price.lua', 'src/lua/abyss_shop_price.lua'}) do\nlocal price = dofile(module)\n${body}\nend\nprint('price candidate passed')\n`);
    const result = runLua(script);
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /price candidate passed/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
}

test('Lua bounded binary32 matches literal ties, carry, and precision boundaries', () => {
  const cases = [
    [0, 0], [2 ** -32, 2 ** -32], [256, 256],
    [1 + 2 ** -24, 1], // even lower significand
    [1 + 3 * 2 ** -24, 1 + 2 ** -22], // odd lower significand
    [2 - 2 ** -24, 2], // carry into next exponent
    [0.9266666, 0.9266666173934937],
    [0.8999999761581421, 0.8999999761581421],
    [2 ** -32 + 2 ** -56, 2 ** -32],
    [2 ** -32 + 3 * 2 ** -56, 2 ** -32 + 2 ** -54],
  ];
  for (const [input, expected] of cases) assert.equal(Math.fround(input), expected);
  checkLua(`for _, c in ipairs(${toLua(cases)}) do assert(price.roundPositiveBinary32(c[1]) == c[2]) end`);
});

test('Lua preserves all original price-vector groups and injected-input normalization', () => {
  const cases = [];
  for (const sample of [0, 8388608, 16777215]) {
    for (const rarity of ['common', 'uncommon', 'rare']) cases.push({ rarity, multiplier: multiplierFromUint24(sample) });
    for (const rarity of ['uncommon', 'rare']) cases.push({ rarity, color: 'colorless', multiplier: multiplierFromUint24(sample) });
  }
  for (const flags of [{sale:true}, {membership:true}, {courier:true,membership:true},
    {phase:'restock',courier:true,membership:true}, {sale:true,courier:true,membership:true}, {}]) {
    cases.push({ rarity:'common', multiplier:Math.fround(1.02), ...flags });
  }
  cases.push({rarity:'uncommon',multiplier:multiplierFromUint24(0),phase:'restock',courier:true});
  cases.push({rarity:'rare',multiplier:0.9266666});
  cases.push({rarity:'rare',color:'colorless',multiplier:1,courier:true});
  const vectors = cases.map(options => [options, quoteCard(options)]);
  checkLua(`for _, c in ipairs(${toLua(vectors)}) do
    local before = {}; for k,v in pairs(c[1]) do before[k]=v end
    assert(price.quoteCard(c[1]) == c[2]); assert(price.quoteCard(c[1]) == c[2])
    for k,v in pairs(before) do assert(c[1][k] == v) end
    for k,v in pairs(c[1]) do assert(before[k] == v) end
  end`);
});

test('Lua rounds either side of half-ULP ties at every supported exponent', () => {
  const values = [];
  for (let exponent = -32; exponent <= 7; exponent++) {
    const power = 2 ** exponent;
    for (const significand of [8388608, 8388609, 12582911, 16777215]) {
      const half = (significand + 0.5) * power / 8388608;
      for (const value of [half - power * 2 ** -51, half, half + power * 2 ** -51]) {
        values.push([value, Math.fround(value)]);
      }
    }
  }
  checkLua(`for i,c in ipairs(${toLua(values)}) do assert(price.roundPositiveBinary32(c[1]) == c[2], 'half ULP '..i) end`);
});

test('Lua uint24 endpoints and all supported existing integer prices match JS', () => {
  const samples = [0, 1, 559238, 8388608, 16777215];
  const prices = Array.from({length:199}, (_,value) => [value, discountExistingPrice(value)]);
  checkLua(`for _, c in ipairs(${toLua(samples.map(s=>[s,multiplierFromUint24(s)]))}) do
    assert(price.multiplierFromUint24(c[1]) == c[2]) end
    for _, c in ipairs(${toLua(prices)}) do assert(price.discountExistingPrice(c[1]) == c[2]) end`);
});

test('Lua rejects unsupported domains and malformed contracts without mutation', () => {
  checkLua(`
    local function rejected(fn, value) assert(not pcall(fn, value)) end
    for _, value in ipairs({-1, 1/0, -1/0, 0/0, '1', true, {}, 2^-33, 257}) do
      rejected(price.roundPositiveBinary32, value) end
    rejected(price.roundPositiveBinary32, nil)
    for _, value in ipairs({-1, 16777216, 0.5, 0/0, 1/0, '1', true, {}}) do
      rejected(price.multiplierFromUint24, value) end
    rejected(price.multiplierFromUint24, nil)
    for _, value in ipairs({-1, 1.5, 0/0, 1/0, '51', 199, true, {}}) do
      rejected(price.discountExistingPrice, value) end
    rejected(price.discountExistingPrice, nil)
    for _, value in ipairs({false, 'common', 1, {}}) do rejected(price.quoteCard, value) end
    rejected(price.quoteCard, nil)
    for _, patch in ipairs({
      {rarity='basic'}, {rarity='special'}, {rarity='toString'}, {rarity=false},
      {multiplier=0/0}, {multiplier=1/0}, {multiplier=0.89}, {multiplier=1.11}, {multiplier='1'},
      {color='unknown'}, {color='colorless'}, {phase='unknown'}, {phase='restock'},
      {phase='restock',courier=true,sale=true}, {color='colorless',rarity='rare',sale=true},
      {sale=1}, {courier='true'}, {membership=0}, {ascension=16}, {smilingMask=true},
      {[1]='array item'}
    }) do
      local options={rarity='common',multiplier=1}; for k,v in pairs(patch) do options[k]=v end
      rejected(price.quoteCard, options); assert(options.multiplier == patch.multiplier or options.multiplier == 1 or options.multiplier ~= options.multiplier)
    end
    rejected(price.quoteCard, setmetatable({rarity='common',multiplier=1}, {}))
  `);
});

// Sampling is test-data construction, not an implementation of merchant RNG.
for (let batch = 0; batch < 4; batch++) {
  test(`Lua binary32 differential batch ${batch + 1}/4 (1024 quotes and mappings)`, () => {
    let seed = (batch + 1) * 70001;
    const vectors = [];
    const samples = [];
    for (let index = 0; index < 1024; index++) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const sample = seed >>> 8;
      const colorless = index % 3 === 0;
      const restock = index % 2 === 0;
      const options = {
        rarity: colorless ? ['uncommon','rare'][index % 2] : ['common','uncommon','rare'][Math.floor(index / 3) % 3],
        color: colorless ? 'colorless' : 'colored', phase: restock ? 'restock' : 'initial',
        multiplier: index % 5 ? multiplierFromUint24(sample) : 0.9 + (sample / 16777216) * 0.2,
        courier: restock || index % 4 === 1, membership: index % 7 < 3,
        sale: !restock && !colorless && index % 5 === 0,
      };
      vectors.push([options, quoteCard(options)]);
      samples.push([sample, multiplierFromUint24(sample)]);
    }
    checkLua(`for i,c in ipairs(${toLua(vectors)}) do assert(price.quoteCard(c[1]) == c[2], 'quote '..i) end
      for i,c in ipairs(${toLua(samples)}) do assert(price.multiplierFromUint24(c[1]) == c[2], 'mapping '..i) end`);
  });
}
