// Offline visualizer only. The client receives native text, never HTML.
export function nativeInlinePreview(source) {
  return source.split(/(<color=#[0-9A-Fa-f]{6}>|<\/color>)/g).map(part => {
    if (/^<color=#[0-9A-Fa-f]{6}>$/.test(part)) return `<span style="color:${part.slice(7,14)}">`;
    if (part === '</color>') return '</span>';
    return part.replace(/[<&]/g, c => c === '<' ? '&lt;' : '&amp;');
  }).join('');
}
