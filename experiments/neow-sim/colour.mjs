// Native opacity is the complete alpha, not an extra multiplier of legacy RGBA.
export function argb(colour, opacity) {
  let hex = String(colour || '#FFFFFFFF').replace('#', '');
  if (hex.length === 6) hex += 'FF';
  const alpha = opacity === undefined ? parseInt(hex.slice(6, 8), 16) : Math.round(opacity * 255);
  return ((alpha << 24) >>> 0) + parseInt(hex.slice(0, 6), 16);
}
