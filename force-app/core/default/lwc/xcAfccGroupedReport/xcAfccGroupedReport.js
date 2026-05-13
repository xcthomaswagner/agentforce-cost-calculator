import { LightningElement } from 'lwc';
import getRows from '@salesforce/apex/XC_AFCC_GroupedReportController.getRows';

const VALUE_LABELS = {
  RESOLVED: 'Resolved',
  DEFERRED: 'Deferred',
  ESCALATED: 'Escalated',
  ABANDONED: 'Abandoned',
  UNKNOWN: 'Unknown',
  FLEX_CREDITS: 'Flex Credits',
  PRIMARY_CASE: 'Primary Case',
  EVEN_SPLIT: 'Even Split'
};

function friendlyValue(value) {
  if (!value) {
    return value;
  }
  if (VALUE_LABELS[value]) {
    return VALUE_LABELS[value];
  }
  return String(value).includes('_')
    ? String(value)
        .toLowerCase()
        .split('_')
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(' ')
    : value;
}

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
    const rows = await getRows({ groupByField: this.groupBy });
    this.rows = rows.map((row) => ({
      ...row,
      groupValue: friendlyValue(row.groupValue)
    }));
  }

  get hasRows() {
    return this.rows && this.rows.length > 0;
  }
}
