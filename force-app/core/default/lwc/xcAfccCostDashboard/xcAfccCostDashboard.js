import { LightningElement } from 'lwc';
import getSummary from '@salesforce/apex/XC_AFCC_DashboardController.getSummary';

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
}
