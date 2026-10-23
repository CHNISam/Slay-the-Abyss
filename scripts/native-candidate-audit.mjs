import { createHash } from 'node:crypto';

export const sha256 = source => createHash('sha256').update(source).digest('hex');
export const normalizedSource = source => source.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
export function requireSourceSha(source) {
  if (typeof source !== 'string' || !/^[a-f0-9]{40}$/i.test(source)) throw new TypeError('source must be a complete 40-character Git commit SHA');
  return source.toLowerCase();
}

// The native reader expands defaults and lowercases colours. Fill implies mask.
// Keep geometry, text, assets, grid, button states and child order in the comparison.
export function normalizeUi(value, context = Array.isArray(value) ? 'controls' : 'control') {
  if (typeof value === 'string') return context === 'colour' && /^#[0-9a-f]{6}$/i.test(value) ? value.toLowerCase() : value;
  if (Array.isArray(value)) return value.map(item => normalizeUi(item, context === 'controls' ? 'control' : 'opaque'));
  if (!value || typeof value !== 'object') return value;
  const result = {};
  for (const name of Object.keys(value).sort()) {
    const item = value[name];
    if (context === 'control' && (name === 'mask' && value.fill || name === 'position' && JSON.stringify(item) === '[0,0]'
      || name === 'visible' && item === true || name === 'rotation' && item === 0
      || name === 'scale' && ['[1,1]', '[1,1,1]'].includes(JSON.stringify(item)) || name === 'focusable' && item === false)
      || ['control', 'text'].includes(context) && name === 'opacity' && item === 1
      || context === 'grid' && (name === 'horizontal' && item === false || name === 'scrollbar' && item === true || name === 'preview')
      || context === 'text' && name === 'content' && item === '') continue;
    const next = context === 'control' && name === 'children' ? 'controls'
      : context === 'control' && ['text', 'grid'].includes(name) ? name
      : context === 'control' && name === 'colour' || context === 'text' && ['colour', 'background', 'outlineColour'].includes(name) ? 'colour' : 'opaque';
    result[name] = normalizeUi(item, next);
  }
  return result;
}
function interfaceMetadata(spec) {
  const { controls, script, scripts = [], ...metadata } = spec;
  metadata.scripts = [...(script === undefined ? [] : [script]), ...scripts];
  for (const flag of ['hidden', 'showCursor', 'blockKeys', 'blockCursor', 'isolateNavigation']) {
    if (metadata[flag] === undefined) metadata[flag] = false;
  }
  return metadata;
}
function uiComparisonContext(context, key) {
  if (context === 'control') {
    if (key === 'children') return 'controls';
    if (['text', 'grid'].includes(key)) return key;
    if (['position', 'size', 'scale'].includes(key)) return 'float-vector';
    if (['rotation', 'opacity'].includes(key)) return 'float';
  }
  if (context === 'text' && ['fontSize', 'minFontSize', 'opacity'].includes(key)) return 'float';
  if (context === 'grid' && ['itemSize', 'spacing', 'padding'].includes(key)) return 'float-vector';
  return 'opaque';
}
function equivalent(left, right, context = 'opaque') {
  if (context === 'float' && typeof left === 'number' && typeof right === 'number') {
    return Number.isFinite(left) && Number.isFinite(right) && Math.abs(left - right) <= 0.0001;
  }
  if (!left || !right || typeof left !== 'object' || typeof right !== 'object') return left === right;
  if (Array.isArray(left) !== Array.isArray(right) || Object.keys(left).length !== Object.keys(right).length) return false;
  return Object.keys(left).every(key => {
    const next = Array.isArray(left) ? context === 'controls' ? 'control' : context === 'float-vector' ? 'float' : 'opaque'
      : uiComparisonContext(context, key);
    return Object.hasOwn(right, key) && equivalent(left[key], right[key], next);
  });
}
export function controlTreeStats(controls) {
  let count = 0, maxChildren = 0;
  function visit(nodes) { for (const node of nodes) { count++; maxChildren = Math.max(maxChildren, (node.children ?? []).length); visit(node.children ?? []); } }
  visit(controls); return { count, maxChildren };
}

export function compareNativeCandidate({ actual, expected, sourceSha, candidateBefore, candidateAfter, bgm = false }) {
  requireSourceSha(sourceSha);
  const issues = [], add = (code, detail) => issues.push({ code, detail });
  const wanted = new Map(expected.modules.map(module => [module.name, module]));
  const modules = actual.scripts.scripts.map(module => {
    const source = wanted.get(module.name)?.source;
    const row = { name: module.name, actualSha256: sha256(module.source), expectedSha256: source === undefined ? null : sha256(source),
      byteIdentical: source === module.source, sourceTextIdentical: source !== undefined && normalizedSource(source) === normalizedSource(module.source) };
    if (!row.sourceTextIdentical) add('MODULE_MISMATCH', module.name);
    if (module.file !== `${module.name}.lua`) add('MODULE_FILE', module.name);
    return row;
  });
  for (const name of wanted.keys()) if (!modules.some(module => module.name === name)) add('MODULE_MISSING', name);
  if (new Set(modules.map(module => module.name)).size !== modules.length) add('MODULE_DUPLICATE', 'Script names must be unique');
  const sourceControls = expected.ui.controls, controls = actual.ui.interface.controls;
  const sourceStats = controlTreeStats(sourceControls), stats = controlTreeStats(controls);
  if (!equivalent(normalizeUi(sourceControls), normalizeUi(controls), 'controls')) add('UI_MISMATCH', 'Controls differ from same-source generated UI');
  if (!equivalent(normalizeUi(expected.template), normalizeUi(actual.template.template), 'control')) add('TEMPLATE_MISMATCH', 'Deck template differs from same-source generated template');
  if (!equivalent(interfaceMetadata(expected.ui), interfaceMetadata(actual.ui.interface))) add('INTERFACE_MISMATCH', 'Interface identity, flags, scripts or other root metadata differ');
  const graphContracts = expected.graphs.filter(graph => bgm || graph.name !== '_GSTS_ABYSS_BGM');
  if (actual.inspected.graphs.length !== graphContracts.length) add('GRAPH_COUNT', 'Unexpected/missing server graph');
  for (const contract of graphContracts) {
    const graph = actual.inspected.graphs.find(graph => graph.name === contract.name);
    if (!graph || graph.type !== 20000 || !Number.isSafeInteger(graph.nodeCount) || graph.nodeCount <= 0) { add('GRAPH_MISSING', contract.name); continue; }
    const mounted = actual.inspected.entities.some(entity => entity.templateId === 10003004
      && (entity.graphMounts ?? []).some(mount => mount.graphId === graph.id && mount.category === 20000 && mount.enabled === 1));
    if (!mounted) add('GRAPH_UNMOUNTED', contract.name);
    const signals = (graph.signalReferences ?? []).filter(signal => signal.role === 'monitor').map(signal => signal.name).sort();
    if (JSON.stringify(signals) !== JSON.stringify([...contract.signals].sort())) add('GRAPH_SIGNALS', contract.name);
  }
  const parameters = actual.parameters.records ?? [];
  if (bgm || expected.uiBgmParameter?.type === 'boolean' && expected.uiBgmParameter.value === false) {
    if (parameters.length !== 2 || ![7, 8].every(section => parameters.some(parameter => parameter.section === section
      && parameter.name === 'nativeBgmEnabled' && parameter.type === 4 && parameter.code === 5 && parameter.value === bgm))) {
      add('BGM_PARAMETER', `nativeBgmEnabled must be boolean ${bgm} in both native records`);
    }
  }
  if (!bgm && parameters.some(parameter => parameter.value === true)) add('BGM_NOT_REQUESTED', 'Enabled BGM requires explicit --bgm');
  if (!actual.checked.ok || actual.checked.errors !== 0) add('CLIENT_ERRORS', actual.checked.problems ?? []);
  if (candidateBefore !== candidateAfter) add('CANDIDATE_CHANGED', 'Candidate hash changed during readback');
  return { sourceCommit: sourceSha, candidate: { sha256Before: candidateBefore, sha256After: candidateAfter }, modules,
    sourceNormalization: 'Only optional UTF-8 BOM and CRLF/LF are normalized; original hashes retained.',
    ui: { expectedCount: sourceStats.count, actualCount: stats.count, expectedMaxChildren: sourceStats.maxChildren, actualMaxChildren: stats.maxChildren,
      shellNodesExcluded: 'Native interface container/root are outside interface.controls; counts use source controls scope.' },
    graphs: actual.inspected.graphs, bgmEnabled: bgm, parameters,
    staticCheck: actual.checked, issues, ok: issues.length === 0,
    officialImport: 'NOT_TESTED', playtest: 'NOT_TESTED', audio: 'NOT_TESTED' };
}
