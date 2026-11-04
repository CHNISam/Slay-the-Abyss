// Narrow inverse for historical workflow hash guards. Unknown or partial
// queue wiring stays visible to frozen baseline checks; no hashes are updated.
const additions=[
  [
    "  merge_group:\n    types: [checks_requested]\n    branches: [develop]\n",
    ""
  ],
  [
    "      - name: Mark native queue gates pending\n        if: github.event_name == 'merge_group'\n        env:\n          GH_TOKEN: ${{ github.token }}\n        run: node scripts/publish-merge-group.mjs --pending\n",
    ""
  ],
  [
    "          BASE_SHA: ${{ github.event.pull_request.base.sha || github.event.merge_group.base_sha || github.event.before }}",
    "          BASE_SHA: ${{ github.event.pull_request.base.sha || github.event.before }}"
  ],
  [
    "        if: always() && (github.event_name == 'merge_group' || (github.event_name == 'pull_request' && github.event.pull_request.base.ref == 'develop' && github.event.pull_request.head.repo.full_name == github.repository))",
    "        if: always() && github.event_name == 'pull_request' && github.event.pull_request.base.ref == 'develop' && github.event.pull_request.head.repo.full_name == github.repository"
  ],
  [
    "      - name: Publish native queue Full and admission gates\n        if: always() && github.event_name == 'merge_group'\n        env:\n          GH_TOKEN: ${{ github.token }}\n          FULL_MODE: ${{ needs.impact.outputs.mode }}\n          FULL_NEEDS: ${{ toJSON(needs) }}\n        run: node scripts/publish-merge-group.mjs\n",
    ""
  ]
];
export function beforeNativeMergeQueueWorkflow(text) {
 const eol=text.includes('\r\n')?'\r\n':'\n';
 const trigger='  merge_group:'+eol;
 if(!text.includes(trigger))return text; // old frozen sources
 if(text.split(trigger).length!==2)return null;
 for(const [added,removed] of additions) {
  // Match complete reviewed blocks using the checkout's line endings, leaving
  // all other source bytes intact for the existing immutable hash guards.
  const after=added.replaceAll('\n',eol),before=removed.replaceAll('\n',eol);
  const expected=after.includes("if: always() && (github.event_name")?2:1;
  if(text.split(after).length-1!==expected)return null;
  text=text.replaceAll(after,before);
 }
 return text;
}
