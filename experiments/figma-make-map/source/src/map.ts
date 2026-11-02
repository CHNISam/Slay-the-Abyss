export type NodeType = 'battle' | 'elite' | 'unknown' | 'shop' | 'camp' | 'treasure' | 'boss'
export interface MapNode {
  id: string
  floor: number // 0..14
  xr: number // 0..1
  jy: number // px jitter
  type: NodeType
  next: string[]
}
export const FLOORS = 15

function rng(seed: number) {
  return () => {
    seed |= 0
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function generateMap(seed = 20261028): MapNode[][] {
  const r = rng(seed)
  const floors: MapNode[][] = []
  const counts = [3, 4, 4, 3, 4, 3, 4, 4, 3, 4, 3, 4, 3]
  for (let f = 0; f < FLOORS; f++) {
    const n = f === FLOORS - 1 ? 1 : counts[f % counts.length] - (f === 0 ? 0 : 0)
    const row: MapNode[] = []
    for (let i = 0; i < n; i++) {
      const base = n === 1 ? 0.5 : 0.08 + (0.84 * i) / (n - 1)
      row.push({
        id: `f${f}n${i}`,
        floor: f,
        xr: n === 1 ? 0.5 : base + (r() - 0.5) * 0.07,
        jy: Math.round((r() - 0.5) * 14),
        type: 'battle',
        next: [],
      })
    }
    floors.push(row)
  }
  // edges (non-crossing)
  for (let f = 0; f < FLOORS - 1; f++) {
    const a = floors[f]
    const b = floors[f + 1]
    const edges: [number, number][] = []
    const crosses = (i: number, j: number) => edges.some(([p, q]) => (p < i && q > j) || (p > i && q < j))
    const has = (i: number, j: number) => edges.some(([p, q]) => p === i && q === j)
    if (b.length === 1) a.forEach((_, i) => edges.push([i, 0]))
    else {
      a.forEach((_, i) => {
        const j = Math.round((i * (b.length - 1)) / Math.max(1, a.length - 1))
        edges.push([i, j])
      })
      a.forEach((_, i) => {
        if (r() < 0.55) {
          const j0 = edges.find(([p]) => p === i)![1]
          const j = j0 + (r() < 0.5 ? -1 : 1)
          if (j >= 0 && j < b.length && !has(i, j) && !crosses(i, j)) edges.push([i, j])
        }
      })
      b.forEach((_, j) => {
        if (!edges.some(([, q]) => q === j)) {
          const i = a.map((n, k) => [k, Math.abs(n.xr - b[j].xr)] as const).sort((x, y) => x[1] - y[1])[0][0]
          if (!crosses(i, j)) edges.push([i, j])
        }
      })
    }
    edges.forEach(([i, j]) => a[i].next.push(b[j].id))
  }
  // prune nodes without incoming (floor>0)
  for (let f = 1; f < FLOORS; f++) {
    const incoming = new Set(floors[f - 1].flatMap((n) => n.next))
    floors[f] = floors[f].filter((n) => incoming.has(n.id))
  }
  // types
  const pick = (f: number): NodeType => {
    const pool: [NodeType, number][] = [['battle', 46], ['unknown', 24]]
    if (f >= 3) pool.push(['shop', 7])
    if (f >= 4) pool.push(['camp', 9])
    if (f >= 5) pool.push(['elite', 14])
    let t = pool.reduce((s, p) => s + p[1], 0) * r()
    for (const [k, w] of pool) if ((t -= w) < 0) return k
    return 'battle'
  }
  floors.forEach((row, f) =>
    row.forEach((n) => {
      n.type = f === 0 ? 'battle' : f === 8 ? 'treasure' : f === 13 ? 'camp' : f === FLOORS - 1 ? 'boss' : pick(f)
    }),
  )
  return floors
}
