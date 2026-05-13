import { LightningElement } from 'lwc';
import listScenarios from '@salesforce/apex/XC_AFCC_DemoScenarioService.listScenarios';
import seed from '@salesforce/apex/XC_AFCC_DemoSeeder.seed';
import resetSyntheticData from '@salesforce/apex/XC_AFCC_DemoResetService.resetSyntheticData';
import validateCurrentScenario from '@salesforce/apex/XC_AFCC_DemoReadinessService.validateCurrentScenario';

export default class XcAfccSyntheticDataGenerator extends LightningElement {
  scenario = 'deferred-hotspot';
  volume = 'small';
  scenarioOptions = [];
  volumeOptions = [
    { label: 'Small', value: 'small' },
    { label: 'Medium', value: 'medium' },
    { label: 'Large', value: 'large' }
  ];
  busy = false;
  error;
  seedResult;
  readiness;
  resetResult;

  connectedCallback() {
    this.loadScenarios();
  }

  async loadScenarios() {
    this.scenarioOptions = (await listScenarios()).map((value) => ({ label: value, value }));
  }

  scenarioChanged(event) {
    this.scenario = event.detail.value;
  }

  volumeChanged(event) {
    this.volume = event.detail.value;
  }

  async generate() {
    await this.run(async () => {
      this.resetResult = undefined;
      this.seedResult = await seed({ scenarioName: this.scenario, volume: this.volume });
      this.readiness = await validateCurrentScenario();
    });
  }

  async validate() {
    await this.run(async () => {
      this.readiness = await validateCurrentScenario();
    });
  }

  async reset() {
    await this.run(async () => {
      this.seedResult = undefined;
      this.readiness = undefined;
      this.resetResult = await resetSyntheticData();
    });
  }

  async run(operation) {
    this.busy = true;
    this.error = undefined;
    try {
      await operation();
    } catch (error) {
      this.error = error?.body?.message || error?.message || 'Demo Harness operation failed.';
    } finally {
      this.busy = false;
    }
  }

  get readinessClass() {
    return this.readiness?.result === 'PASS' ? 'status pass' : 'status fail';
  }

  get readinessSummary() {
    return this.readiness?.summary || {};
  }

  get resetItems() {
    const labels = {
      accounts: 'Accounts',
      contacts: 'Contacts',
      cases: 'Cases',
      ledger: 'Ledger Rows',
      staging: 'Staging Rows',
      links: 'Case Links',
      health: 'Health Rows'
    };
    return Object.keys(this.resetResult || {}).map((name) => ({
      name,
      label: labels[name] || name,
      value: this.resetResult[name]
    }));
  }
}
