import { LightningElement } from 'lwc';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';

const VALUE_LABELS = {
  ANALYSIS_READY: 'Analysis Ready',
  NATIVE_READY: 'Native Ready',
  READY_FOR_NATIVE_DATA: 'Ready for Native Data',
  MISSING_NATIVE_SOURCE: 'Missing Native Source',
  MISSING_SERVICE_CLOUD_DATA: 'Missing Service Cloud Data',
  PASS: 'Pass',
  WARN: 'Warning',
  FAIL: 'Fail',
  INFO: 'Info'
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

export default class XcAfccDataHealth extends LightningElement {
  summary;
  busy = false;
  columns = [
    { label: 'Check', fieldName: 'name' },
    { label: 'Status', fieldName: 'statusLabel' },
    { label: 'Detail', fieldName: 'detailLabel' }
  ];

  connectedCallback() {
    this.load();
  }

  async load() {
    this.summary = await getLatestSummary();
  }

  async run() {
    this.busy = true;
    try {
      this.summary = await runDataHealth();
    } finally {
      this.busy = false;
    }
  }

  get resultLabel() {
    return friendlyValue(this.rawResult);
  }

  get rawResult() {
    return this.summary && this.summary.result ? this.summary.result : 'Not Run';
  }

  get badgeClass() {
    if (this.rawResult === 'PASS') {
      return 'status-badge pass';
    }
    if (this.rawResult === 'WARN' || this.rawResult === 'READY_FOR_NATIVE_DATA' || this.rawResult === 'NATIVE_READY') {
      return 'status-badge warn';
    }
    if (this.rawResult === 'FAIL') {
      return 'status-badge fail';
    }
    return 'status-badge neutral';
  }

  get healthRows() {
    const checks = this.summary && this.summary.checks ? this.summary.checks : [];
    return checks.map((check) => ({
      ...check,
      statusLabel: friendlyValue(check.status),
      detailLabel: friendlyValue(check.detail)
    }));
  }
}
