export function withViewport(layout, theme) {
  return { ...layout, controls: [
    // Fill the native host, which can be wider than GetUICanvasSize on phones.
    // With stretch anchors size is a delta; adding the canvas dimensions doubles it.
    { name: 'canvasBackdrop', kind: 'image', anchor: { min: [0, 0], max: [1, 1] }, size: [0, 0],
      image: theme.image.rect, colour: theme.color.backdrop },
    { name: 'stage', kind: 'container', size: [...theme.canvas.base], children: layout.controls },
  ] };
}
