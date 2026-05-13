import { LightningElement } from 'lwc';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';

export default class XcAfccDataHealth extends LightningElement {
  summary;
  busy = false;
  columns = [
    { label: 'Check', fieldName: 'name' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Detail', fieldName: 'detail' }
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
    return this.summary && this.summary.result ? this.summary.result : 'Not Run';
  }

  get badgeClass() {
    if (this.resultLabel === 'PASS') {
      return 'status-badge pass';
    }
    if (this.resultLabel === 'WARN' || this.resultLabel === 'READY_FOR_IMPORT') {
      return 'status-badge warn';
    }
    if (this.resultLabel === 'FAIL') {
      return 'status-badge fail';
    }
    return 'status-badge neutral';
  }
}
