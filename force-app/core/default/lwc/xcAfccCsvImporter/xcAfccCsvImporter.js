import { LightningElement } from 'lwc';
import importCsv from '@salesforce/apex/XC_AFCC_CsvImportService.importCsv';

const CSV_HEADER = 'source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome\n';

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
}
