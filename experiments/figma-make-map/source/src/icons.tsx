import type { NodeType } from './map'

// 单色剪影图标(官方图库图标无法在此环境获取,以同风格线性剪影代替)
export function NodeIcon({ type, size = 30 }: { type: NodeType; size?: number }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.9, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
  switch (type) {
    case 'battle':
      return (
        <svg {...common}>
          <path d="M4 4l9.5 9.5M20 4l-9.5 9.5" />
          <path d="M13 14l-3.5 3.5M11 14l3.5 3.5" />
          <path d="M6.5 15.5L4 18M17.5 15.5L20 18M3.2 20.8l2-.4M20.8 20.8l-2-.4" />
          <path d="M4 4l.6 3.2L8 7.5M20 4l-.6 3.2L16 7.5" />
        </svg>
      )
    case 'elite':
      return (
        <svg {...common} fill="currentColor" strokeWidth={1.2}>
          <path d="M4 3.5c.2 5 2.2 7.7 4.6 8.8V16l1.6 2.2h3.6l1.6-2.2v-3.7c2.4-1.1 4.4-3.8 4.6-8.8-2.2 1.1-3.8 2.4-4.8 4.6H8.8C7.8 5.9 6.2 4.6 4 3.5z" />
          <path d="M10 20.5h4" stroke="currentColor" strokeWidth="1.8" />
          <path d="M9.4 11.2l1.8 1M14.6 11.2l-1.8 1" stroke="#0d0708" strokeWidth="1.6" />
        </svg>
      )
    case 'unknown':
      return (
        <svg {...common} strokeWidth={2.3}>
          <path d="M8.6 8.8a3.5 3.5 0 1 1 5.4 2.9c-1.3.8-2 1.5-2 3" />
          <circle cx="12" cy="19" r=".6" fill="currentColor" />
        </svg>
      )
    case 'shop':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="8.6" />
          <rect x="8.7" y="8.7" width="6.6" height="6.6" transform="rotate(45 12 12)" />
        </svg>
      )
    case 'camp':
      return (
        <svg {...common} fill="currentColor" strokeWidth={1.2}>
          <path d="M12.3 2.8c.6 3.6 4.8 5 4.8 9.6a5.1 5.1 0 0 1-10.2 0c0-2.2 1-3.4 2.2-4.4.1 1.8.9 2.8 2 3 .6-2.8-.1-5.6 1.2-8.2z" />
          <path d="M5 21l14-3M5 18l14 3" stroke="currentColor" strokeWidth="1.8" />
        </svg>
      )
    case 'treasure':
      return (
        <svg {...common}>
          <path d="M4 11V7.5C4 5.6 5.6 4.5 7.5 4.5h9c1.9 0 3.5 1.1 3.5 3V11" />
          <rect x="3.5" y="11" width="17" height="8.5" rx="1" />
          <path d="M3.5 14h17" />
          <rect x="10.4" y="12.6" width="3.2" height="3.4" fill="currentColor" />
        </svg>
      )
    case 'boss':
      return (
        <svg {...common} fill="currentColor" strokeWidth={1}>
          <path d="M2.5 19.5L3.6 6.5l5 5 3.4-7.5 3.4 7.5 5-5 1.1 13z" />
          <path d="M8.2 19.5c1-3 2.4-4.4 3.8-4.4s2.8 1.4 3.8 4.4" fill="none" stroke="#0d0708" strokeWidth="1.2" />
          <ellipse cx="12" cy="12.2" rx="2.3" ry="1.4" fill="#0d0708" stroke="none" />
          <circle cx="12" cy="12.2" r=".8" fill="currentColor" stroke="none" />
          <path d="M2 22h20" stroke="currentColor" strokeWidth="1.6" />
        </svg>
      )
  }
}

export const Heart = ({ s = 16 }: { s?: number }) => (
  <svg width={s} height={s} viewBox="0 0 24 24" fill="#d9574a"><path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.7A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z" /></svg>
)
export const Mora = ({ s = 16 }: { s?: number }) => (
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="#e9c77b" strokeWidth="2"><circle cx="12" cy="12" r="9" /><rect x="8.7" y="8.7" width="6.6" height="6.6" transform="rotate(45 12 12)" /></svg>
)
export const Cards = ({ s = 18 }: { s?: number }) => (
  <svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke="#e9c77b" strokeWidth="1.8" strokeLinejoin="round"><rect x="3" y="6" width="11" height="15" rx="1.5" transform="rotate(-10 8 13)" /><rect x="10" y="4" width="11" height="15" rx="1.5" fill="#1a1312" /></svg>
)
export const Bottle = ({ color, s = 16 }: { color: string; s?: number }) => (
  <svg width={s} height={s} viewBox="0 0 24 24" fill={color}><path d="M9 3h6v2.5l-1 1.5v2.2l4.2 7.6c.9 1.7-.3 3.7-2.2 3.7H8c-1.900 0-3.100-2-2.200-3.700L10 9.200V7L9 5.500z" /></svg>
)
