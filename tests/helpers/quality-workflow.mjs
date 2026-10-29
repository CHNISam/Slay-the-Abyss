// Remove only this change's exact artifact additions when older workflow hash
// guards reconstruct their historical source. The new tests assert these exact
// blocks against the live workflow, including failure-path uploads.
export const qualityWindowsUpload = `      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
        if: always() && matrix.shard == 1
        with:
          name: engineering-quality-windows-\${{ github.run_id }}-\${{ github.run_attempt }}
          path: |
            build/engineering-quality.json
            build/engineering-quality.md
          retention-days: 7
          if-no-files-found: warn
`;
export const qualityPosixPaths = `            build/responsibility-complexity.json
            build/engineering-quality.json
            build/engineering-quality.md
`;
export function beforeQualityArtifacts(text) {
  return text.replace(qualityWindowsUpload,'')
    .replace(qualityPosixPaths,'')
    .replace('        if: always() && matrix.shard == 1\n        with:\n          name: engineering-',
      '        if: matrix.shard == 1\n        with:\n          name: engineering-');
}

// Historical package replays retain their complete old hash. Invert only the
// two reviewed quality additions, including the exact new entry position.
// Partial, reordered or altered wiring is left intact for the old hash to reject.
export function beforeQualityPackage(text) {
  const oldEntry='    "check:architecture": "node scripts/check-architecture.mjs",\n';
  const newEntry=oldEntry+'    "check:quality": "node scripts/check-engineering-quality.mjs",\n';
  const oldGate='    "check:engineering": "npm run check:architecture && npm run check:lua-static && npm run check:test-strength && npm run check:native-ui-contract",\n';
  const newGate=oldGate.replace('npm run check:architecture','npm run check:quality && npm run check:architecture');
  if(text.split(newEntry).length!==2||text.split(newGate).length!==2)return text;
  return text.replace(newEntry,oldEntry).replace(newGate,oldGate);
}
