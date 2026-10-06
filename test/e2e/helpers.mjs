// Helpers for this plugin's scenarios: reset the plugin's seed data and run
// commands (rails runner, rake) against the same Redmine as the server.
import { execSync } from 'node:child_process';
import path from 'node:path';

const REDMINE = process.env.REDMINE_DIR || 'redmine';
const ENV = { ...process.env, RAILS_ENV: process.env.RMP_SERVER_ENV || 'production' };

export function sh(cmd) {
  return execSync(cmd, { cwd: REDMINE, env: ENV, stdio: ['ignore', 'pipe', 'pipe'] }).toString();
}

// Runs test/e2e/seed.rb again and returns the ids of the plugin's issues.
export function reset() {
  const out = sh(`bundle exec rails runner ${path.resolve('test/e2e/seed.rb')}`);
  const line = out.split('\n').find(l => l.startsWith('E2E_IDS '));
  return JSON.parse(line.slice('E2E_IDS '.length));
}

export function rails(code) {
  return sh(`bundle exec rails runner ${JSON.stringify(code)}`).trim();
}

// The cron entry point: rake redmine:issue_recurring:renew_all
export function renewAll() {
  return sh('bundle exec rake redmine:issue_recurring:renew_all');
}

// Fills and submits the recurrence form opened with "Add" or "Edit".
export async function fillRecurrence(page, values) {
  for (const [field, value] of Object.entries(values)) {
    const el = page.locator(`#recurrence_${field}`);
    if (await el.evaluate(e => e.tagName) === 'SELECT') {
      await el.click();
      await el.selectOption(String(value));
      await el.click();
    } else {
      await el.fill(String(value));
    }
  }
}
