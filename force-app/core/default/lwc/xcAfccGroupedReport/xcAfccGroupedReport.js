import { LightningElement } from 'lwc';
import getRows from '@salesforce/apex/XC_AFCC_GroupedReportController.getRows';

export default class XcAfccGroupedReport extends LightningElement {
  groupBy = 'queue';
  rows = [];
  options = [
    { label: 'Queue', value: 'queue' },
    { label: 'Agent', value: 'agent' },
    { label: 'Topic', value: 'topic' },
    { label: 'Outcome', value: 'outcome' },
    { label: 'Channel', value: 'channel' },
    { label: 'Date', value: 'date' }
  ];
  columns = [
    { label: 'Group', fieldName: 'groupValue' },
    { label: 'Rows', fieldName: 'rowCount', type: 'number' },
    { label: 'Credits', fieldName: 'credits', type: 'number' },
    { label: 'Cost', fieldName: 'allocatedCost', type: 'currency' }
  ];

  connectedCallback() {
    this.load();
  }

  async change(event) {
    this.groupBy = event.detail.value;
    await this.load();
  }

  async load() {
    this.rows = await getRows({ groupByField: this.groupBy });
  }

  get hasRows() {
    return this.rows && this.rows.length > 0;
  }
}
