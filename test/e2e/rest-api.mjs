// Function: none of its own in the REST API. Checks that core's issue API
// (what Redmine 7 webhooks also send) keeps working on issues with a
// recurrence, and that the plugin's routes do not answer as an API.
import { e2e } from '../../.codex/e2e/lib.mjs';
import { reset, rails } from './helpers.mjs';

const ids = reset();
rails(`User.current = User.find_by(login: 'admin')
  IssueRecurrence.create!(issue: Issue.find(${ids.panel}), mode: :weekly, multiplier: 1, anchor_mode: :first_issue_fixed)`);
const key = rails("print User.find_by(login: 'manager').api_key").split('\n').pop();
const t = await e2e('rest-api');
const p = () => t.page;

await t.anonymous();
const show = await p().request.get(`${t.BASE}/issues/${ids.panel}.json?include=relations`, { headers: { 'X-Redmine-API-Key': key } });
const body = await show.json().catch(() => ({}));
if (show.status() !== 200 || body.issue?.id !== ids.panel) t.problems.push(`GET issue.json: HTTP ${show.status()}`);
const list = await p().request.get(`${t.BASE}/projects/e2e-project/issues.json`, { headers: { 'X-Redmine-API-Key': key } });
if (list.status() !== 200) t.problems.push(`GET issues.json: HTTP ${list.status()}`);
const xml = await p().request.get(`${t.BASE}/issues/${ids.panel}.xml`, { headers: { 'X-Redmine-API-Key': key } });
if (xml.status() !== 200) t.problems.push(`GET issue.xml: HTTP ${xml.status()}`);
const plugin = await p().request.get(`${t.BASE}/projects/e2e-project/recurrences.json`, { headers: { 'X-Redmine-API-Key': key } });
if (plugin.status() < 400) t.problems.push(`plugin route answered as API: HTTP ${plugin.status()}`);

const summary = `issue.json ${show.status()} (keys: ${Object.keys(body.issue || {}).join(', ')}); issues.json ${list.status()}; issue.xml ${xml.status()}; recurrences.json ${plugin.status()}`;
console.log(summary);
await t.login('manager');
await t.go(`/issues/${ids.panel}.json`);
await t.shot('issue-json', `REST API with a recurrence on the issue: ${summary}`, { full: false });

reset();
await t.done();
