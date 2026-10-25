import { writeFileSync } from 'node:fs';
// Offline probe only. Parent allows this exact local script and no other child.
setTimeout(() => writeFileSync(process.argv[2], JSON.stringify({ at: Date.now() })), 1500);
setTimeout(() => {}, 60000);
