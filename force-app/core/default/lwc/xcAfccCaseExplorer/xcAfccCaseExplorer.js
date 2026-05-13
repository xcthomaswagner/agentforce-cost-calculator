import { LightningElement } from 'lwc';
import explain from '@salesforce/apex/XC_AFCC_CaseExplorerController.explain';

export default class XcAfccCaseExplorer extends LightningElement {
  caseNumber = '';
  explanation;
  busy = false;
  columns = [
    { label: 'Action', fieldName: 'XC_AFCC_Action_Name__c' },
    { label: 'Queue', fieldName: 'XC_AFCC_Queue_Name__c' },
    { label: 'Outcome', fieldName: 'XC_AFCC_Case_Outcome__c' },
    { label: 'Cost', fieldName: 'XC_AFCC_Allocated_Cost__c', type: 'currency' }
  ];

  caseNumberChanged(event) {
    this.caseNumber = event.detail.value;
  }

  async explain() {
    this.busy = true;
    try {
      this.explanation = await explain({ caseId: null, caseNumber: this.caseNumber });
    } finally {
      this.busy = false;
    }
  }

  get rowCount() {
    return this.explanation && this.explanation.rows ? this.explanation.rows.length : 0;
  }
}
