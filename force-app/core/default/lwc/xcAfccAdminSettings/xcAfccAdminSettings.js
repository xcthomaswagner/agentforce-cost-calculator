import { LightningElement } from 'lwc';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';

export default class XcAfccAdminSettings extends LightningElement {
  state;

  connectedCallback() {
    this.load();
  }

  async load() {
    this.state = await getSetupState();
  }

  get environment() {
    return this.state && this.state.environment ? this.state.environment : {};
  }

  get orgName() {
    return this.environment.orgName || 'Unknown';
  }

  get orgType() {
    return this.environment.organizationType || 'Unknown';
  }

  get sandboxStatus() {
    return this.environment.isSandbox ? 'Yes' : 'No';
  }

  get productionStatus() {
    return this.environment.isProduction ? 'Yes' : 'No';
  }

  get csvStatus() {
    return this.state && this.state.csvImportAvailable ? 'Available' : 'Unavailable';
  }
}
