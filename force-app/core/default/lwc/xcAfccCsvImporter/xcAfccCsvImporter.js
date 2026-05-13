import { LightningElement } from 'lwc';
import importCsv from '@salesforce/apex/XC_AFCC_CsvImportService.importCsv';

const CSV_HEADER = 'source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome\n';
const STATUS_LABELS = {
  COMPLETED: 'Completed',
  COMPLETED_WITH_ERRORS: 'Completed with Errors',
  FAILED: 'Failed',
  RUNNING: 'Running',
  PENDING: 'Pending'
};

function friendlyValue(value) {
  if (!value) {
    return value;
  }
  if (STATUS_LABELS[value]) {
    return STATUS_LABELS[value];
  }
  return String(value).includes('_')
    ? String(value)
        .toLowerCase()
        .split('_')
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(' ')
    : value;
}

export default class XcAfccCsvImporter extends LightningElement {
  csvBody = CSV_HEADER;
  result;
  busy = false;

  bodyChanged(event) {
    this.csvBody = event.detail.value;
  }

  async importData() {
    this.busy = true;
    try {
      this.result = await importCsv({ fileName: 'usage-import.csv', csvBody: this.csvBody });
    } finally {
      this.busy = false;
    }
  }

  get resultStatus() {
    return this.result ? friendlyValue(this.result.status) : '';
  }
}
