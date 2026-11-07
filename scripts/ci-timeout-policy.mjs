// Execution guards are separate from scheduling estimates. Explicit caller
// timeouts (including deliberate failure probes) always retain their value.
export const luaTimeoutMs = Object.freeze({
  default: 90000,
  heavy: 120000,
  veryHeavy: 180000,
});

export const sapphireSliceMs = 90000;
