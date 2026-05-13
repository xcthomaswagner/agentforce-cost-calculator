public with sharing class XC_AFCC_DemoReadinessService {
    public class ReadinessResult {
        @AuraEnabled public String result;
        @AuraEnabled public String scenario;
        @AuraEnabled public List<XC_AFCC_DataHealthService.CheckResult> checks = new List<XC_AFCC_DataHealthService.CheckResult>();
        @AuraEnabled public Map<String, Object> summary = new Map<String, Object>();
    }

    @AuraEnabled(cacheable=false)
    public static ReadinessResult validateCurrentScenario() {
        XC_AFCC_DemoGuardService.assertCanRun();
        String scenarioName = currentScenario();
        XC_AFCC_DemoScenarioService.Scenario scenario = XC_AFCC_DemoScenarioService.loadScenario(scenarioName, 'small');
        ReadinessResult r = new ReadinessResult();
        r.scenario = scenarioName;

        Integer cases = [SELECT COUNT() FROM Case WHERE Subject LIKE 'XC AFCC Synthetic Case%'];
        Integer ledgerRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'];
        Integer deferredRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case_Outcome__c = 'DEFERRED'];
        Integer unallocatedRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case__c = null];
        AggregateResult totals = [SELECT SUM(XC_AFCC_Credits_Used__c) credits, SUM(XC_AFCC_Allocated_Cost__c) cost FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'];
        Decimal credits = (Decimal) totals.get('credits');
        Decimal cost = (Decimal) totals.get('cost');
        Decimal unallocatedPct = ledgerRows == 0 ? 0 : (Decimal.valueOf(unallocatedRows) * 100 / ledgerRows).setScale(2);

        r.summary.put('cases', cases);
        r.summary.put('ledgerRows', ledgerRows);
        r.summary.put('deferredCases', deferredRows);
        r.summary.put('allocatedCost', cost);
        r.summary.put('totalCredits', credits);
        r.summary.put('unallocatedUsagePercent', unallocatedPct);

        addCheck(r, 'Core data exists', cases > 0, String.valueOf(cases), cases);
        addCheck(r, 'Ledger rows exist', ledgerRows > 0, String.valueOf(ledgerRows), ledgerRows);
        addCheck(r, 'Deferred cases exist', deferredRows > 0, String.valueOf(deferredRows), deferredRows);
        if (scenarioName == 'known-answer-small') {
            addCheck(r, 'Known-answer credits', credits == 100, String.valueOf(credits), credits == null ? 0 : credits);
            addCheck(r, 'Known-answer cost', cost == 0.50, String.valueOf(cost), cost == null ? 0 : cost);
        }
        r.result = 'PASS';
        for (XC_AFCC_DataHealthService.CheckResult c : r.checks) {
            if (c.status != 'PASS') {
                r.result = 'FAIL';
                break;
            }
        }
        return r;
    }

    private static String currentScenario() {
        List<AggregateResult> rows = [
            SELECT XC_AFCC_Demo_Scenario_Id__c scenarioName, COUNT(Id) rows
            FROM XC_AFCC_Cost_Ledger__c
            WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'
            GROUP BY XC_AFCC_Demo_Scenario_Id__c
            ORDER BY COUNT(Id) DESC
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].get('scenarioName') == null) {
            return 'deferred-hotspot';
        }
        return String.valueOf(rows[0].get('scenarioName'));
    }

    private static void addCheck(ReadinessResult r, String name, Boolean pass, String detail, Decimal value) {
        r.checks.add(new XC_AFCC_DataHealthService.CheckResult(name, pass ? 'PASS' : 'FAIL', detail, value));
    }
}
