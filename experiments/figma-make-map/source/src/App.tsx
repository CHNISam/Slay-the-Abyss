import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { FLOORS, generateMap, type MapNode, type NodeType } from './map'
import { Bottle, Cards, Heart, Mora, NodeIcon } from './icons'

const TYPES: Record<NodeType, { name: string; color: string; desc: string }> = {
  battle: { name: '普通战斗', color: '#e4695a', desc: '迷渊魔物拦路,胜者得摩拉与卡牌。' },
  elite: { name: '精英', color: '#b79bea', desc: '凶险的守卫,战胜后可能掉落遗物。' },
  unknown: { name: '未知事件', color: '#8cc4e2', desc: '遗迹深处的低语,是机缘,亦或陷阱。' },
  shop: { name: '商店', color: '#7fd1b9', desc: '游商的摊位,购买卡牌、药水与遗物。' },
  camp: { name: '营地', color: '#ffa95c', desc: '篝火旁休整:恢复生命,或强化一张卡牌。' },
  treasure: { name: '宝箱', color: '#f6dfa4', desc: '尘封的古老宝箱,内藏一件遗物。' },
  boss: { name: '首领', color: '#ff5a4a', desc: '塔顶的主宰。击败它,方可踏入下一幕。' },
}
const ORDER: NodeType[] = ['battle', 'elite', 'unknown', 'shop', 'camp', 'treasure', 'boss']
const POTIONS = [
  { name: '愈疗药剂', color: '#e0605a' },
  { name: '迅捷药剂', color: '#6fb8e6' },
  null,
]

type St = 'current' | 'visited' | 'available' | 'future' | 'sealed'

function initialPath(floors: MapNode[][], upTo: number) {
  const p = [floors[0][1].id]
  const byId = new Map(floors.flat().map((n) => [n.id, n]))
  for (let f = 1; f <= upTo; f++) {
    const nx = byId.get(p[f - 1])!.next
    p.push(nx[(f + 1) % nx.length])
  }
  return p
}

export default function App() {
  const floors = useMemo(() => generateMap(), [])
  const nodes = useMemo(() => floors.flat(), [floors])
  const byId = useMemo(() => new Map(nodes.map((n) => [n.id, n])), [nodes])

  const [path, setPath] = useState<string[]>(() => initialPath(floors, 4))
  const [moving, setMoving] = useState<{ from: string; to: string } | null>(null)
  const [hover, setHover] = useState<string | null>(null)
  const [shake, setShake] = useState<string | null>(null)
  const [picked, setPicked] = useState<string | null>(null)
  const [sparks, setSparks] = useState<{ id: number; x: number; y: number }[]>([])
  const [toast, setToast] = useState<{ t: string; k: number } | null>(null)
  const [menu, setMenu] = useState<null | 'main' | 'help'>(null)
  const [legendOpen, setLegendOpen] = useState(true)
  const [legendHover, setLegendHover] = useState<NodeType | null>(null)
  const [legendPin, setLegendPin] = useState<NodeType | null>(null)
  const [vw, setVw] = useState(window.innerWidth)
  const [scrollW, setScrollW] = useState(window.innerWidth)

  const scroller = useRef<HTMLDivElement>(null)
  const bgRef = useRef<HTMLDivElement>(null)
  const pillL = useRef<HTMLDivElement>(null)
  const pillR = useRef<HTMLDivElement>(null)
  const drag = useRef({ down: false, moved: false, y: 0, top: 0, id: 0 })
  const sparkId = useRef(0)

  const compact = vw < 900
  const phone = vw < 640
  const gap = phone ? 84 : 100
  const padTop = 190
  const padBottom = 150
  const H = padTop + (FLOORS - 1) * gap + padBottom
  const headerH = phone ? 96 : 76
  const sideRes = compact ? 60 : legendOpen ? 230 : 110
  const mapW = Math.max(250, Math.min(760, scrollW - sideRes * 2))
  const inner = 34
  const pos = useCallback(
    (n: MapNode) => ({ x: inner + n.xr * (mapW - inner * 2), y: padTop + (FLOORS - 1 - n.floor) * gap + n.jy }),
    [mapW, gap],
  )

  const curId = path[path.length - 1]
  const cur = byId.get(curId)!
  const tokenId = moving ? moving.to : curId

  const reach = useMemo(() => {
    const s = new Set<string>()
    const walk = (id: string) => {
      if (s.has(id)) return
      s.add(id)
      byId.get(id)!.next.forEach(walk)
    }
    walk(curId)
    return s
  }, [curId, byId])

  const stateOf = (n: MapNode): St => {
    if (n.id === curId) return 'current'
    if (path.includes(n.id)) return 'visited'
    if (cur.next.includes(n.id)) return 'available'
    if (reach.has(n.id)) return 'future'
    return 'sealed'
  }

  const hoverPath = useMemo(() => {
    if (!hover || !reach.has(hover) || hover === curId) return null
    const find = (id: string, acc: string[]): string[] | null => {
      if (id === hover) return [...acc, id]
      for (const nx of byId.get(id)!.next) {
        const r = find(nx, [...acc, id])
        if (r) return r
      }
      return null
    }
    return find(curId, [])
  }, [hover, reach, curId, byId])
  const hoverEdges = useMemo(() => {
    const s = new Set<string>()
    hoverPath?.forEach((id, i) => i && s.add(`${hoverPath[i - 1]}>${id}`))
    return s
  }, [hoverPath])

  const say = (t: string) => setToast({ t, k: Date.now() })
  useEffect(() => {
    if (!toast) return
    const h = setTimeout(() => setToast(null), 2600)
    return () => clearTimeout(h)
  }, [toast])

  // layout / scroll
  useEffect(() => {
    const on = () => {
      setVw(window.innerWidth)
      if (scroller.current) setScrollW(scroller.current.clientWidth)
    }
    on()
    window.addEventListener('resize', on)
    return () => window.removeEventListener('resize', on)
  }, [])
  const scrollToNode = useCallback(
    (n: MapNode, smooth: boolean) => {
      const el = scroller.current
      if (!el) return
      el.scrollTo({ top: pos(n).y - el.clientHeight * 0.6, behavior: smooth ? 'smooth' : 'auto' })
    },
    [pos],
  )
  const first = useRef(true)
  useEffect(() => {
    if (first.current) {
      first.current = false
      scrollToNode(cur, false)
    }
  }, [cur, scrollToNode])

  const onScroll = () => {
    const s = scroller.current!.scrollTop
    if (bgRef.current) bgRef.current.style.transform = `translate3d(0, ${-s * 0.1}px, 0)`
    if (pillL.current) pillL.current.style.backgroundPositionY = `${-s * 0.55}px`
    if (pillR.current) pillR.current.style.backgroundPositionY = `${-s * 0.55}px`
  }

  // drag
  const pd = (e: React.PointerEvent) => {
    if (e.pointerType !== 'mouse' || e.button !== 0) return
    drag.current = { down: true, moved: false, y: e.clientY, top: scroller.current!.scrollTop, id: e.pointerId }
  }
  const pm = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d.down) return
    const dy = e.clientY - d.y
    if (!d.moved && Math.abs(dy) > 5) {
      d.moved = true
      scroller.current!.setPointerCapture(d.id)
    }
    if (d.moved) scroller.current!.scrollTop = d.top - dy
  }
  const pu = () => {
    const d = drag.current
    d.down = false
    if (d.moved) setTimeout(() => (d.moved = false), 0)
  }

  const choose = (n: MapNode) => {
    if (drag.current.moved || moving) return
    const st = stateOf(n)
    const t = TYPES[n.type]
    if (st === 'current') return say('你正站在此处')
    if (st === 'visited') return say('来路已定,无法折返')
    if (st === 'sealed' || st === 'future') {
      setShake(n.id)
      setTimeout(() => setShake(null), 400)
      return say(st === 'sealed' ? `此路已断绝 · 无法前往${t.name}` : `距离尚远 · 先选择相邻的路径`)
    }
    // legal
    setMoving({ from: curId, to: n.id })
    setPicked(n.id)
    setHover(null)
    const p = pos(n)
    const ns = Array.from({ length: 10 }, () => {
      const a = Math.random() * Math.PI * 2
      const r = 22 + Math.random() * 28
      return { id: ++sparkId.current, x: p.x, y: p.y, sx: Math.cos(a) * r, sy: Math.sin(a) * r - 12 }
    })
    setSparks(ns as never)
    setTimeout(() => {
      setPath((pp) => [...pp, n.id])
      setMoving(null)
      setPicked(null)
      setSparks([])
      say(n.type === 'boss' ? '抵达塔顶 · 首领在等待着你' : `第 ${n.floor + 1} 层 · 进入${t.name}(模拟)`)
      scrollToNode(n, true)
    }, 800)
  }

  const reset = () => {
    setPath(initialPath(floors, 0).slice(0, 1))
    setMenu(null)
    setTimeout(() => scrollToNode(floors[0][1], true), 30)
    say('地图已重置,回到第 1 层')
  }

  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && setMenu(null)
    window.addEventListener('keydown', k)
    return () => window.removeEventListener('keydown', k)
  }, [])

  const filter = legendPin ?? legendHover
  const embers = useMemo(
    () => Array.from({ length: 26 }, () => ({ l: Math.random() * 100, s: 2 + Math.random() * 2.5, d: 9 + Math.random() * 14, dl: -Math.random() * 20, dx: (Math.random() - 0.5) * 120 })),
    [],
  )

  const iconSize = (n: MapNode) => (n.type === 'boss' ? (phone ? 54 : 66) : phone ? 26 : 32)
  const hovered = hover ? byId.get(hover) : null

  // edges
  const edges = nodes.flatMap((a) => a.next.map((b) => ({ a: a.id, b, k: `${a.id}>${b}` })))
  const edgeClass = (a: string, b: string, k: string) => {
    const ia = path.indexOf(a)
    if (ia >= 0 && path[ia + 1] === b) return 'walked'
    if (hoverEdges.has(k)) return 'preview'
    if (a === curId) return 'avail'
    if (reach.has(a) && reach.has(b)) return 'future'
    return 'sealed'
  }
  const curve = (a: MapNode, b: MapNode) => {
    const p = pos(a), q = pos(b)
    const m = (p.y + q.y) / 2
    return `M${p.x} ${p.y} C${p.x} ${m},${q.x} ${m},${q.x} ${q.y}`
  }
  const order = ['sealed', 'future', 'walked', 'avail', 'preview']

  const tokenPos = pos(byId.get(tokenId)!)
  const floorNo = cur.floor + 1

  return (
    <div className="relative h-full w-full select-none overflow-hidden" style={{ background: '#0b0606' }}>
      {/* depth backdrop */}
      <div className="absolute inset-0" style={{ background: 'radial-gradient(90% 70% at 50% 55%, #1b1210 0%, #0f0909 55%, #070303 100%)' }} />
      <div ref={bgRef} className="pointer-events-none absolute inset-0 grid place-items-center will-change-transform">
        <svg width="900" height="900" viewBox="-450 -450 900 900" fill="none" stroke="#c9a15e" style={{ opacity: 0.1, animation: 'slowspin 300s linear infinite' }}>
          <circle r="420" strokeWidth="1" /><circle r="380" strokeWidth="3" strokeDasharray="2 10" strokeLinecap="round" />
          <circle r="300" strokeWidth="1" /><circle r="210" strokeWidth="1.5" />
          <rect x="-150" y="-150" width="300" height="300" transform="rotate(45)" strokeWidth="1.5" />
          <rect x="-106" y="-106" width="212" height="212" strokeWidth="1" />
          {Array.from({ length: 48 }, (_, i) => <line key={i} x1="0" y1="-420" x2="0" y2={i % 4 ? -408 : -394} transform={`rotate(${i * 7.5})`} strokeWidth="1.5" />)}
        </svg>
      </div>
      <div className="fog a" /><div className="fog b" />
      <div className="absolute inset-0 overflow-hidden">
        {embers.map((e, i) => (
          <span key={i} className="ember" style={{ left: `${e.l}%`, width: e.s, height: e.s, animationDuration: `${e.d}s`, animationDelay: `${e.dl}s`, ['--dx' as never]: `${e.dx}px` }} />
        ))}
      </div>
      <div ref={pillL} className="pillar" style={{ left: compact ? 4 : 56 }} />
      <div ref={pillR} className="pillar" style={{ right: compact ? 4 : 'calc(230px + 20px)', display: compact ? 'none' : 'block' }} />

      {/* scroller */}
      <div
        ref={scroller}
        onScroll={onScroll}
        onPointerDown={pd} onPointerMove={pm} onPointerUp={pu} onPointerCancel={pu}
        className="map-scroller no-scrollbar absolute inset-0 overflow-y-auto"
        style={{ cursor: drag.current.moved ? 'grabbing' : 'grab', paddingTop: headerH * 0.2, touchAction: 'pan-y' }}
      >
        <div className="relative mx-auto" style={{ width: mapW, height: H }}>
          <svg className="absolute inset-0 overflow-visible" width={mapW} height={H}>
            <defs>
              <mask id="gapmask" maskUnits="userSpaceOnUse" x="-40" y="0" width={mapW + 80} height={H}>
                <rect x="-40" y="0" width={mapW + 80} height={H} fill="#fff" />
                {nodes.map((n) => { const p = pos(n); return <circle key={n.id} cx={p.x} cy={p.y} r={n.type === 'boss' ? (phone ? 34 : 42) : phone ? 21 : 25} fill="#000" /> })}
              </mask>
              <radialGradient id="pool"><stop offset="0" stopColor="#e9c77b" stopOpacity=".22" /><stop offset="1" stopColor="#e9c77b" stopOpacity="0" /></radialGradient>
            </defs>
            <ellipse cx={pos(cur).x} cy={pos(cur).y + 8} rx="170" ry="110" fill="url(#pool)" />
            <g mask="url(#gapmask)" strokeLinecap="round" fill="none">
              {order.map((cls) =>
                edges.filter((e) => edgeClass(e.a, e.b, e.k) === cls).map((e) => {
                  const d = curve(byId.get(e.a)!, byId.get(e.b)!)
                  if (cls === 'sealed') return <path key={e.k} d={d} stroke="#4a3b2c" strokeOpacity=".5" strokeWidth="2.2" strokeDasharray="0.1 9" />
                  if (cls === 'future') return <path key={e.k} d={d} stroke="#a88f68" strokeOpacity=".75" strokeWidth="2.8" strokeDasharray="0.1 8" />
                  if (cls === 'walked') return <g key={e.k}><path d={d} stroke="#e9c77b" strokeOpacity=".35" strokeWidth="9" style={{ filter: 'blur(4px)' }} /><path d={d} stroke="#f0cf86" strokeWidth="3.2" /></g>
                  if (cls === 'avail') return <path key={e.k} d={d} className="edge-flow" stroke="#f6dfa4" strokeWidth="3.2" strokeDasharray="3 11" style={{ filter: 'drop-shadow(0 0 4px #e9c77b)' }} />
                  return <path key={e.k} d={d} className="edge-flow" stroke="#fff3c9" strokeWidth="4" strokeDasharray="3 11" style={{ filter: 'drop-shadow(0 0 6px #f6dfa4)' }} />
                }),
              )}
              {moving && <path key={moving.to} d={curve(byId.get(moving.from)!, byId.get(moving.to)!)} pathLength={1} className="edge-draw" stroke="#fff0bd" strokeWidth="4" style={{ filter: 'drop-shadow(0 0 8px #f6dfa4)' }} />}
            </g>
          </svg>

          {/* boss light shaft */}
          {(() => { const b = pos(floors[FLOORS - 1][0]); return <div className="pointer-events-none absolute" style={{ left: b.x - 160, top: b.y - 150, width: 320, height: 300, background: 'radial-gradient(closest-side, rgba(255,90,74,.2), transparent)' }} /> })()}

          {nodes.map((n) => {
            const st = stateOf(n)
            const p = pos(n)
            const t = TYPES[n.type]
            const sz = iconSize(n)
            const hit = n.type === 'boss' ? sz + 20 : 56
            const color = st === 'available' ? t.color : st === 'visited' ? '#8a7352' : st === 'future' ? '#bdb7aa' : '#5b4c3e'
            const op = st === 'visited' ? 0.62 : st === 'future' ? 0.7 : st === 'sealed' ? 0.5 : 1
            const hot = hover === n.id && st !== 'available'
            return (
              <button
                key={n.id}
                aria-label={`${t.name} 第${n.floor + 1}层`}
                className={`node ${st} ${shake === n.id ? 'shake' : ''} ${filter && filter !== n.type ? 'dim' : ''} ${picked === n.id ? 'picked' : ''} ${hot ? 'hot' : ''}`}
                style={{ left: p.x, top: p.y, width: hit, height: hit, color, opacity: st === 'current' ? 0 : op, ['--c' as never]: t.color, zIndex: hover === n.id ? 8 : 2, cursor: st === 'available' ? 'pointer' : st === 'sealed' || st === 'future' ? 'not-allowed' : 'default' }}
                onClick={() => choose(n)}
                onPointerEnter={() => setHover(n.id)}
                onPointerLeave={() => setHover((h) => (h === n.id ? null : h))}
                onFocus={() => setHover(n.id)}
                onBlur={() => setHover((h) => (h === n.id ? null : h))}
              >
                <NodeIcon type={n.type} size={sz} />
              </button>
            )
          })}

          {sparks.map((s: any) => <span key={s.id} className="spark" style={{ left: s.x, top: s.y, ['--sx' as never]: `${s.sx}px`, ['--sy' as never]: `${s.sy}px` }} />)}

          {/* hero token */}
          <div className={`token ${moving ? 'hop' : ''}`} style={{ transform: `translate(${tokenPos.x}px, ${tokenPos.y}px)` }}>
            <div className="hopper" style={{ position: 'absolute', left: -28, top: -34 }}>
              <div className="bob">
                <svg width="56" height="68" viewBox="0 0 56 68" style={{ filter: 'drop-shadow(0 6px 8px rgba(0,0,0,.7)) drop-shadow(0 0 12px rgba(233,199,123,.55))', overflow: 'visible' }}>
                  <defs>
                    <linearGradient id="tk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#fff0bd" /><stop offset=".5" stopColor="#e9c77b" /><stop offset="1" stopColor="#a8742f" /></linearGradient>
                    <radialGradient id="tk2" cx=".5" cy=".4" r=".7"><stop offset="0" stopColor="#3a2a1a" /><stop offset="1" stopColor="#120a07" /></radialGradient>
                  </defs>
                  <path d="M28 2L52 34L28 66L4 34Z" fill="url(#tk)" />
                  <path d="M28 8L46 34L28 60L10 34Z" fill="url(#tk2)" stroke="#6e5a42" strokeWidth="1" />
                  <path d="M28 20c1.6 7 4.4 9.800 11 14-6.600 4.200-9.400 7-11 14-1.600-7-4.400-9.800-11-14 6.600-4.200 9.400-7 11-14z" fill="url(#tk)" />
                  <circle cx="28" cy="34" r="2" fill="#fff6d8" />
                </svg>
              </div>
            </div>
          </div>

          {/* tooltip */}
          {hovered && !moving && (() => {
            const p = pos(hovered)
            const st = stateOf(hovered)
            const t = TYPES[hovered.type]
            const label = { current: '当前位置', visited: '已走过', available: '可前往 · 点击选择', future: '尚未抵达', sealed: '此路已断绝' }[st]
            const below = hovered.floor >= 12
            const w = phone ? 170 : 210
            const left = Math.min(Math.max(p.x, w / 2 - 20), mapW - w / 2 + 20)
            return (
              <div className="tip" style={{ left, top: below ? p.y + (hovered.type === 'boss' ? 50 : 34) : p.y - (hovered.type === 'boss' ? 50 : 34), transform: `translate(-50%, ${below ? '0' : '-100%'})`, width: w }}>
                <div className="plate" style={{ padding: '10px 14px', borderRadius: 3, borderColor: st === 'available' ? t.color : undefined }}>
                  <div className="flex items-baseline justify-between gap-2">
                    <span className="serif" style={{ fontSize: 16, fontWeight: 900, color: st === 'sealed' ? '#8c7a62' : t.color, letterSpacing: '.08em' }}>{t.name}</span>
                    <span className="cinzel" style={{ fontSize: 11, color: '#9e8c72' }}>F{hovered.floor + 1}</span>
                  </div>
                  <div style={{ fontSize: 12, lineHeight: 1.6, color: '#c9c3b6', marginTop: 3 }}>{t.desc}</div>
                  <div style={{ fontSize: 11, marginTop: 6, color: st === 'available' ? '#f6dfa4' : '#8c7a62', letterSpacing: '.1em' }}>{label}</div>
                </div>
              </div>
            )
          })()}
        </div>
      </div>

      {/* floor rail */}
      <div className="absolute z-10 flex flex-col-reverse justify-between" style={{ left: compact ? 14 : 66, top: headerH + 24, bottom: 40, width: 26 }}>
        <div className="pointer-events-none absolute" style={{ left: 12, top: 0, bottom: 0, width: 1, background: 'linear-gradient(transparent, #6e5a42 15%, #6e5a42 85%, transparent)' }} />
        {Array.from({ length: FLOORS }, (_, f) => {
          const isCur = f === cur.floor
          const major = f === 0 || (f + 1) % 5 === 0
          return (
            <button key={f} aria-label={`前往第${f + 1}层视图`} className="relative flex items-center" style={{ height: 14, background: 'none', border: 0, padding: 0 }}
              onClick={() => { const n = floors[f][0]; scrollToNode(n, true) }}>
              <span style={{ position: 'absolute', left: isCur ? 7 : 9, width: isCur ? 11 : major ? 7 : 5, height: isCur ? 11 : major ? 7 : 5, transform: 'rotate(45deg)', background: isCur ? '#f6dfa4' : f < cur.floor ? '#8c6a44' : 'transparent', border: `1px solid ${isCur ? '#f6dfa4' : '#6e5a42'}`, boxShadow: isCur ? '0 0 10px #e9c77b' : 'none', marginTop: isCur ? 0 : 0 }} />
              {(major || isCur) && !phone && <span className="cinzel" style={{ position: 'absolute', left: 26, fontSize: 10, color: isCur ? '#f6dfa4' : '#7d6c55' }}>{f + 1}</span>}
            </button>
          )
        })}
      </div>

      {/* header */}
      <header className="absolute inset-x-0 top-0 z-30" style={{ height: headerH, background: 'linear-gradient(180deg, rgba(8,4,4,.96) 0%, rgba(10,5,5,.88) 70%, rgba(10,5,5,0))' }}>
        <div className="absolute inset-x-0 bottom-0" style={{ height: 1, background: 'linear-gradient(90deg, transparent, #6e5a42 20%, #6e5a42 80%, transparent)', opacity: 0.6 }} />
        <div className="flex items-start justify-between" style={{ padding: phone ? '10px 10px 0' : '14px 20px 0' }}>
          <div className="flex items-center gap-2">
            <div className="hud-pill" style={{ minWidth: phone ? 0 : 108 }}>
              <Heart /><span className="cinzel" style={{ fontWeight: 700, fontSize: 14 }}>62<span style={{ color: '#9e8c72' }}>/80</span></span>
              {!phone && <span style={{ width: 36, height: 4, borderRadius: 2, background: '#2a1a16', overflow: 'hidden', marginLeft: 2 }}><span style={{ display: 'block', width: '77%', height: '100%', background: 'linear-gradient(90deg,#a8362e,#e0605a)' }} /></span>}
            </div>
            <div className="hud-pill"><Mora /><span className="cinzel" style={{ fontWeight: 700, fontSize: 14, color: '#f6dfa4' }}>146</span></div>
            <div className="flex items-center gap-1.5">
              {POTIONS.map((p, i) => (
                <button key={i} onClick={() => say(p ? `${p.name} · 战斗中使用` : '空药水槽')} className="grid place-items-center" style={{ width: phone ? 28 : 34, height: phone ? 28 : 34, borderRadius: '50%', background: p ? 'radial-gradient(circle at 50% 35%, rgba(255,255,255,.14), rgba(26,19,18,.85))' : 'rgba(26,19,18,.5)', border: p ? `1px solid ${p.color}99` : '1px dashed #6e5a42' }}>
                  {p && <Bottle color={p.color} s={phone ? 14 : 17} />}
                </button>
              ))}
            </div>
          </div>

          {!compact && <Title floorNo={floorNo} path={path} />}

          <div className="flex items-center gap-2">
            <button className="hud-pill" style={{ height: 36, cursor: 'pointer' }} onClick={() => say('卡组 · 14 张(模拟)')}><Cards /><span className="cinzel" style={{ fontWeight: 700, fontSize: 14 }}>14</span></button>
            <div className="relative">
              <button className={`round-btn ${menu ? 'on' : ''}`} aria-label="菜单" aria-expanded={!!menu} onClick={() => setMenu(menu ? null : 'main')}>
                <svg width="18" height="18" viewBox="0 0 24 24" stroke="#e9c77b" strokeWidth="2" strokeLinecap="round" fill="none"><path d="M4 7h16M4 12h16M4 17h16" /></svg>
              </button>
              {menu && (
                <>
                  <div className="fixed inset-0" onClick={() => setMenu(null)} />
                  <div className="plate pop absolute right-0 top-12" style={{ width: 228, borderRadius: 3, padding: '8px 0' }}>
                    {menu === 'main' ? (
                      <>
                        <button className="menu-item" onClick={() => setMenu(null)}>继续冒险</button>
                        <button className="menu-item" onClick={() => { setMenu(null); say('卡组 · 14 张(模拟)') }}>查看卡组</button>
                        <button className="menu-item" onClick={() => { setLegendOpen((v) => !v); setMenu(null) }}>{legendOpen ? '收起图例' : '展开图例'}</button>
                        <button className="menu-item" onClick={() => setMenu('help')}>操作说明</button>
                        <div style={{ height: 1, margin: '6px 14px', background: '#3a2c20' }} />
                        <button className="menu-item" onClick={reset}>重置地图</button>
                        <button className="menu-item" onClick={() => { setMenu(null); say('返回主界面(模拟)') }}>返回主界面</button>
                      </>
                    ) : (
                      <div style={{ padding: '10px 18px 12px', fontSize: 13, lineHeight: 1.9, color: '#c9c3b6' }}>
                        <div className="serif" style={{ color: '#e9c77b', fontSize: 15, fontWeight: 900, letterSpacing: '.1em', marginBottom: 4 }}>操作说明</div>
                        滚轮 / 拖拽:上下查看路线<br />点击发亮的节点:选择前进<br />悬停节点:预览路线<br />图例:悬停高亮,点击锁定类型<br />左侧刻度:快速定位楼层
                        <button className="menu-item" style={{ padding: '8px 0 0', color: '#e9c77b' }} onClick={() => setMenu('main')}>返回</button>
                      </div>
                    )}
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
        {compact && <div className="flex justify-center" style={{ marginTop: phone ? 6 : 2 }}><Title floorNo={floorNo} path={path} small /></div>}
      </header>

      {/* legend */}
      <aside className="plate absolute z-20" style={{ right: compact ? 6 : 20, top: '50%', transform: 'translateY(-50%)', borderRadius: 3, padding: '8px 6px', width: compact || !legendOpen ? 46 : 178 }}>
        {!compact && (
          <button className="flex w-full items-center justify-between" style={{ background: 'none', border: 0, padding: '2px 8px 8px', color: '#9e8c72' }} onClick={() => setLegendOpen((v) => !v)} aria-label="折叠图例">
            {legendOpen && <span className="serif" style={{ fontSize: 13, letterSpacing: '.3em', color: '#bbaa8c' }}>图例</span>}
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" style={{ transform: legendOpen ? 'none' : 'rotate(180deg)', marginLeft: legendOpen ? 0 : 'auto', marginRight: legendOpen ? 0 : 'auto' }}><path d="M9 5l7 7-7 7" /></svg>
          </button>
        )}
        {ORDER.map((t) => {
          const c = TYPES[t]
          const count = nodes.filter((n) => n.type === t).length
          return (
            <button key={t} title={`${c.name}:${c.desc}`} className={`legend-row ${legendPin === t ? 'on' : ''}`} style={{ padding: compact || !legendOpen ? '7px 0' : undefined, justifyContent: compact || !legendOpen ? 'center' : undefined }}
              onPointerEnter={() => setLegendHover(t)} onPointerLeave={() => setLegendHover(null)}
              onClick={() => setLegendPin((p) => (p === t ? null : t))}>
              <span style={{ color: c.color, filter: `drop-shadow(0 0 5px ${c.color}88)`, display: 'grid' }}><NodeIcon type={t} size={compact ? 22 : 24} /></span>
              {!compact && legendOpen && (<><span style={{ fontSize: 14, letterSpacing: '.08em', flex: 1 }}>{c.name}</span><span className="cinzel" style={{ fontSize: 11, color: '#7d6c55' }}>{count}</span></>)}
            </button>
          )
        })}
      </aside>

      {toast && (
        <div key={toast.k} className="toast plate pointer-events-none absolute z-40 serif" style={{ left: '50%', bottom: 28, transform: 'translateX(-50%)', padding: '10px 22px', borderRadius: 3, fontSize: 14, letterSpacing: '.12em', color: '#f6dfa4', whiteSpace: 'nowrap', maxWidth: '92vw' }}>
          {toast.t}
        </div>
      )}
      <div className="vignette" />
      <svg className="grain" width="100%" height="100%"><filter id="nz"><feTurbulence type="fractalNoise" baseFrequency=".8" numOctaves="2" stitchTiles="stitch" /></filter><rect width="100%" height="100%" filter="url(#nz)" /></svg>
    </div>
  )
}

function Title({ floorNo, path, small }: { floorNo: number; path: string[]; small?: boolean }) {
  return (
    <div className="flex flex-col items-center" style={{ position: small ? 'static' : 'absolute', left: small ? undefined : '50%', transform: small ? undefined : 'translateX(-50%)', top: small ? undefined : 10, pointerEvents: 'none' }}>
      <div className="flex items-center gap-3">
        <span style={{ width: small ? 24 : 54, height: 1, background: 'linear-gradient(90deg, transparent, #8c6a44)' }} />
        <span className="serif" style={{ fontSize: small ? 12 : 13, letterSpacing: '.5em', color: '#bbaa8c', marginRight: '-.5em' }}>第一幕</span>
        <span style={{ width: small ? 24 : 54, height: 1, background: 'linear-gradient(270deg, transparent, #8c6a44)' }} />
      </div>
      <div className="serif flex items-baseline gap-2" style={{ color: '#e9c77b', textShadow: '0 0 18px rgba(233,199,123,.35), 0 2px 0 #000', lineHeight: 1.1, marginTop: 2 }}>
        <span style={{ fontSize: small ? 18 : 24, fontWeight: 900, letterSpacing: '.15em' }}>第 {floorNo} 层</span>
        <span className="cinzel" style={{ fontSize: 12, color: '#7d6c55' }}>/ {FLOORS}</span>
      </div>
      <div className="flex gap-[5px]" style={{ marginTop: 5 }}>
        {Array.from({ length: FLOORS }, (_, i) => (
          <span key={i} style={{ width: 6, height: 6, transform: 'rotate(45deg)', background: i < floorNo - 1 ? '#8c6a44' : i === floorNo - 1 ? '#f6dfa4' : 'transparent', border: '1px solid ' + (i <= floorNo - 1 ? '#a8823f' : '#4a3b2c'), boxShadow: i === floorNo - 1 ? '0 0 8px #e9c77b' : 'none', ...(i === FLOORS - 1 ? { width: 8, height: 8, borderColor: '#d9574a' } : {}) }} />
        ))}
      </div>
    </div>
  )
}
