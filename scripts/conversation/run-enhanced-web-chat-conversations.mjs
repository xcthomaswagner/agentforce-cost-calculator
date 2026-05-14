#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const defaults = {
  targetOrg: process.env.XC_AFCC_TARGET_ORG || '',
  runKey: process.env.XC_AFCC_RUN_KEY || '',
  caseSubjectPrefix: process.env.XC_AFCC_CASE_SUBJECT_PREFIX || '',
  count: Number(process.env.XC_AFCC_CASE_COUNT || 5),
  chatUrl: process.env.XC_AFCC_EWC_URL || '',
  caseNumber: process.env.XC_AFCC_CASE_NUMBER || '',
  message: process.env.XC_AFCC_EWC_MESSAGE || '',
  expectText: (process.env.XC_AFCC_EWC_EXPECT_TEXT || '').split('|').filter(Boolean),
  eventActionRegex: process.env.XC_AFCC_EWC_EVENT_ACTION_REGEX || 'actionName: Look_Up_Case_Status_Live_.*isSuccessful: true',
  outputDir: process.env.XC_AFCC_CONVERSATION_OUTPUT_DIR || 'output/conversations',
  timeoutMs: Number(process.env.XC_AFCC_EWC_TIMEOUT_MS || 90000),
  delayMs: Number(process.env.XC_AFCC_EWC_DELAY_MS || 1000),
  headed: process.env.XC_AFCC_EWC_HEADED === 'true',
  keepOpen: process.env.XC_AFCC_EWC_KEEP_OPEN === 'true',
  requireEventLog: process.env.XC_AFCC_EWC_REQUIRE_EVENT_LOG !== 'false'
};

function parseArgs(argv) {
  const args = { ...defaults };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      return argv[i];
    };
    if (arg === '--target-org') args.targetOrg = next();
    else if (arg === '--run-key') args.runKey = next();
    else if (arg === '--case-subject-prefix') args.caseSubjectPrefix = next();
    else if (arg === '--count') args.count = Number(next());
    else if (arg === '--chat-url') args.chatUrl = next();
    else if (arg === '--case-number') args.caseNumber = next();
    else if (arg === '--message') args.message = next();
    else if (arg === '--expect-text') args.expectText.push(next());
    else if (arg === '--event-action-regex') args.eventActionRegex = next();
    else if (arg === '--output-dir') args.outputDir = next();
    else if (arg === '--timeout-ms') args.timeoutMs = Number(next());
    else if (arg === '--delay-ms') args.delayMs = Number(next());
    else if (arg === '--headed') args.headed = true;
    else if (arg === '--headless') args.headed = false;
    else if (arg === '--keep-open') args.keepOpen = true;
    else if (arg === '--no-event-log-check') args.requireEventLog = false;
    else if (arg === '--help') {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }
  return args;
}

function printUsage() {
  console.log(`Usage:
  scripts/conversation/run-enhanced-web-chat-conversations.mjs \\
    --target-org agentcalc-af \\
    --chat-url https://.../apex/ESWX... \\
    --case-subject-prefix "AFCC Prod-Like afcc-prod-like-YYYYMMDDHHMMSS Case" \\
    --count 150

Quick single-case smoke test:
  scripts/conversation/run-enhanced-web-chat-conversations.mjs \\
    --target-org agentcalc-af \\
    --chat-url https://.../apex/ESWX... \\
    --case-number 00001322 \\
    --count 1 \\
    --headed

Custom prompt smoke test:
  scripts/conversation/run-enhanced-web-chat-conversations.mjs \\
    --target-org agentcalc-af \\
    --chat-url https://.../apex/ESWX... \\
    --message "What is total Agentforce cost?" \\
    --expect-text "$0.95" \\
    --event-action-regex "actionName: Answer_Cost_Question_Live_.*isSuccessful: true" \\
    --count 1

The runner drives the real Enhanced Web Chat widget. It does not insert MessagingSession,
Conversation, AgentWork, staging, or ledger records directly.`);
}

function sfJson(args) {
  let output = '';
  try {
    output = execFileSync('sf', [...args, '--json'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    });
  } catch (error) {
    const stderr = error.stderr ? String(error.stderr).trim() : '';
    const stdout = error.stdout ? String(error.stdout).trim() : '';
    throw new Error(`Salesforce CLI failed: sf ${args.join(' ')}${stderr ? `\n${stderr}` : ''}${stdout ? `\n${stdout}` : ''}`);
  }
  const parsed = JSON.parse(output);
  if (parsed.status && parsed.status !== 0) {
    throw new Error(parsed.message || `Salesforce CLI failed: sf ${args.join(' ')}`);
  }
  return parsed.result;
}

function soqlString(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function compactRecord(record) {
  return {
    caseId: record.Id,
    caseNumber: record.CaseNumber,
    subject: record.Subject,
    status: record.Status,
    priority: record.Priority,
    contactName: record.Contact?.Name || 'Customer Contact',
    contactEmail: record.Contact?.Email || 'customer@example.invalid',
    accountName: record.Account?.Name || 'Customer Account'
  };
}

function resolveCases(args) {
  if (args.message && !args.caseNumber && !args.caseSubjectPrefix && !args.runKey) {
    return [{
      caseId: null,
      caseNumber: 'custom-message',
      subject: 'Custom Enhanced Web Chat prompt',
      status: '',
      priority: '',
      contactName: 'Customer Contact',
      contactEmail: 'customer@example.invalid',
      accountName: 'Customer Account'
    }];
  }

  if (args.caseNumber) {
    const rows = sfJson([
      'data',
      'query',
      '--target-org',
      args.targetOrg,
      '--query',
      [
        'SELECT Id, CaseNumber, Subject, Status, Priority, Contact.Name, Contact.Email, Account.Name',
        'FROM Case',
        `WHERE CaseNumber = '${soqlString(args.caseNumber)}'`,
        'LIMIT 1'
      ].join(' ')
    ]).records || [];
    if (!rows.length) throw new Error(`No Case found for case number ${args.caseNumber}`);
    return rows.map(compactRecord);
  }

  const prefix = args.caseSubjectPrefix || (args.runKey ? `AFCC Prod-Like ${args.runKey} Case` : 'AFCC Prod-Like');
  const rows = sfJson([
    'data',
    'query',
    '--target-org',
    args.targetOrg,
    '--query',
    [
      'SELECT Id, CaseNumber, Subject, Status, Priority, Contact.Name, Contact.Email, Account.Name',
      'FROM Case',
      `WHERE Subject LIKE '${soqlString(prefix)}%'`,
      'ORDER BY CreatedDate ASC',
      `LIMIT ${args.count}`
    ].join(' ')
  ]).records || [];
  if (!rows.length) throw new Error(`No seeded cases found with subject prefix: ${prefix}`);
  return rows.map(compactRecord);
}

function resolveOrgSession(targetOrg) {
  const org = sfJson(['org', 'display', '--target-org', targetOrg, '--verbose']);
  if (!org.instanceUrl || !org.accessToken) {
    throw new Error(`Could not resolve Salesforce session for target org ${targetOrg}`);
  }
  return {
    instanceUrl: org.instanceUrl,
    accessToken: org.accessToken
  };
}

function safeFilePart(value) {
  return String(value).replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');
}

function buildCustomerMessage(item, args) {
  if (args.message) {
    return args.message
      .replaceAll('{caseNumber}', item.caseNumber || '')
      .replaceAll('{contactName}', item.contactName || '')
      .replaceAll('{contactEmail}', item.contactEmail || '')
      .replaceAll('{accountName}', item.accountName || '');
  }
  return [
    `Hi, I am ${item.contactName} from ${item.accountName}.`,
    `My email is ${item.contactEmail}.`,
    `Please look up case ${item.caseNumber} and tell me the status, priority, account, contact, and next support step.`
  ].join(' ');
}

function latestEventLog(targetOrg, startedAtIso) {
  const result = sfJson([
    'data',
    'query',
    '--target-org',
    targetOrg,
    '--query',
    [
      'SELECT EventDateTime, EventLabel',
      'FROM ConversationDefinitionEventLog',
      `WHERE EventDateTime >= ${startedAtIso}`,
      'ORDER BY EventDateTime ASC'
    ].join(' ')
  ]);
  return result.records || [];
}

function countMatchingActions(targetOrg, eventActionRegex) {
  const actionRegex = new RegExp(eventActionRegex);
  const result = sfJson([
    'data',
    'query',
    '--target-org',
    targetOrg,
    '--query',
    [
      'SELECT EventLabel',
      'FROM ConversationDefinitionEventLog',
      'ORDER BY EventDateTime DESC',
      'LIMIT 2000'
    ].join(' ')
  ]);
  return (result.records || []).filter((record) => (
    actionRegex.test(record.EventLabel || '')
  )).length;
}

function toSoqlDateTime(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

async function waitForEventSummary(targetOrg, startedAtIso, expectedActionCount, eventActionRegex, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let records = [];
  let summary = summarizeEventLogs(records, eventActionRegex);
  while (Date.now() < deadline) {
    records = latestEventLog(targetOrg, startedAtIso);
    summary = summarizeEventLogs(records, eventActionRegex);
    if (summary.actionSuccesses >= expectedActionCount) {
      return { records, summary };
    }
    await sleep(5000);
  }
  return { records, summary };
}

async function waitForActionSuccessDelta(targetOrg, eventActionRegex, baselineCount, expectedDelta, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let currentCount = countMatchingActions(targetOrg, eventActionRegex);
  while (Date.now() < deadline) {
    currentCount = countMatchingActions(targetOrg, eventActionRegex);
    if (currentCount - baselineCount >= expectedDelta) {
      return {
        baselineCount,
        currentCount,
        delta: currentCount - baselineCount
      };
    }
    await sleep(5000);
  }
  return {
    baselineCount,
    currentCount,
    delta: currentCount - baselineCount
  };
}

async function loadPlaywright() {
  try {
    return await import('playwright');
  } catch {
    throw new Error('Playwright is not installed. Run `npm install`, then retry.');
  }
}

function chromeLaunchOptions(args) {
  const options = {
    headless: !args.headed,
    args: ['--disable-dev-shm-usage']
  };
  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  if (existsSync(chromePath)) {
    options.executablePath = chromePath;
  } else {
    options.channel = 'chrome';
  }
  return options;
}

async function findChatFrame(page, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      const url = frame.url();
      if (!url.includes('/ESW') && !url.includes('my.site.com') && !url.includes('embeddedservice')) continue;
      const hasChat = await frame.locator('textarea, [contenteditable="true"], button:has-text("New Conversation")').count().catch(() => 0);
      if (hasChat > 0) return frame;
    }
    await sleep(500);
  }
  throw new Error('Enhanced Web Chat frame did not become available.');
}

async function clickIfVisible(locator, timeout = 1500) {
  try {
    await locator.first().click({ timeout });
    return true;
  } catch {
    return false;
  }
}

async function ensureFreshConversation(frame, timeoutMs) {
  await clickIfVisible(frame.getByRole('button', { name: /ask me anything|chat/i }), 5000);
  await sleep(1000);
  await clickIfVisible(frame.getByRole('button', { name: /new conversation/i }), 5000);
  const textarea = frame.locator('textarea, [contenteditable="true"]').last();
  await textarea.waitFor({ state: 'visible', timeout: timeoutMs });
  await frame.getByText(/how can i help you/i).last().waitFor({ state: 'visible', timeout: timeoutMs });
  await sleep(1000);
  return textarea;
}

async function sendMessage(frame, message, timeoutMs) {
  const textarea = frame.locator('textarea, [contenteditable="true"]').last();
  await textarea.waitFor({ state: 'visible', timeout: timeoutMs });
  await textarea.fill(message);
  const sendButton = frame.getByRole('button', { name: /send/i }).last();
  await sendButton.click({ timeout: 5000 });
}

async function waitForExpectedReply(frame, item, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  const expected = [
    item.caseNumber,
    item.status,
    item.priority
  ].map((value) => String(value || '').toLowerCase());

  let lastText = '';
  while (Date.now() < deadline) {
    const bodyText = await frame.locator('body').innerText({ timeout: 2000 }).catch(() => '');
    lastText = bodyText;
    const normalized = bodyText.toLowerCase();
    const hasExpected = expected.every((value) => value && normalized.includes(value));
    const hasFailure = /unable to look up|couldn't retrieve|technical issue|contact support directly/i.test(bodyText);
    if (hasExpected && !hasFailure) return bodyText;
    if (hasFailure) {
      throw new Error(`Agent returned a lookup failure for case ${item.caseNumber}: ${bodyText.slice(-500)}`);
    }
    await sleep(1000);
  }
  throw new Error(`Timed out waiting for expected reply for case ${item.caseNumber}. Last text: ${lastText.slice(-500)}`);
}

async function waitForExpectedCustomReply(frame, expectedText, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  const expected = expectedText.map((value) => String(value || '').toLowerCase()).filter(Boolean);

  let lastText = '';
  while (Date.now() < deadline) {
    const bodyText = await frame.locator('body').innerText({ timeout: 2000 }).catch(() => '');
    lastText = bodyText;
    const normalized = bodyText.toLowerCase();
    const hasExpected = expected.length === 0 || expected.every((value) => normalized.includes(value));
    const hasFailure = /unable to look up|couldn't retrieve|technical issue|contact support directly|i don't have access/i.test(bodyText);
    if (hasExpected && !hasFailure) return bodyText;
    if (hasFailure) {
      throw new Error(`Agent returned a failure for custom prompt: ${bodyText.slice(-500)}`);
    }
    await sleep(1000);
  }
  throw new Error(`Timed out waiting for expected custom reply. Last text: ${lastText.slice(-500)}`);
}

async function endConversation(frame) {
  const menuButtons = frame.locator('button').filter({ hasText: /^$/ });
  const visibleCount = await menuButtons.count().catch(() => 0);
  for (let i = 0; i < visibleCount; i += 1) {
    const button = menuButtons.nth(i);
    try {
      await button.click({ timeout: 500 });
      if (await clickIfVisible(frame.getByText(/end chat/i), 800)) return;
    } catch {
      // Continue scanning accessible icon-only menu buttons.
    }
  }
}

async function runOne({ browser, args, item, index, outputDir }) {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  const conversationStartedAt = new Date().toISOString();
  const screenshotBase = path.join(outputDir, `${String(index + 1).padStart(3, '0')}-${safeFilePart(item.caseNumber)}`);
  try {
    const loginUrl = `${args.orgSession.instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(args.orgSession.accessToken)}`;
    await page.goto(loginUrl, { waitUntil: 'domcontentloaded', timeout: args.timeoutMs });
    await page.goto(args.chatUrl, { waitUntil: 'domcontentloaded', timeout: args.timeoutMs });
    const frame = await findChatFrame(page, args.timeoutMs);
    await ensureFreshConversation(frame, args.timeoutMs);
    const message = buildCustomerMessage(item, args);
    await sendMessage(frame, message, args.timeoutMs);
    const replyText = args.message
      ? await waitForExpectedCustomReply(frame, args.expectText, args.timeoutMs)
      : await waitForExpectedReply(frame, item, args.timeoutMs);
    const screenshotPath = `${screenshotBase}-success.png`;
    await page.screenshot({ path: screenshotPath, fullPage: true });
    await endConversation(frame).catch(() => {});
    return {
      caseNumber: item.caseNumber,
      status: item.status,
      priority: item.priority,
      result: 'PASS',
      conversationStartedAt,
      screenshotPath,
      replyExcerpt: replyText.slice(-700)
    };
  } catch (error) {
    const screenshotPath = `${screenshotBase}-failure.png`;
    await page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => {});
    return {
      caseNumber: item.caseNumber,
      status: item.status,
      priority: item.priority,
      result: 'FAIL',
      conversationStartedAt,
      screenshotPath,
      error: error.message
    };
  } finally {
    if (!args.keepOpen) await context.close().catch(() => {});
  }
}

function summarizeEventLogs(records, eventActionRegex = defaults.eventActionRegex) {
  const actionRegex = new RegExp(eventActionRegex);
  const labels = records.map((record) => record.EventLabel || '');
  return {
    totalEvents: records.length,
    actionSuccesses: labels.filter((label) => actionRegex.test(label)).length,
    outputSafe: labels.filter((label) => /Copilot Message: INFORM, Is Output Safe\? true/.test(label)).length,
    instructionHigh: labels.filter((label) => /InstructionAdherence: HIGH/.test(label)).length,
    failures: labels.filter((label) => /InstructionAdherence: LOW|isSuccessful: false|Is Output Safe\? false/.test(label))
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.targetOrg) throw new Error('--target-org is required');
  if (!args.chatUrl) throw new Error('--chat-url or XC_AFCC_EWC_URL is required');
  if (!Number.isInteger(args.count) || args.count < 1) throw new Error('--count must be a positive integer');
  if (!Number.isInteger(args.timeoutMs) || args.timeoutMs < 10000) throw new Error('--timeout-ms must be at least 10000');

  const cases = resolveCases(args).slice(0, args.count);
  args.orgSession = resolveOrgSession(args.targetOrg);
  const runId = args.runKey || `ewc-${new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14)}`;
  const outputDir = path.resolve(args.outputDir, safeFilePart(runId));
  mkdirSync(outputDir, { recursive: true });

  const { chromium } = await loadPlaywright();
  const browser = await chromium.launch(chromeLaunchOptions(args));
  const startedAt = toSoqlDateTime(new Date());
  const baselineActionSuccessCount = countMatchingActions(args.targetOrg, args.eventActionRegex);
  const results = [];
  try {
    for (let i = 0; i < cases.length; i += 1) {
      const item = cases[i];
      console.log(`Enhanced Web Chat conversation ${i + 1}/${cases.length}: case ${item.caseNumber}`);
      const result = await runOne({ browser, args, item, index: i, outputDir });
      results.push(result);
      console.log(`${result.result}: case ${item.caseNumber}${result.error ? ` - ${result.error}` : ''}`);
      if (result.result !== 'PASS') break;
      await sleep(args.delayMs);
    }
  } finally {
    if (!args.keepOpen) await browser.close().catch(() => {});
  }

  const completedCount = results.filter((result) => result.result === 'PASS').length;
  const failed = results.filter((result) => result.result !== 'PASS');
  const actionSuccessDelta = args.requireEventLog
    ? await waitForActionSuccessDelta(args.targetOrg, args.eventActionRegex, baselineActionSuccessCount, completedCount, 180000)
    : { baselineCount: baselineActionSuccessCount, currentCount: baselineActionSuccessCount, delta: 0 };
  const eventResult = args.requireEventLog
    ? await waitForEventSummary(args.targetOrg, startedAt, completedCount, args.eventActionRegex, 30000)
    : { records: latestEventLog(args.targetOrg, startedAt), summary: summarizeEventLogs([], args.eventActionRegex) };
  const eventSummary = eventResult.summary;
  const summary = {
    targetOrg: args.targetOrg,
    chatUrl: args.chatUrl,
    requestedCount: args.count,
    selectedCaseCount: cases.length,
    completedCount,
    failedCount: failed.length,
    eventSummary,
    actionSuccessDelta,
    result: failed.length === 0 && (!args.requireEventLog || actionSuccessDelta.delta >= completedCount) ? 'PASS' : 'FAIL',
    outputDir,
    conversations: results
  };
  const summaryPath = path.join(outputDir, 'summary.json');
  writeFileSync(summaryPath, `${JSON.stringify(summary, null, 2)}\n`);
  console.log(JSON.stringify(summary, null, 2));

  if (summary.result !== 'PASS') {
    throw new Error(`Enhanced Web Chat runner failed. Summary: ${summaryPath}`);
  }
}

main().catch((error) => {
  console.error(`Enhanced Web Chat runner failed: ${error.message}`);
  process.exit(1);
});
