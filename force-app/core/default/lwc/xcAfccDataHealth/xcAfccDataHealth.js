import { LightningElement } from 'lwc';
import runDataHealth from '@salesforce/apex/XC_AFCC_DataHealthService.runDataHealth';
import getLatestSummary from '@salesforce/apex/XC_AFCC_DataHealthService.getLatestSummary';
export default class XcAfccDataHealth extends LightningElement { summary; columns=[{label:'Check',fieldName:'name'},{label:'Status',fieldName:'status'},{label:'Detail',fieldName:'detail'}]; connectedCallback(){ this.load(); } async load(){ this.summary = await getLatestSummary(); } async run(){ this.summary = await runDataHealth(); } }
