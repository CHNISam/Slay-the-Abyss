// Run the generated Lua in beyond-simulator's real Lua runtime (createStudio/playRun), screenshot via its host renderer.
import { readFileSync, writeFileSync } from 'node:fs'
import { createStudio } from '/workspace/tools/miliastra-beyond-simulator/studio/index.js'
import { renderPaintPng, renderScenePng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { loadImages } from './lib.mjs'
const A = '/workspace/sta-art/.artifacts/art-breakthrough/'
const s = createStudio()
s.patch({ op: 'setCanvas', canvasId: 'mobile-16-9' })
// server asset: strip demo children of n1
let g = s.get()
for (const n of g.tree.filter(t => t.parentId === 'n1')) s.patch({ op: 'remove', id: n.id })
s.patch({ op: 'selectAsset', assetType: 'client-control-template' })
for (const [kind, name] of [['image', 'IMG'], ['textbox', 'TXT'], ['container', 'BOX']]) s.patch({ op: 'addTemplate', kind, name })
g = s.get()
const idx = Object.fromEntries(g.tree.filter(t => t.depth === 0).map(t => [t.name, t.guid]))
// BOX container template comes with default size; make sure it has no visual children
s.patch({ op: 'selectAsset', assetType: 'server-control-template' })
let lua = readFileSync(A + 'pack/sta_art_scene.lua', 'utf8')
lua = lua.replace('local IMG_PREFAB = 0', `local IMG_PREFAB = ${idx.IMG}`).replace('local TXT_PREFAB = 0', `local TXT_PREFAB = ${idx.TXT}`).replace('local BOX_PREFAB = 0', `local BOX_PREFAB = ${idx.BOX}`)
writeFileSync(A + 'pack/sta_art_scene.sim.lua', lua)
s.patch({ op: 'addScript', controlId: 'n1', controlAsset: 'server-control-template', path: 'sta_art_scene', source: lua })
const t0 = performance.now()
let snap = s.playStart({ canvasId: 'mobile-16-9' })
const tBuild = performance.now() - t0
console.log('logs', JSON.stringify(snap.logs.slice(0, 5)), 'build ms', Math.round(tBuild))
const images = await loadImages([102005, 104003, 104004, 104007, 104008, 104009, 104010, 106029, 106033, 106037, 106038, 106039])
const shots = [[1, 'sim3-f001-idle.png'], [44, 'sim3-t1.5s-select1.png'], [36, 'sim3-t2.7s-select2.png'], [3, 'sim3-t2.8s-moving.png'], [70, 'sim3-t5.1s-select4.png']]
let frame = 0
const stepMs = []
for (const [n, f] of shots) {
  const t1 = performance.now(); for (let i = 0; i < n; i++) s.playStep(1 / 30, { observe: false }); stepMs.push((performance.now() - t1) / n)
  const v = s.playGet({ view: true }); frame += n
  writeFileSync(A + f, renderScenePng(v.scene, v.canvasWidth, v.canvasHeight, { images }).data)
  console.log(f, 'frame', v.frame, 'nodes', v.scene?.nodes?.length, 'paint', v.paint?.length)
}
console.log('logs-end', JSON.stringify(s.playGet().logs.slice(-3)));console.log('avg step ms', stepMs.map(x => x.toFixed(1)).join(','))
const v = s.playGet({ view: true }); const kinds = {}; (v.scene.nodes).forEach(x => kinds[x.primitive || x.kind] = (kinds[x.primitive || x.kind] || 0) + 1); console.log(JSON.stringify(kinds))
writeFileSync(A + 'pack/sim-project.save.json', JSON.stringify(s.archiveData ? s.archiveData() : s.get()))
// export attempt: choices + GIA
try {
  console.log('choices', JSON.stringify(s.exportChoices()).slice(0, 800))
} catch (e) { console.log('choices err', e.message) }
for (const kind of ['gia', 'client-gia', 'combined-gia', 'scripts', 'json']) {
  try { const r = s.exportData(kind); if (r?.data) { writeFileSync(A + 'pack/export-' + kind + (r.filename?.endsWith('.gia') ? '.gia' : '.json'), Buffer.from(r.data, 'base64')); console.log('export', kind, r.filename, r.warnings ? JSON.stringify(r.warnings).slice(0, 300) : '') } }
  catch (e) { console.log('export err', kind, e.message.slice(0, 200)) }
}
