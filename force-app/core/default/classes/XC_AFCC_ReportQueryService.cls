public with sharing class XC_AFCC_ReportQueryService {
    public class ReportRow {
        @AuraEnabled public String groupValue;
        @AuraEnabled public Integer rowCount;
        @AuraEnabled public Decimal credits;
        @AuraEnabled public Decimal conversations;
        @AuraEnabled public Decimal allocatedCost;
    }

    @AuraEnabled(cacheable=true)
    public static List<ReportRow> groupedReport(String groupByField) {
        Map<String, String> allowed = new Map<String, String>{
            'queue' => 'XC_AFCC_Queue_Name__c',
            'agent' => 'XC_AFCC_Agent_Name__c',
            'topic' => 'XC_AFCC_Topic__c',
            'outcome' => 'XC_AFCC_Case_Outcome__c',
            'channel' => 'XC_AFCC_Channel__c',
            'date' => 'XC_AFCC_Usage_Date__c'
        };
        String fieldName = allowed.get(String.isBlank(groupByField) ? 'queue' : groupByField.toLowerCase());
        if (fieldName == null) {
            throw new AuraHandledException('Unsupported group-by field.');
        }
        String soql = 'SELECT ' + fieldName + ' groupValue, COUNT(Id) rows, SUM(XC_AFCC_Credits_Used__c) credits, ' +
            'SUM(XC_AFCC_Conversations_Used__c) conversations, SUM(XC_AFCC_Allocated_Cost__c) cost ' +
            'FROM XC_AFCC_Cost_Ledger__c GROUP BY ' + fieldName + ' ORDER BY SUM(XC_AFCC_Allocated_Cost__c) DESC NULLS LAST LIMIT 200';
        List<ReportRow> reportRows = new List<ReportRow>();
        for (AggregateResult ar : Database.query(soql)) {
            ReportRow row = new ReportRow();
            row.groupValue = String.valueOf(ar.get('groupValue'));
            row.rowCount = Integer.valueOf(ar.get('rows'));
            row.credits = (Decimal) ar.get('credits');
            row.conversations = (Decimal) ar.get('conversations');
            row.allocatedCost = (Decimal) ar.get('cost');
            reportRows.add(row);
        }
        return reportRows;
    }
}
