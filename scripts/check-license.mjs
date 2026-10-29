// Project-original compliance tooling: PolyForm-Noncommercial-1.0.0.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { resolve, extname } from 'node:path';
import { pathToFileURL } from 'node:url';

const media = new Set(['.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.ico',
  '.gia', '.gil', '.blend', '.glb', '.gltf', '.obj', '.fbx', '.wav', '.mp3',
  '.ogg', '.flac', '.mp4', '.webm', '.ttf', '.otf', '.ttc', '.woff', '.woff2']);
export const sensitive = path => media.has(extname(path).toLowerCase()) ||
  (/^(art\/|docs\/experiments\/art-portrait\/)/.test(path) && /\.(lua|json)$/i.test(path));
export const digest = (bytes, text = false) => createHash('sha256')
  .update(text ? bytes.toString('utf8').replace(/\r\n/g, '\n') : bytes).digest('hex');

function matchesAsset(bytes, path, entry) {
  if (entry.lfsBytes === undefined) return digest(bytes, /\.(lua|json|svg)$/i.test(path)) === entry.sha256;
  if (!['.png','.webp'].includes(extname(path).toLowerCase()) ||
    !Number.isSafeInteger(entry.lfsBytes) || entry.lfsBytes <= 0) return false;
  // Explicitly reviewed raster candidates may stay as pointers in CI. This
  // checks inventory identity only, not remote object availability or pixels.
  const pointer = /^version https:\/\/git-lfs.github.com\/spec\/v1\noid sha256:([0-9a-f]{64})\nsize ([1-9]\d*)\n$/.exec(bytes.toString('utf8'));
  if (pointer) return pointer[1] === entry.sha256 && Number(pointer[2]) === entry.lfsBytes;
  return bytes.length === entry.lfsBytes && digest(bytes) === entry.sha256;
}

export function checkDependencies(bom, expected) {
  const actual = Object.fromEntries((bom.components ?? []).map(c => {
    // npm 10 provides a path property; npm 11 lock-only output may omit it.
    const path = c.properties?.find(p => p.name === 'cdx:npm:package:path')?.value ??
      (c.name ? `node_modules/${c.group ? `${c.group}/` : ''}${c.name}` : undefined);
    const licenses = (c.licenses ?? []).map(l => l.license?.id ?? l.expression ?? l.license?.name ?? 'UNKNOWN').sort();
    return [path, { version: c.version, licenses }];
  }));
  const errors = [];
  for (const path of new Set([...Object.keys(actual), ...Object.keys(expected)])) {
    if (JSON.stringify(actual[path]) !== JSON.stringify(expected[path])) {
      errors.push(`Dependency needs license review: ${path} (${JSON.stringify(actual[path])})`);
    }
  }
  return errors;
}

export function checkAssets(root, paths, inventory) {
  const errors = [];
  for (const path of paths.filter(sensitive)) {
    const entry = inventory.files[path];
    if (!entry || !inventory.categories[entry.category]) {
      errors.push(`Asset/runtime needs provenance review: ${path}`);
      continue;
    }
    if (!existsSync(resolve(root, path))) {
      errors.push(`Changed asset/runtime needs provenance review: ${path}`);
      continue;
    }
    const bytes = readFileSync(resolve(root, path));
    if (entry.lfs === true) {
      // Opt-in source identity only: this does not inspect pixels or fetch LFS objects.
      if (!/^art\/cards\/traveler-geo\/[a-z0-9_]+\/source\.png$/.test(path) ||
          /^art\/cards\/traveler-geo\/(armaments|cleave|heavy_blade)\/source\.png$/.test(path) ||
          !/^[0-9a-f]{64}$/.test(entry.sha256) || !Number.isSafeInteger(entry.bytes) || entry.bytes <= 0) {
        errors.push(`Invalid LFS source provenance record: ${path}`);
        continue;
      }
      const pointer = Buffer.from(`version https://git-lfs.github.com/spec/v1\noid sha256:${entry.sha256}\nsize ${entry.bytes}\n`);
      if (bytes.equals(pointer)) continue;
      if (bytes.length !== entry.bytes) errors.push(`Changed asset size needs provenance review: ${path}`);
    }
    if (!existsSync(resolve(root,path)) || !matchesAsset(readFileSync(resolve(root,path)), path, entry)) {
      errors.push(`Changed asset/runtime needs provenance review: ${path}`);
    }
  }
  for (const path of Object.keys(inventory.files)) {
    if (!paths.includes(path)) errors.push(`Remove obsolete asset record after review: ${path}`);
  }
  return errors;
}

export function audit(root = process.cwd()) {
  const json = path => JSON.parse(readFileSync(resolve(root, path), 'utf8'));
  const policy = json('docs/legal/dependencies.json');
  const paths = execFileSync('git', ['ls-files', '-z'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
  // Use npm's maintained SBOM implementation; no installs, lifecycle scripts or network requests.
  const args = ['sbom', '--sbom-format=cyclonedx', '--package-lock-only', '--offline', '--ignore-scripts'];
  const options = { cwd: root, encoding: 'utf8', timeout: 30000, maxBuffer: 8 * 1024 * 1024 };
  const output = process.platform === 'win32'
    ? execFileSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', `npm ${args.join(' ')}`], options)
    : execFileSync('npm', args, options);
  const errors = checkDependencies(JSON.parse(output), policy.npm);
  errors.push(...checkAssets(root, paths, json('docs/legal/assets.json')));
  for (const [path, hash] of Object.entries(policy.reviewedFiles)) {
    if (!existsSync(resolve(root, path)) || digest(readFileSync(resolve(root, path)), true) !== hash) {
      errors.push(`License text or external dependency declaration needs review: ${path}`);
    }
  }
  for (const path of ['LICENSE', 'LICENSE-SCOPE.md', 'README.md', 'THIRD_PARTY_NOTICES.md', 'docs/legal/LICENSE_AUDIT.md']) {
    if (!paths.includes(path) || !existsSync(resolve(root, path))) errors.push(`Required tracked notice missing: ${path}`);
  }
  return errors;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const errors = audit();
    if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
    else console.log('License inventory unchanged. Known GPL/IP/unknown risks remain open; this is not commercial clearance.');
  } catch (error) { console.error(`License check failed: ${error.message}`); process.exitCode = 1; }
}
