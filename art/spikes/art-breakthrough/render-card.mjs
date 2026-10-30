import { writeFileSync, existsSync } from 'node:fs'
import { renderPaintPng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { loadFit } from './fitlua.mjs'
import { cardPaint } from './card.mjs'
import { loadImages } from './lib.mjs'
const D = '/workspace/sta-art/.artifacts/art-breakthrough/card/'
const fp = process.argv[2] || D + 'illu350.lua'
const fit = !existsSync(fp) ? null : fp.endsWith('.json') ? JSON.parse((await import('node:fs')).readFileSync(fp, 'utf8')) : loadFit(fp)
const { items, counts } = cardPaint(fit, 130, 170, 1)
const images = await loadImages([...new Set(items.filter(i => i.imageId).map(i => i.imageId))])
writeFileSync(D + (process.argv[3] || 'card-sim.png'), renderPaintPng(items, 260, 340, { scale: 2, images }).data)
console.log(JSON.stringify(counts))
