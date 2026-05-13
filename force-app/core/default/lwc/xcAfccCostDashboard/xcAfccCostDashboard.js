import { LightningElement } from 'lwc';
import getSummary from '@salesforce/apex/XC_AFCC_DashboardController.getSummary';

function friendlyValue(value) {
  return value && String(value).includes('_')
    ? String(value)
        .toLowerCase()
        .split('_')
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(' ')
    : value;
}

export default class XcAfccCostDashboard extends LightningElement {
  summary;
  columns = [
    { label: 'Queue', fieldName: 'groupValue' },
    { label: 'Rows', fieldName: 'rowCount', type: 'number' },
    { label: 'Credits', fieldName: 'credits', type: 'number' },
    { label: 'Cost', fieldName: 'allocatedCost', type: 'currency' }
  ];

  connectedCallback() {
    this.load();
  }

  async load() {
    this.summary = await getSummary();
  }

  get hasUsage() {
    return this.summary && this.summary.ledgerRows > 0;
  }

  get queueRows() {
    const rows = this.summary && this.summary.costByQueue ? this.summary.costByQueue : [];
    return rows.map((row) => ({
      ...row,
      groupValue: friendlyValue(row.groupValue)
    }));
  }
}
