import { LightningElement } from 'lwc';
import listScenarios from '@salesforce/apex/XC_AFCC_DemoScenarioService.listScenarios';
import seed from '@salesforce/apex/XC_AFCC_DemoSeeder.seed';
import resetSyntheticData from '@salesforce/apex/XC_AFCC_DemoResetService.resetSyntheticData';
export default class XcAfccDemoLauncher extends LightningElement { scenario='deferred-hotspot'; volume='small'; scenarioOptions=[]; volumeOptions=[{label:'Small',value:'small'},{label:'Medium',value:'medium'},{label:'Large',value:'large'}]; result; connectedCallback(){ this.load(); } async load(){ this.scenarioOptions=(await listScenarios()).map(v=>({label:v,value:v})); } scenarioChanged(e){ this.scenario=e.detail.value; } volumeChanged(e){ this.volume=e.detail.value; } async seed(){ this.result=await seed({scenarioName:this.scenario, volume:this.volume}); } async reset(){ this.result=await resetSyntheticData(); } get resultText(){ return JSON.stringify(this.result, null, 2); } }
