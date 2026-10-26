import test from 'node:test';
import assert from 'node:assert/strict';

test('lint baseline allows exact existing warnings but rejects new globals and tool errors',async()=>{
  const {compareDiagnostics,parseDiagnostics}=await import('../scripts/check-lua-static.mjs');
  const old='src/lua/a.lua:2:1-3: (W211) unused variable \'old\'';
  const a=parseDiagnostics(old);
  assert.deepEqual(compareDiagnostics(a,a),[]);
  const added=parseDiagnostics(old+'\nsrc/lua/a.lua:3:1-4: (W113) accessing undefined variable \'typo\'');
  assert.equal(compareDiagnostics(added,a).length,1);
  assert.throws(()=>parseDiagnostics('luacheck crashed'),/Unrecognized/);
});
