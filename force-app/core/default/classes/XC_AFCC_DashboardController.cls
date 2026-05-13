public with sharing class XC_AFCC_DashboardController {
    public class DashboardSummary {
        @AuraEnabled public Integer ledgerRows;
        @AuraEnabled public Integer linkedCases;
        @AuraEnabled public Decimal allocatedCost;
        @AuraEnabled public Decimal credits;
        @AuraEnabled public Decimal conversations;
        @AuraEnabled public Decimal unallocatedUsagePercent;
        @AuraEnabled public List<XC_AFCC_ReportQueryService.ReportRow> costByQueue;
        @AuraEnabled public XC_AFCC_DataHealthService.HealthSummary health;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardSummary getSummary() {
        DashboardSummary summary = new DashboardSummary();
        summary.ledgerRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c];
        summary.linkedCases = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Case__c != null];
        AggregateResult totals = [
            SELECT SUM(XC_AFCC_Allocated_Cost__c) cost, SUM(XC_AFCC_Credits_Used__c) credits,
                   SUM(XC_AFCC_Conversations_Used__c) conversations
            FROM XC_AFCC_Cost_Ledger__c
        ];
        summary.allocatedCost = (Decimal) totals.get('cost');
        summary.credits = (Decimal) totals.get('credits');
        summary.conversations = (Decimal) totals.get('conversations');
        Integer unallocated = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Case__c = null];
        summary.unallocatedUsagePercent = summary.ledgerRows == 0 ? 0 : (Decimal.valueOf(unallocated) * 100 / summary.ledgerRows).setScale(2);
        summary.costByQueue = XC_AFCC_ReportQueryService.groupedReport('queue');
        summary.health = XC_AFCC_DataHealthService.getLatestSummary();
        return summary;
    }
}
