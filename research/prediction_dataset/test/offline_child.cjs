"use strict";

// Only used by an isolated-process test. Failure is intentional if any dataset
// import attempts SDK initialization or any network transport.
const Module = require("node:module");
const originalLoad = Module._load;
Module._load = function offlineOnly(request, parent, isMain) {
  if (/(?:firebase|google-cloud|google-auth|gaxios|axios|switchbot|bigquery)/i.test(request)) {
    throw new Error(`unexpected_external_dependency:${request}`);
  }
  return originalLoad.apply(this, arguments);
};
const forbidden = () => { throw new Error("unexpected_external_connection"); };
global.fetch = forbidden;
for (const [name, methods] of [
  ["node:http", ["request", "get"]],
  ["node:https", ["request", "get"]],
  ["node:net", ["connect", "createConnection"]],
  ["node:tls", ["connect"]],
  ["node:dns", ["lookup", "resolve"]],
]) {
  const transport = require(name);
  for (const method of methods) transport[method] = forbidden;
}

// The parent passes a fixture-only test entry; this child has no credentials.
require(process.argv[2]);
