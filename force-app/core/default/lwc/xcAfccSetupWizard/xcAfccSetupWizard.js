import { LightningElement } from 'lwc';
import ensureDefaultConfig from '@salesforce/apex/XC_AFCC_SetupController.ensureDefaultConfig';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';
import getSummary from '@salesforce/apex/XC_AFCC_DashboardController.getSummary';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import getNativeReadiness from '@salesforce/apex/XC_AFCC_NativeUsageService.getReadiness';
import syncNativeUsage from '@salesforce/apex/XC_AFCC_NativeUsageService.syncNativeUsage';

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
    { label: 'Status', fieldName: 'status' },
    { label: 'Detail', fieldName: 'detail' }
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
    return this.health && this.health.result ? this.health.result : 'Not Run';
  }

  get healthBadgeClass() {
    const result = this.healthResult;
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
    return this.nativeReadiness && this.nativeReadiness.result ? this.nativeReadiness.result : 'Not Checked';
  }

  get nativeBadgeClass() {
    const result = this.nativeResult;
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
}
