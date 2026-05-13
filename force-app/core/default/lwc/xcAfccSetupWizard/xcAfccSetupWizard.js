import { LightningElement } from 'lwc';
import ensureDefaultConfig from '@salesforce/apex/XC_AFCC_SetupController.ensureDefaultConfig';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';
import getSummary from '@salesforce/apex/XC_AFCC_DashboardController.getSummary';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import importCsv from '@salesforce/apex/XC_AFCC_CsvImportService.importCsv';

const CSV_HEADER = 'source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome\n';

export default class XcAfccSetupWizard extends LightningElement {
  state;
  summary;
  health;
  importResult;
  csvBody = CSV_HEADER;
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

  connectedCallback() {
    this.load();
  }

  async load() {
    await this.run(async () => {
      const [state, summary, health] = await Promise.all([getSetupState(), getSummary(), getLatestSummary()]);
      this.state = state;
      this.summary = summary;
      this.health = health;
    });
  }

  async ensure() {
    await this.run(async () => {
      await ensureDefaultConfig();
      await this.load();
    });
  }

  bodyChanged(event) {
    this.csvBody = event.detail.value;
  }

  async importData() {
    await this.run(async () => {
      this.importResult = await importCsv({ fileName: 'usage-import.csv', csvBody: this.csvBody });
      const [summary, health] = await Promise.all([getSummary(), getLatestSummary()]);
      this.summary = summary;
      this.health = health;
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
    return this.state && this.state.csvImportAvailable ? 'Available' : 'Unavailable';
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
    if (result === 'WARN' || result === 'READY_FOR_IMPORT') {
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
}
