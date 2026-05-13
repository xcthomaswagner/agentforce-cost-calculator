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

  get config() {
    return this.state && this.state.config ? this.state.config : {};
  }

  get hasConfig() {
    return Boolean(this.state && this.state.config);
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
    return this.state && this.state.csvImportAvailable ? 'Fallback Enabled' : 'Fallback Disabled';
  }

  get billingModel() {
    return this.config.XC_AFCC_Billing_Model__c || 'Not Set';
  }

  get allocationMethod() {
    return this.config.XC_AFCC_Allocation_Method__c || 'Not Set';
  }

  get contractCreditRate() {
    return this.formatRate(this.config.XC_AFCC_Contract_Credit_Rate__c);
  }

  get contractConversationRate() {
    return this.formatCurrency(this.config.XC_AFCC_Contract_Conversation_Rate__c);
  }

  get defaultCreditRate() {
    return this.formatRate(this.config.XC_AFCC_Default_Credit_Rate__c);
  }

  get defaultConversationRate() {
    return this.formatCurrency(this.config.XC_AFCC_Default_Conversation_Rate__c);
  }

  get installMode() {
    return this.config.XC_AFCC_Install_Mode__c || 'Not Set';
  }

  get demoOverrideEnabled() {
    return this.config.XC_AFCC_Demo_Override_Enabled__c ? 'Yes' : 'No';
  }

  get demoOverrideExpires() {
    return this.config.XC_AFCC_Demo_Override_Expires_On__c || 'Not Set';
  }

  get demoOverrideReason() {
    return this.config.XC_AFCC_Demo_Override_Reason__c || 'Not Set';
  }

  formatRate(value) {
    return value === undefined || value === null ? 'Not Set' : String(value);
  }

  formatCurrency(value) {
    if (value === undefined || value === null) {
      return 'Not Set';
    }
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value);
  }
}
