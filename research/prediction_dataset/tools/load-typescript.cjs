'use strict';

// Local-only source loader: use the project's pinned TypeScript, never an SDK.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const researchRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(researchRoot, '../..');
const materializerSourceRoot = path.join(repositoryRoot, 'research/prediction_materializer/src');
const ts = require(path.join(repositoryRoot, 'functions/node_modules/typescript'));
const allowedSharedFiles = new Set([
  'functions/src/health/dateKey.ts',
  'functions/src/health/observationCatalog.ts',
  'functions/src/health/observationCatalog.generated.ts',
  'functions/src/careActions/careActionCatalog.ts',
  'functions/src/careActions/careActionCatalog.generated.ts',
].map(relative => path.join(repositoryRoot, relative)));
const cache = new Map();
const loaded = new Set();

function isAllowedSource(filename) {
  return filename.startsWith(path.join(researchRoot, 'src') + path.sep) ||
    filename.startsWith(materializerSourceRoot + path.sep) ||
    allowedSharedFiles.has(filename);
}

function resolveSource(specifier, parent) {
  if (!specifier.startsWith('.')) {
    throw new Error(`Offline source loader rejected import: ${specifier}`);
  }
  const base = path.resolve(path.dirname(parent), specifier);
  const candidates = base.endsWith('.ts') ? [base] : [base + '.ts', path.join(base, 'index.ts')];
  const filename = candidates.find(candidate => fs.existsSync(candidate));
  if (!filename || !isAllowedSource(filename)) {
    throw new Error(`Offline source loader rejected source: ${specifier}`);
  }
  return filename;
}

function loadTypeScript(filename) {
  const absolute = path.resolve(filename);
  if (!isAllowedSource(absolute)) throw new Error('Only isolated research source and named pure helpers may load');
  if (cache.has(absolute)) return cache.get(absolute).exports;
  const source = fs.readFileSync(absolute, 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS,
      esModuleInterop: true,
      strict: true,
    },
    fileName: absolute,
    reportDiagnostics: true,
  });
  const errors = (compiled.diagnostics || []).filter(item => item.category === ts.DiagnosticCategory.Error);
  if (errors.length) {
    throw new Error(ts.formatDiagnosticsWithColorAndContext(errors, {
      getCurrentDirectory: () => researchRoot,
      getCanonicalFileName: value => value,
      getNewLine: () => '\n',
    }));
  }
  const localModule = {exports: {}};
  cache.set(absolute, localModule);
  loaded.add(absolute);
  const safeRequire = specifier => {
    if (specifier === 'node:crypto') return Object.freeze({createHash: crypto.createHash});
    return loadTypeScript(resolveSource(specifier, absolute));
  };
  try {
    const execute = new vm.Script(
      '(function (exports, require, module, __filename, __dirname) {\n' + compiled.outputText + '\n})',
      {filename: absolute},
    ).runInThisContext();
    execute(localModule.exports, safeRequire, localModule, absolute, path.dirname(absolute));
    return localModule.exports;
  } catch (error) {
    cache.delete(absolute);
    loaded.delete(absolute);
    throw error;
  }
}

function loadedSourceFiles() {
  return [...loaded].sort();
}

module.exports = {loadTypeScript, loadedSourceFiles, typescriptVersion: ts.version};
