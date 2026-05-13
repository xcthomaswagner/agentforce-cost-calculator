import { LightningElement } from 'lwc';
import ensureDefaultConfig from '@salesforce/apex/XC_AFCC_SetupController.ensureDefaultConfig';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';
import getSummary from '@salesforce/apex/XC_AFCC_DashboardController.getSummary';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import getNativeReadiness from '@salesforce/apex/XC_AFCC_NativeUsageService.getReadiness';
import syncNativeUsage from '@salesforce/apex/XC_AFCC_NativeUsageService.syncNativeUsage';

const VALUE_LABELS = {
  ANALYSIS_READY: 'Analysis Ready',
  NATIVE_READY: 'Native Ready',
  READY_FOR_NATIVE_DATA: 'Ready for Native Data',
  MISSING_NATIVE_SOURCE: 'Missing Native Source',
  MISSING_SERVICE_CLOUD_DATA: 'Missing Service Cloud Data',
  PASS: 'Pass',
  WARN: 'Warning',
  FAIL: 'Fail',
  INFO: 'Info',
  COMPLETED: 'Completed',
  COMPLETED_WITH_ERRORS: 'Completed with Errors',
  RUNNING: 'Running',
  FAILED: 'Failed',
  PENDING: 'Pending',
  FLEX_CREDITS: 'Flex Credits',
  PRIMARY_CASE: 'Primary Case',
  EVEN_SPLIT: 'Even Split',
  CSV_IMPORT: 'CSV Import'
};

function friendlyValue(value) {
  if (!value) {
    return value;
  }
  if (VALUE_LABELS[value]) {
    return VALUE_LABELS[value];
  }
  if (!String(value).includes('_')) {
    return value;
  }
  return String(value)
    .toLowerCase()
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

export default class XcAfccSetupWizard extends LightningElement {
  state;
  summary;
  health;
  nativeReadiness;
  nativeSyncResult;
  busy = false;
  error;

  healthColumns = [
    { label: 'Check', fieldName: 'name' },
    { label: 'Status', fieldName: 'statusLabel' },
    { label: 'Detail', fieldName: 'detailLabel' }
  ];

  queueColumns = [
    { label: 'Queue', fieldName: 'groupValue' },
    { label: 'Rows', fieldName: 'rowCount', type: 'number' },
    { label: 'Credits', fieldName: 'credits', type: 'number' },
    { label: 'Cost', fieldName: 'allocatedCost', type: 'currency' }
  ];

  sourceColumns = [
    { label: 'Source', fieldName: 'apiName' },
    { label: 'Available', fieldName: 'available', type: 'boolean' },
    { label: 'Accessible', fieldName: 'accessible', type: 'boolean' },
    { label: 'Rows', fieldName: 'rowCount', type: 'number' }
  ];

  connectedCallback() {
    this.load();
  }

  async load() {
    await this.run(async () => {
      const [state, summary, health, nativeReadiness] = await Promise.all([getSetupState(), getSummary(), getLatestSummary(), getNativeReadiness()]);
      this.state = state;
      this.summary = summary;
      this.health = health;
      this.nativeReadiness = nativeReadiness;
    });
  }

  async ensure() {
    await this.run(async () => {
      await ensureDefaultConfig();
      await this.load();
    });
  }

  async syncNative() {
    await this.run(async () => {
      this.nativeSyncResult = await syncNativeUsage();
      const [summary, health, nativeReadiness] = await Promise.all([getSummary(), getLatestSummary(), getNativeReadiness()]);
      this.summary = summary;
      this.health = health;
      this.nativeReadiness = nativeReadiness;
    });
  }

  async runHealth() {
    await this.run(async () => {
      this.health = await runDataHealth();
      this.summary = await getSummary();
    });
  }

  async run(operation) {
    this.busy = true;
    this.error = undefined;
    try {
      await operation();
    } catch (error) {
      this.error = error?.body?.message || error?.message || 'The operation failed.';
    } finally {
      this.busy = false;
    }
  }

  get environment() {
    return this.state && this.state.environment ? this.state.environment : {};
  }

  get configStatus() {
    return this.state && this.state.configCount > 0 ? 'Configured' : 'Missing';
  }

  get csvStatus() {
    return this.state && this.state.csvImportAvailable ? 'Fallback Enabled' : 'Fallback Disabled';
  }

  get needsConfig() {
    return !this.state || this.state.configCount === 0;
  }

  get orgType() {
    return this.environment.organizationType || 'Unknown';
  }

  get instanceName() {
    return this.environment.instanceName || 'Unknown';
  }

  get healthResult() {
    return friendlyValue(this.rawHealthResult);
  }

  get rawHealthResult() {
    return this.health && this.health.result ? this.health.result : 'Not Run';
  }

  get healthBadgeClass() {
    const result = this.rawHealthResult;
    if (result === 'PASS') {
      return 'status-badge pass';
    }
    if (result === 'WARN' || result === 'READY_FOR_NATIVE_DATA' || result === 'NATIVE_READY' || result === 'MISSING_NATIVE_SOURCE') {
      return 'status-badge warn';
    }
    if (result === 'FAIL') {
      return 'status-badge fail';
    }
    return 'status-badge neutral';
  }

  get hasUsage() {
    return this.summary && this.summary.ledgerRows > 0;
  }

  get nativeResult() {
    return friendlyValue(this.rawNativeResult);
  }

  get rawNativeResult() {
    return this.nativeReadiness && this.nativeReadiness.result ? this.nativeReadiness.result : 'Not Checked';
  }

  get nativeBadgeClass() {
    const result = this.rawNativeResult;
    if (result === 'ANALYSIS_READY') {
      return 'status-badge pass';
    }
    if (result === 'NATIVE_READY' || result === 'READY_FOR_NATIVE_DATA') {
      return 'status-badge warn';
    }
    if (result === 'MISSING_NATIVE_SOURCE' || result === 'MISSING_SERVICE_CLOUD_DATA') {
      return 'status-badge fail';
    }
    return 'status-badge neutral';
  }

  get nativeSources() {
    const sources = this.nativeReadiness && this.nativeReadiness.sources ? this.nativeReadiness.sources : [];
    return sources.map((source) => ({
      ...source,
      availableLabel: source.available ? 'Yes' : 'No',
      accessibleLabel: source.accessible ? 'Yes' : 'No'
    }));
  }

  get nativeMessages() {
    return this.nativeReadiness && this.nativeReadiness.messages ? this.nativeReadiness.messages : [];
  }

  get hasNativeMessages() {
    return this.nativeMessages.length > 0;
  }

  get healthRows() {
    const checks = this.health && this.health.checks ? this.health.checks : [];
    return checks.map((check) => ({
      ...check,
      statusLabel: friendlyValue(check.status),
      detailLabel: friendlyValue(check.detail)
    }));
  }

  get nativeSyncStatus() {
    return this.nativeSyncResult ? friendlyValue(this.nativeSyncResult.status) : '';
  }

  get queueRows() {
    const rows = this.summary && this.summary.costByQueue ? this.summary.costByQueue : [];
    return rows.map((row) => ({
      ...row,
      groupValue: friendlyValue(row.groupValue)
    }));
  }
}
