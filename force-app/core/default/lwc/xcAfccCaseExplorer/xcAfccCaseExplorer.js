import { LightningElement } from 'lwc';
import explain from '@salesforce/apex/XC_AFCC_CaseExplorerController.explain';

const VALUE_LABELS = {
  RESOLVED: 'Resolved',
  DEFERRED: 'Deferred',
  ESCALATED: 'Escalated',
  ABANDONED: 'Abandoned',
  UNKNOWN: 'Unknown'
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

export default class XcAfccCaseExplorer extends LightningElement {
  caseNumber = '';
  explanation;
  busy = false;
  columns = [
    { label: 'Action', fieldName: 'XC_AFCC_Action_Name__c' },
    { label: 'Queue', fieldName: 'XC_AFCC_Queue_Name__c' },
    { label: 'Outcome', fieldName: 'outcomeLabel' },
    { label: 'Cost', fieldName: 'XC_AFCC_Allocated_Cost__c', type: 'currency' }
  ];

  caseNumberChanged(event) {
    this.caseNumber = event.detail.value;
  }

  async explain() {
    this.busy = true;
    try {
      const explanation = await explain({ caseId: null, caseNumber: this.caseNumber });
      this.explanation = {
        ...explanation,
        rows: (explanation.rows || []).map((row) => ({
          ...row,
          outcomeLabel: friendlyValue(row.XC_AFCC_Case_Outcome__c)
        }))
      };
    } finally {
      this.busy = false;
    }
  }

  get rowCount() {
    return this.explanation && this.explanation.rows ? this.explanation.rows.length : 0;
  }
}
