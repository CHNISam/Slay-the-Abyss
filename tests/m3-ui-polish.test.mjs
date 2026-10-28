import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {integration} from './helpers/presentation-m3-integration.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('PR256 and PR268 theme changes are exactly the reviewed visual fields, with all rule and art-layout values retained',()=>{
  const expected=JSON.parse(integration.beforeSources['data/presentation/ui_theme.json']);
  Object.assign(expected.color,{cardShadow:'#00000059',cardBody:'#161820',cardWell:'#0D0E12',
    rarity:{basic:'#34363C',common:'#8C929D',uncommon:'#3F7FC6',rare:'#D4A54A',curse:'#6B4A44'},
    rarityBand:{basic:'#24262B',common:'#3A3E46',uncommon:'#1F4677',rare:'#5E4111',curse:'#4A322E'}});
  expected.font.cost=24;
  expected.layout.card.trim={shadow:3,costOverhang:4,costRing:4,keyline:1,typeTag:[60,16]};
  expected.layout.battlePotions.origin=[-480,268];
  Object.assign(expected.layout.topBar,{note:'左侧按扫视顺序 生命 → 金币 → 消耗；右端 408..600 留给共用的卡组/退出按钮行。',
    goldIcon:[-420,28],gold:[-376,52],exhaustIcon:[-330,28],exhaust:[-292,44]});
  Object.assign(expected.layout.cardDrag,{aimDots:14,aimDot:[8,24]});
  Object.assign(expected.layout.enemyRow,{xFromFew:32,fewCount:3});
  // PR282 relocates only the existing version geometry and retires notices.
  expected.layout.nativeMenu.codeVersion=expected.layout.releaseNotes.menuVersion;
  delete expected.layout.releaseNotes;
  assert.deepEqual(JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8')),expected);
});

test('first UI batch keeps visual enemy slots, actual target hitboxes, lock colours and original hand-return cancellation aligned',()=>{
  const result=runLua('tests/lua/m3_ui_polish.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/M3_UI_POLISH_PASS counts=1,2,3,4,5/);
});
