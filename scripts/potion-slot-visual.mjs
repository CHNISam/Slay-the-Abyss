// Main.dc.html / Map.dc.html share the same circular bottle silhouette.
// Accept existing border/face controls so extracting Main's visuals changes no
// geometry, colour, control names or interaction; only known library IDs are used.
export function potionSlotVisual(theme, { border, plate, bottleSize, ink }) {
  return [
    { ...border, image: theme.image.disc },
    { ...plate, image: theme.image.disc },
    { name: 'bottle', kind: 'image', position: [0, 0], size: [bottleSize, bottleSize],
      image: theme.icon.potion.fire_potion, colour: ink },
  ];
}
