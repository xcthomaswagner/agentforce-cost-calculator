#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';

const defaults = {
  targetOrg: process.env.XC_AFCC_TARGET_ORG || '',
  runKey: process.env.XC_AFCC_RUN_KEY || '',
  caseSubjectPrefix: process.env.XC_AFCC_CASE_SUBJECT_PREFIX || '',
  count: Number(process.env.XC_AFCC_CASE_COUNT || 10),
  agentId: process.env.XC_AFCC_AGENT_ID || '',
  externalClientAppId: process.env.XC_AFCC_ECA_ID || '',
  oauthConsumerId: process.env.XC_AFCC_OAUTH_CONSUMER_ID || '',
  apiHost: process.env.XC_AFCC_AGENT_API_HOST || 'https://api.salesforce.com',
  delayMs: Number(process.env.XC_AFCC_AGENT_API_DELAY_MS || 250),
  turns: Number(process.env.XC_AFCC_AGENT_API_TURNS || 2),
  concurrency: Number(process.env.XC_AFCC_AGENT_API_CONCURRENCY || 1)
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
    else if (arg === '--agent-id') args.agentId = next();
    else if (arg === '--eca-id') args.externalClientAppId = next();
    else if (arg === '--consumer-id') args.oauthConsumerId = next();
    else if (arg === '--api-host') args.apiHost = next();
    else if (arg === '--delay-ms') args.delayMs = Number(next());
    else if (arg === '--turns') args.turns = Number(next());
    else if (arg === '--concurrency') args.concurrency = Number(next());
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
  scripts/conversation/run-agent-api-conversations.mjs \\
    --target-org agentcalc-af \\
    --agent-id 0Xx... \\
    --eca-id 0xI... \\
    --consumer-id 888... \\
    --count 150 \\
    --concurrency 8

Environment variables from scripts/mvp/03-run-prod-like-agentforce-sandbox.sh are also supported.

Prerequisite: External Client App REST secret access must be enabled long enough for this runner to retrieve the OAuth consumer secret.`);
}

function sfJson(args) {
  const output = execFileSync('sf', [...args, '--json'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
  const parsed = JSON.parse(output);
  if (parsed.status && parsed.status !== 0) {
    throw new Error(parsed.message || `Salesforce CLI failed: sf ${args.join(' ')}`);
  }
  return parsed.result;
}

function parseOauthLink(value) {
  if (!value || !String(value).includes(':')) return value || '';
  return String(value).split(':').pop();
}

function resolveOauthConsumerId(targetOrg, externalClientAppId, suppliedId) {
  if (!suppliedId) return '';
  if (String(suppliedId).startsWith('888')) return suppliedId;

  const escapedAppId = soqlString(externalClientAppId);
  const escapedSuppliedId = soqlString(suppliedId);
  const settingsQuery = [
    'SELECT Id, OauthLink',
    'FROM ExtlClntAppOauthSettings',
    `WHERE Id = '${escapedSuppliedId}' OR ExternalClientApplicationId = '${escapedAppId}'`,
    'ORDER BY LastModifiedDate DESC',
    'LIMIT 1'
  ].join(' ');
  const settingsRows = sfJson(['data', 'query', '--target-org', targetOrg, '--query', settingsQuery]).records || [];
  if (settingsRows.length > 0 && settingsRows[0].OauthLink) {
    return parseOauthLink(settingsRows[0].OauthLink);
  }

  const consumerQuery = [
    'SELECT ExtlClntAppOauthSettingsId',
    'FROM ExtlClntAppOauthConsumer',
    `WHERE Id = '${escapedSuppliedId}'`,
    'LIMIT 1'
  ].join(' ');
  const consumerRows = sfJson(['data', 'query', '--target-org', targetOrg, '--query', consumerQuery]).records || [];
  if (consumerRows.length > 0 && consumerRows[0].ExtlClntAppOauthSettingsId) {
    const linkedSettingsQuery = [
      'SELECT OauthLink',
      'FROM ExtlClntAppOauthSettings',
      `WHERE Id = '${soqlString(consumerRows[0].ExtlClntAppOauthSettingsId)}'`,
      'LIMIT 1'
    ].join(' ');
    const linkedSettingsRows = sfJson(['data', 'query', '--target-org', targetOrg, '--query', linkedSettingsQuery]).records || [];
    if (linkedSettingsRows.length > 0 && linkedSettingsRows[0].OauthLink) {
      return parseOauthLink(linkedSettingsRows[0].OauthLink);
    }
  }

  return suppliedId;
}

function soqlString(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body = {};
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = { rawBody: text };
    }
  }
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${JSON.stringify(body)}`);
  }
  return body;
}

function compactRecord(record) {
  return {
    caseId: record.Id,
    caseNumber: record.CaseNumber,
    subject: record.Subject,
    priority: record.Priority,
    contactName: record.Contact?.Name || 'Customer Contact',
    contactEmail: record.Contact?.Email || 'customer@example.com',
    accountName: record.Account?.Name || 'Customer Account'
  };
}

function buildUtterances(item, turnCount) {
  const messages = [
    `Hi, I am ${item.contactName} from ${item.accountName}. My email is ${item.contactEmail}. I am following up on case ${item.caseNumber}: ${item.subject}. The issue is still happening and we need support to review it.`,
    `Yes, please proceed. Keep this tied to case ${item.caseNumber}, keep the priority as ${item.priority || 'High'}, and summarize the next support step for our team.`
  ];
  return messages.slice(0, Math.max(1, Math.min(turnCount, messages.length)));
}

async function runConversation({ args, oauthToken, instanceUrl, item, index }) {
  const externalSessionKey = `afcc-${args.runKey || 'run'}-${item.caseNumber}-${index + 1}`;
  const session = await requestJson(`${args.apiHost}/einstein/ai-agent/v1/agents/${args.agentId}/sessions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${oauthToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      externalSessionKey,
      instanceConfig: { endpoint: instanceUrl },
      tz: 'America/Los_Angeles',
      streamingCapabilities: { chunkTypes: ['Text'] },
      bypassUser: true
    })
  });

  const sessionId = session.sessionId;
  const utterances = buildUtterances(item, args.turns);
  const replies = [];
  try {
    for (let turn = 0; turn < utterances.length; turn += 1) {
      const response = await requestJson(`${args.apiHost}/einstein/ai-agent/v1/sessions/${sessionId}/messages`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${oauthToken}`,
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            sequenceId: Date.now() + turn,
            type: 'Text',
            text: utterances[turn]
          },
          variables: []
        })
      });
      replies.push(...(response.messages || []).map((message) => ({
        type: message.type,
        message: message.message || ''
      })));
      await sleep(args.delayMs);
    }
  } finally {
    await requestJson(`${args.apiHost}/einstein/ai-agent/v1/sessions/${sessionId}`, {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${oauthToken}`,
        'x-session-end-reason': 'UserRequest'
      }
    });
  }

  console.log(`Conversation ${index + 1}/${args.count}: case ${item.caseNumber} session ${sessionId}`);
  return {
    caseNumber: item.caseNumber,
    sessionId,
    turns: utterances.length,
    firstReply: replies.find((reply) => reply.message)?.message || ''
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.targetOrg) throw new Error('--target-org is required');
  if (!args.agentId) throw new Error('--agent-id or XC_AFCC_AGENT_ID is required');
  if (!args.externalClientAppId) throw new Error('--eca-id or XC_AFCC_ECA_ID is required');
  if (!args.oauthConsumerId) throw new Error('--consumer-id or XC_AFCC_OAUTH_CONSUMER_ID is required');
  if (!Number.isInteger(args.count) || args.count < 1) throw new Error('--count must be a positive integer');
  if (!Number.isInteger(args.concurrency) || args.concurrency < 1 || args.concurrency > 20) {
    throw new Error('--concurrency must be an integer between 1 and 20');
  }

  const org = sfJson(['org', 'display', '--target-org', args.targetOrg, '--verbose']);
  const instanceUrl = org.instanceUrl;
  const adminToken = org.accessToken;
  const oauthConsumerId = resolveOauthConsumerId(args.targetOrg, args.externalClientAppId, args.oauthConsumerId);
  const prefix = args.caseSubjectPrefix || (args.runKey ? `AFCC Prod-Like ${args.runKey} Case` : 'AFCC Prod-Like');
  const query = [
    'SELECT Id, CaseNumber, Subject, Priority, Contact.Name, Contact.Email, Account.Name',
    'FROM Case',
    `WHERE Subject LIKE '${soqlString(prefix)}%'`,
    'ORDER BY CreatedDate ASC',
    `LIMIT ${args.count}`
  ].join(' ');
  const caseRows = sfJson(['data', 'query', '--target-org', args.targetOrg, '--query', query]).records.map(compactRecord);
  if (caseRows.length === 0) {
    throw new Error(`No seeded cases found with subject prefix: ${prefix}`);
  }

  const credentialUrl = `${instanceUrl}/services/data/v64.0/apps/oauth/credentials/${args.externalClientAppId}/${oauthConsumerId}?part=keyandsecret`;
  const credentials = await requestJson(credentialUrl, {
    headers: { Authorization: `Bearer ${adminToken}`, Accept: 'application/json' }
  });
  if (!credentials.key || !credentials.secret) {
    throw new Error('External Client App credentials were not returned. Enable REST secret access in External Client App Settings, then retry.');
  }

  const tokenBody = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: credentials.key,
    client_secret: credentials.secret
  });
  const oauth = await requestJson(`${instanceUrl}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: tokenBody
  });
  if (!oauth.access_token) throw new Error('Client credentials token response did not include access_token');

  const results = [];
  for (let start = 0; start < caseRows.length; start += args.concurrency) {
    const batch = caseRows.slice(start, start + args.concurrency);
    const batchResults = await Promise.all(batch.map((item, batchIndex) => runConversation({
      args,
      oauthToken: oauth.access_token,
      instanceUrl,
      item,
      index: start + batchIndex
    })));
    results.push(...batchResults);
    await sleep(args.delayMs);
  }

  console.log(JSON.stringify({
    targetOrg: args.targetOrg,
    agentId: args.agentId,
    requestedCount: args.count,
    completedCount: results.length,
    result: 'PASS',
    sessions: results
  }, null, 2));
}

main().catch((error) => {
  console.error(`Agent API runner failed: ${error.message}`);
  process.exit(1);
});
