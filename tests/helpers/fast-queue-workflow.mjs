// Undo only these complete reviewed additions. Preserve historical workflow
// hashes and leave every unknown/partial change visible to their original guards.
const blocks=[
`      - name: Invalidate previous PR admission status
        if: github.event_name == 'pull_request' && github.event.pull_request.base.ref == 'develop' && github.event.pull_request.head.repo.full_name == github.repository
        env:
          GH_TOKEN: \${{ github.token }}
        run: node scripts/publish-pr-quality.mjs --pending
`,
`      - run: node scripts/write-ci-receipt.mjs --fast
        if: runner.os == 'Windows'
      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4
        if: runner.os == 'Windows'
        with:
          name: quality-\${{ github.run_id }}-\${{ github.run_attempt }}-fast
          path: |
            build/ci-checkout.json
            build/ci-impact.json
          retention-days: 7
          if-no-files-found: error
`,
`      - name: Publish exact PR admission status
        if: always() && github.event_name == 'pull_request' && github.event.pull_request.base.ref == 'develop' && github.event.pull_request.head.repo.full_name == github.repository
        env:
          GH_TOKEN: \${{ github.token }}
          FULL_MODE: \${{ needs.impact.outputs.mode }}
          FULL_NEEDS: \${{ toJSON(needs) }}
        run: node scripts/publish-pr-quality.mjs
`];
export function beforeFastQueueWorkflow(text){
 if(!text.includes('scripts/publish-pr-quality.mjs')&&!text.includes('write-ci-receipt.mjs --fast'))return text;
 const eol=text.includes('\r\n')?'\r\n':'\n';
 for(const block of blocks){
  const source=block.replaceAll('\n',eol);
  if(text.split(source).length!==2)return null;
  text=text.replace(source,'');
 }
 return text;
}
