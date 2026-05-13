import { LightningElement } from 'lwc';
import getSetupState from '@salesforce/apex/XC_AFCC_SetupController.getSetupState';
export default class XcAfccAdminSettings extends LightningElement { state; connectedCallback(){ this.load(); } async load(){ this.state = await getSetupState(); } get stateText(){ return JSON.stringify(this.state, null, 2); } }
