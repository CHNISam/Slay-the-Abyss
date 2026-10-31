export function withViewport(layout, theme) {
  return { ...layout, controls: [
    // Mobile DIAG-12 mode C covered both exposed edges with +400 UI units of horizontal bleed.
    // Stretch anchors include this delta beyond the parent; content stage remains unchanged.
    { name: 'canvasBackdrop', kind: 'image', anchor: { min: [0, 0], max: [1, 1] }, size: [400, 0],
      image: theme.image.rect, colour: theme.color.backdrop },
    { name: 'stage', kind: 'container', size: [...theme.canvas.base], children: layout.controls },
  ] };
}
