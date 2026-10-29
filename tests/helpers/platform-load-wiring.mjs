// Only the exact reviewed additions may be removed for historical replay.
// Partial, moved or altered wiring stays visible to the old hash guards.
const uploadAction = 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4';
const fast = `      - run: npm run check:platform-load
        if: steps.runtime.outputs.tests == 'true'
      - uses: ${uploadAction}
        if: always() && steps.runtime.outputs.tests == 'true'
        with:
          name: platform-load-fast-\${{ matrix.os }}
          path: build/platform-load-daily.json
          retention-days: 7
          if-no-files-found: warn
`;
const full = platform => `      - name: Check production platform load
        if: matrix.shard == 1
        run: node scripts/platform-load.mjs daily
      - uses: ${uploadAction}
        if: always() && matrix.shard == 1
        with:
          name: platform-load-${platform}-\${{ github.run_id }}-\${{ github.run_attempt }}
          path: build/platform-load-daily.json
          retention-days: 7
          if-no-files-found: warn
`;
const fastBefore = '        run: node scripts/ci-fast.mjs\n  rules:\n';
const gate = '      - run: npm run check:engineering\n        if: matrix.shard == 1\n';
const anchor = name => `      - uses: ${uploadAction}\n        if: always() && matrix.shard == 1\n        with:\n          name: ${name}`;
const windowsAnchor = anchor('engineering-quality-windows-${{ github.run_id }}-${{ github.run_attempt }}');
const posixAnchor = anchor('engineering-${{ github.run_id }}-${{ github.run_attempt }}-${{ matrix.shard }}');
export const platformWorkflowEdits = [
  {before: fastBefore, after: '        run: node scripts/ci-fast.mjs\n' + fast + '  rules:\n'},
  {before: gate + windowsAnchor, after: gate + full('windows') + windowsAnchor},
  {before: gate + posixAnchor, after: gate + full('posix') + posixAnchor},
];
const packageTail = '    "test:related": "node scripts/test-affected.mjs"\n';
export const platformPackageEdits = [
  {before: packageTail, after: packageTail.trimEnd() + ',\n'
    + '    "check:platform-load": "npm run build:data && npm run build:ui && node scripts/platform-load.mjs daily",\n'
    + '    "verify:platform-load": "node scripts/platform-load.mjs release"\n'},
  {before: 'npm run check:network && npm run verify:backlog',
    after: 'npm run check:network && npm run check:platform-load && npm run verify:backlog'},
];
function invert(text, edits) {
  if (edits.some(edit => text.split(edit.after).length !== 2)) return null;
  for (const edit of edits) text = text.replace(edit.after, edit.before);
  return text;
}
export const beforePlatformWorkflow = text => invert(text, platformWorkflowEdits);
export const beforePlatformPackage = text => invert(text, platformPackageEdits);
