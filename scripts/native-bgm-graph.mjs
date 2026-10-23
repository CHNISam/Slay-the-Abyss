import { readFileSync } from 'node:fs';

export const nativeBgmSignals = Object.freeze(Object.fromEntries(
  ['map', 'battle', 'elite', 'boss', 'victory', 'defeat', 'stop'].map(cue => [cue, `ABYSS_BGM_${cue.toUpperCase()}`])));

export function loadNativeBgmConfig() {
  return JSON.parse(readFileSync(new URL('../data/presentation/native_bgm.json', import.meta.url), 'utf8'));
}

// Native single-player graph only. No audio files, timers or simulated playback.
// The caller must register all nativeBgmSignals and pass an actual scene_add_graph id.
export function nativeBgmGraphSource({ id, name, config = loadNativeBgmConfig() } = {}) {
  if (!Number.isSafeInteger(id) || id <= 0) throw new TypeError('BGM graph id must come from scene_add_graph');
  if (typeof name !== 'string' || !name.trim()) throw new TypeError('BGM graph name is required');
  const handlers = Object.entries(nativeBgmSignals).map(([cue, signal], index) => {
    const track = config.cues?.[cue];
    if (cue !== 'stop' && (!track || !Number.isSafeInteger(track.id) || track.id <= 0
      || !Number.isFinite(track.seconds) || track.seconds <= 0 || !Number.isInteger(track.volume)
      || track.volume < 0 || track.volume > 100 || typeof track.loop !== 'boolean')) {
      throw new TypeError(`Invalid native BGM candidate: ${cue}`);
    }
    const operation = cue === 'stop' ? 'f.startPausePlayerBackgroundMusic(player,false);'
      : `f.modifyPlayerBackgroundMusic(player,${track.id}n,0,${track.seconds},${track.volume}n,${track.loop},0,1,true);f.startPausePlayerBackgroundMusic(player,true);`;
    return `.onSignal('${signal}',(evt,f)=>{
  if(f.get('currentCue')===${index}n)return;
  for(const player of f.getListOfPlayerEntitiesOnTheField()){${operation}}
  f.set('currentCue',${index}n);
  f.printString('ABYSS_BGM_APPLIED ${cue}${track ? ` id=${track.id}` : ''}');
})`;
  });
  return `/// <reference types="genshin-ts" />
import { g } from 'genshin-ts/runtime/core'

g.server({id:${id},name:${JSON.stringify(name)},variables:{currentCue:-1n}})
${handlers.join('\n')}
`;
}
