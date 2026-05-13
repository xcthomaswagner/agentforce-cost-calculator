import { LightningElement } from 'lwc';
import ensureDefaultConfig from '@salesforce/apex/XC_AFCC_SetupController.ensureDefaultConfig';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';
export default class XcAfccSetupWizard extends LightningElement { state; connectedCallback(){ this.load(); } async load(){ this.state = await getSetupState(); } async ensure(){ await ensureDefaultConfig(); await this.load(); } get stateText(){ return JSON.stringify(this.state, null, 2); } }
