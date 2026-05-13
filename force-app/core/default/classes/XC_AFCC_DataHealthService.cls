public with sharing class XC_AFCC_DataHealthService {
    public class HealthSummary {
        @AuraEnabled public String result;
        @AuraEnabled public Integer stagingRows;
        @AuraEnabled public Integer ledgerRows;
        @AuraEnabled public Integer failedRows;
        @AuraEnabled public Integer deferredCases;
        @AuraEnabled public Decimal totalCredits;
        @AuraEnabled public Decimal totalConversations;
        @AuraEnabled public Decimal totalAllocatedCost;
        @AuraEnabled public Decimal unallocatedUsagePercent;
        @AuraEnabled public Integer estimatedCostRows;
        @AuraEnabled public List<CheckResult> checks = new List<CheckResult>();
    }

    public class CheckResult {
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String detail;
        @AuraEnabled public Decimal value;
        public CheckResult(String name, String status, String detail, Decimal value) {
            this.name = name;
            this.status = status;
            this.detail = detail;
            this.value = value;
        }
    }

    @AuraEnabled
    public static HealthSummary runDataHealth() {
        HealthSummary summary = calculate();
        persist(summary, 'ALL');
        return summary;
    }

    @AuraEnabled(cacheable=false)
    public static HealthSummary validateSandboxReadiness() {
        XC_AFCC_SetupController.ensureDefaultConfig();
        HealthSummary summary = calculate();
        XC_AFCC_NativeUsageService.NativeReadiness readiness = XC_AFCC_NativeUsageService.getReadiness();
        summary.checks.add(new CheckResult('Native Source Readiness', readiness.result == 'MISSING_NATIVE_SOURCE' ? 'WARN' : 'PASS', displayValue(readiness.result), readiness.nativeSourceRows));
        if (summary.ledgerRows == 0) {
            summary.result = readiness.result;
            summary.checks.add(new CheckResult('Analysis Ready', 'WARN', 'Native Agentforce or Service Cloud data has not been synced yet.', 0));
        } else if (summary.result == 'PASS' || summary.result == 'WARN') {
            summary.checks.add(new CheckResult('Analysis Ready', 'PASS', 'Usage data is available.', 1));
        }
        persist(summary, 'LIVE');
        return summary;
    }

    @AuraEnabled(cacheable=true)
    public static HealthSummary getLatestSummary() {
        return calculate();
    }

    private static HealthSummary calculate() {
        HealthSummary s = new HealthSummary();
        s.stagingRows = [SELECT COUNT() FROM XC_AFCC_Usage_Staging__c];
        s.ledgerRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c];
        s.failedRows = [SELECT COUNT() FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Processing_Status__c = 'FAILED'];
        s.deferredCases = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Case_Outcome__c = 'DEFERRED'];
        s.estimatedCostRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Calculation_Basis__c = 'ESTIMATED'];
        AggregateResult totals = [
            SELECT SUM(XC_AFCC_Credits_Used__c) credits,
                   SUM(XC_AFCC_Conversations_Used__c) conversations,
                   SUM(XC_AFCC_Allocated_Cost__c) cost
            FROM XC_AFCC_Cost_Ledger__c
        ];
        s.totalCredits = (Decimal) totals.get('credits');
        s.totalConversations = (Decimal) totals.get('conversations');
        s.totalAllocatedCost = (Decimal) totals.get('cost');
        Integer unallocated = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Case__c = null];
        s.unallocatedUsagePercent = s.ledgerRows == 0 ? 0 : (Decimal.valueOf(unallocated) * 100 / s.ledgerRows).setScale(2);

        s.checks.add(new CheckResult('Staging rows', s.stagingRows > 0 ? 'PASS' : 'INFO', String.valueOf(s.stagingRows), s.stagingRows));
        s.checks.add(new CheckResult('Ledger rows', s.ledgerRows > 0 ? 'PASS' : 'WARN', String.valueOf(s.ledgerRows), s.ledgerRows));
        s.checks.add(new CheckResult('Failed staging rows', s.failedRows == 0 ? 'PASS' : 'FAIL', String.valueOf(s.failedRows), s.failedRows));
        s.checks.add(new CheckResult('Unallocated usage percent', s.unallocatedUsagePercent <= 15 ? 'PASS' : 'WARN', String.valueOf(s.unallocatedUsagePercent), s.unallocatedUsagePercent));
        s.checks.add(new CheckResult('Estimated-cost rows', s.estimatedCostRows == 0 ? 'PASS' : 'WARN', String.valueOf(s.estimatedCostRows), s.estimatedCostRows));

        s.result = 'PASS';
        for (CheckResult c : s.checks) {
            if (c.status == 'FAIL') {
                s.result = 'FAIL';
                break;
            }
            if (c.status == 'WARN' && s.result == 'PASS') {
                s.result = 'WARN';
            }
        }
        return s;
    }

    private static void persist(HealthSummary summary, String dataSetType) {
        List<XC_AFCC_Data_Health_Check__c> rows = new List<XC_AFCC_Data_Health_Check__c>();
        for (CheckResult check : summary.checks) {
            XC_AFCC_Data_Health_Check__c row = new XC_AFCC_Data_Health_Check__c();
            row.XC_AFCC_Check_Name__c = check.name;
            row.XC_AFCC_Status__c = check.status;
            row.XC_AFCC_Detail__c = check.detail;
            row.XC_AFCC_Record_Count__c = check.value;
            row.XC_AFCC_Warning_Level__c = check.status == 'FAIL' ? 'HIGH' : (check.status == 'WARN' ? 'MEDIUM' : 'NONE');
            row.XC_AFCC_Run_Timestamp__c = System.now();
            row.XC_AFCC_Data_Set_Type__c = dataSetType == 'IMPORTED' || dataSetType == 'LIVE' || dataSetType == 'SYNTHETIC' ? dataSetType : null;
            rows.add(row);
        }
        if (!rows.isEmpty()) {
            insert rows;
        }
    }

    private static String displayValue(String value) {
        if (value == 'ANALYSIS_READY') return 'Analysis Ready';
        if (value == 'NATIVE_READY') return 'Native Ready';
        if (value == 'READY_FOR_NATIVE_DATA') return 'Ready for Native Data';
        if (value == 'MISSING_NATIVE_SOURCE') return 'Missing Native Source';
        if (value == 'MISSING_SERVICE_CLOUD_DATA') return 'Missing Service Cloud Data';
        return value;
    }
}
