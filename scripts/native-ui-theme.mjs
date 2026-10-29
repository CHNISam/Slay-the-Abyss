import { readFileSync } from 'node:fs';

// Approved composition stays in layout.card/hand/map/etc.; native* records
// the existing functional fallback until its visual reconstruction is complete.
export const nativeTheme = JSON.parse(readFileSync(new URL('../data/presentation/ui_theme.json', import.meta.url), 'utf8'));

// Native text sizes are varints; positions and dimensions remain floating point.
export function nativeFontSize(value, minimum = 14) {
  if (!Number.isFinite(value) || !Number.isFinite(minimum)) throw new Error('Native font size must be finite');
  return Math.max(14, Math.round(minimum), Math.round(value));
}

export function nativeControls(theme = nativeTheme) {
  const origin = theme.layout.nativeControl.origin;
  const frame = (position, size) => [...position, ...size];
  const box = values => ({ position: values.slice(0, 2), size: values.slice(2) });
  const centred = size => frame(origin, size);
  const text = (name, values, content = '', fontSize = theme.font.body, colour = theme.color.text) => ({
    name, kind: 'text', ...box(values), text: {
      content, fontSize: nativeFontSize(fontSize, theme.font.minimum), colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: nativeFontSize(theme.font.minimum),
    },
  });
  const plate = (name, values, colour = theme.color.panelRaised) => ({
    name, kind: 'image', ...box(values), image: theme.image.rect,
    // The client UI importer accepts RGB; alpha is a separate control property.
    ...(typeof colour === 'string' && /^#[0-9a-f]{8}$/i.test(colour)
      ? { colour: colour.slice(0, 7), opacity: parseInt(colour.slice(7), 16) / 255 }
      : { colour }),
  });
  const hit = size => ({ name: 'hit', kind: 'cursorArea', size: [...size], focusable: true });
  // `border` draws a frame behind the face, as on the approved primary/secondary result buttons.
  const button = (name, values, label = '', { inset, states = false, fontSize = theme.font.body,
    colour = theme.color.text, fill = theme.color.panelRaised, border } = {}) => {
    const size = values.slice(2);
    const edge = border ? [plate('border', centred(size.map(value => value + theme.space.border * 2)), border)] : [];
    return { name, kind: 'container', ...box(values), children: [...edge,
      ...(states ? [plate('normal', centred(size), fill), plate('disabled', centred(size), theme.color.panel),
        plate('selected', centred(size), theme.color.goldDim)] : [plate('plate', centred(size), fill)]),
      text('label', centred(size.map((value, index) => value - inset[index])), label, fontSize, colour), hit(size),
    ] };
  };
  return { text, plate, hit, button, frame, centred };
}
