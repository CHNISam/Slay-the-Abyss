export function withViewport(layout, theme) {
  return { ...layout, controls: [
    { name: 'canvasBackdrop', kind: 'image', size: [...theme.canvas.base],
      image: theme.image.rect, colour: theme.color.backdrop },
    { name: 'stage', kind: 'container', size: [...theme.canvas.base], children: layout.controls },
  ] };
}
