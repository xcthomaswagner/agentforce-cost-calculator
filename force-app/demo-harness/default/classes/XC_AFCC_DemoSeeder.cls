public with sharing class XC_AFCC_DemoSeeder {
    @AuraEnabled
    public static XC_AFCC_SyntheticDataFactory.SeedResult seed(String scenarioName, String volume) {
        XC_AFCC_DemoScenarioService.Scenario scenario = XC_AFCC_DemoScenarioService.loadScenario(scenarioName, volume);
        return XC_AFCC_SyntheticDataFactory.seed(scenario);
    }
}
