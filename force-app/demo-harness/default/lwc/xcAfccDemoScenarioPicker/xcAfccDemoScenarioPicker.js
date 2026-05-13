import { LightningElement } from 'lwc';
import listScenarios from '@salesforce/apex/XC_AFCC_DemoScenarioService.listScenarios';
import loadScenario from '@salesforce/apex/XC_AFCC_DemoScenarioService.loadScenario';
export default class XcAfccDemoScenarioPicker extends LightningElement { scenario='deferred-hotspot'; options=[]; scenarioConfig; connectedCallback(){ this.init(); } async init(){ this.options=(await listScenarios()).map(v=>({label:v,value:v})); await this.load(); } async change(e){ this.scenario=e.detail.value; await this.load(); } async load(){ this.scenarioConfig=await loadScenario({scenarioName:this.scenario, volume:'small'}); } get scenarioText(){ return JSON.stringify(this.scenarioConfig, null, 2); } }
