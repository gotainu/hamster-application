'use strict';
// Aggregate-only offline report. Never connects to Firebase, GA4 or Stripe.
const fs = require('node:fs');
const path = require('node:path');

function renderDashboard(datasets, template) {
  if (!datasets || typeof datasets !== 'object') throw Error('Aggregate datasets required');
  for (const dataset of Object.values(datasets)) {
    if (!Array.isArray(dataset.funnel) || !Array.isArray(dataset.retention) || !dataset.a3) {
      throw Error('Expected journey dashboard aggregate schema');
    }
    // UID/event rows must stay in the restricted warehouse, never the report.
    const prohibited = /"(?:user_id|uid|email|question|answer|memo|customer_id|subscription_id)"\s*:/;
    if (prohibited.test(JSON.stringify(dataset))) throw Error('Report must contain aggregates only');
  }
  const json = JSON.stringify(datasets).replace(/</g, '\\u003c').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  if (!template.includes('/*AGGREGATE_DATA*/null')) throw Error('Missing report data placeholder');
  return template.replace('/*AGGREGATE_DATA*/null', json);
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length !== 3) throw Error('Usage: node render-dashboard.cjs general.json synthetic.json new-report.html');
  const datasets = { general: JSON.parse(fs.readFileSync(args[0], 'utf8')), synthetic: JSON.parse(fs.readFileSync(args[1], 'utf8')) };
  const output = path.resolve(args[2]);
  fs.mkdirSync(path.dirname(output), {recursive: true});
  fs.writeFileSync(output, renderDashboard(datasets, fs.readFileSync(path.join(__dirname, 'dashboard-template.html'), 'utf8')), {flag:'wx'});
  console.log(JSON.stringify({report: output, source: 'aggregate_only', cloud_connected: false}));
}
module.exports = {renderDashboard};
