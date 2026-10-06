// Helpers for this plugin's scenarios: reset the plugin's seed data and run
// commands (rails runner, rake) against the same Redmine as the server.
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
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

// Runs Ruby code with rails runner (through a file, so any quoting works).
export function rails(code) {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'e2e-')), 'code.rb');
  fs.writeFileSync(file, code);
  try { return sh(`bundle exec rails runner ${file}`).trim(); } finally { fs.rmSync(path.dirname(file), { recursive: true }); }
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
