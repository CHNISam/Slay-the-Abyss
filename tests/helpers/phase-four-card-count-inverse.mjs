import {prePhaseFourNecronomicurseCountSource} from './phase-four-necronomicurse-count-inverse.mjs';
// Test-only additive Bell coverage. The old complete render witness stays
// immutable; current execution keeps all old cards plus Bell in every class.
import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
export const phaseFourCardCounts=Object.freeze({
 path:'tests/lua/phase_four_presentation_render.lua',
 beforeSha256:'ea9d8031151557f4bd39ace9cccbf49e06fe9c3c58091ad1be2c3adc72b710cf',
 afterSha256:'28d64276d267ddc601c3e81e672a2e5f0ce042aab8b7c2e84c6c6b12c2f20e63',
 hunks:[
  {at:22,before:'  eq(#data.cards.cards,({ironclad=80,silent=90,defect=90,watcher=100})[id])',after:'  eq(#data.cards.cards,({ironclad=81,silent=91,defect=91,watcher=101})[id])'},
  {at:54,before:'local expected=0;for i=first,last do expected=expected+({160,180,180,200})[i]end',after:'local expected=0;for i=first,last do expected=expected+({162,182,182,202})[i]end'},
 ],
});
export function prePhaseFourCardCountSource(path,source){
 return restoreExactFixtureHunks(phaseFourCardCounts,path,prePhaseFourNecronomicurseCountSource(path,source));
}
