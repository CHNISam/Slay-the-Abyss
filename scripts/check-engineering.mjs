import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { collectEngineeringInputs, main as qualityMain } from './check-engineering-quality.mjs';
import { main as architectureMain } from './check-architecture.mjs';
import { main as staticMain } from './check-lua-static.mjs';

// No disk cache or module singleton: a new invocation always samples current input.
export function runEngineering({collect=collectEngineeringInputs,quality=qualityMain,
  architecture=architectureMain,staticCheck=staticMain}={}) {
  let inputs;
  for(const [name,run] of [
    ['quality',()=>quality([],()=>inputs=collect())],
    ['architecture',()=>architecture(inputs.architecture)],
    ['lua-static',()=>staticCheck(inputs)],
  ]) {
    const report=run();
    if(report.errors.length)throw new Error(`${name} failed: ${report.errors.map(error=>error.message).join('; ')}`);
  }
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if(process.argv.length!==2)throw new Error('Usage: check-engineering.mjs');
    runEngineering();
  }catch(error){console.error(error.message);process.exitCode=1;}
}
