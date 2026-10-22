import { readFileSync } from 'node:fs';

// Approved composition stays in layout.card/hand/map/etc.; native* records
// the existing functional fallback until its visual reconstruction is complete.
export const nativeTheme = JSON.parse(readFileSync(new URL('../data/presentation/ui_theme.json', import.meta.url), 'utf8'));

export function nativeControls(theme = nativeTheme) {
  const origin = theme.layout.nativeControl.origin;
  const frame = (position, size) => [...position, ...size];
  const box = values => ({ position: values.slice(0, 2), size: values.slice(2) });
  const centred = size => frame(origin, size);
  const text = (name, values, content = '', fontSize = theme.font.body, colour = theme.color.text) => ({
    name, kind: 'text', ...box(values), text: {
      content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: theme.font.minimum,
    },
  });
  const plate = (name, values, colour = theme.color.panelRaised) => ({
    name, kind: 'image', ...box(values), image: theme.image.rect, colour,
  });
  const hit = size => ({ name: 'hit', kind: 'cursorArea', size: [...size], focusable: true });
  const button = (name, values, label = '', { inset, states = false, fontSize = theme.font.body,
    colour = theme.color.text } = {}) => {
    const size = values.slice(2);
    return { name, kind: 'container', ...box(values), children: [
      ...(states ? [plate('normal', centred(size)), plate('disabled', centred(size), theme.color.panel),
        plate('selected', centred(size), theme.color.goldDim)] : [plate('plate', centred(size))]),
      text('label', centred(size.map((value, index) => value - inset[index])), label, fontSize, colour), hit(size),
    ] };
  };
  return { text, plate, hit, button, frame, centred };
}
