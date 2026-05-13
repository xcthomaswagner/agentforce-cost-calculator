public with sharing class XC_AFCC_CaseCostExplainService {
    public class CaseExplanation {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Integer ledgerRows;
        @AuraEnabled public Decimal allocatedCost;
        @AuraEnabled public Decimal credits;
        @AuraEnabled public Decimal conversations;
        @AuraEnabled public List<XC_AFCC_Cost_Ledger__c> rows;
    }

    @AuraEnabled(cacheable=true)
    public static CaseExplanation explainCase(Id caseId, String caseNumber) {
        List<XC_AFCC_Cost_Ledger__c> ledger = new List<XC_AFCC_Cost_Ledger__c>();
        if (caseId != null) {
            ledger = [
                SELECT Id, Name, XC_AFCC_Case__c, XC_AFCC_Case_Number__c, XC_AFCC_Conversation_Id__c,
                       XC_AFCC_Agent_Name__c, XC_AFCC_Action_Name__c, XC_AFCC_Topic__c,
                       XC_AFCC_Queue_Name__c, XC_AFCC_Case_Outcome__c, XC_AFCC_Credits_Used__c,
                       XC_AFCC_Conversations_Used__c, XC_AFCC_Allocated_Cost__c,
                       XC_AFCC_Calculation_Basis__c, XC_AFCC_Allocation_Method__c,
                       XC_AFCC_Usage_Timestamp__c
                FROM XC_AFCC_Cost_Ledger__c
                WHERE XC_AFCC_Case__c = :caseId
                ORDER BY XC_AFCC_Usage_Timestamp__c ASC
                LIMIT 200
            ];
        } else if (!String.isBlank(caseNumber)) {
            ledger = [
                SELECT Id, Name, XC_AFCC_Case__c, XC_AFCC_Case_Number__c, XC_AFCC_Conversation_Id__c,
                       XC_AFCC_Agent_Name__c, XC_AFCC_Action_Name__c, XC_AFCC_Topic__c,
                       XC_AFCC_Queue_Name__c, XC_AFCC_Case_Outcome__c, XC_AFCC_Credits_Used__c,
                       XC_AFCC_Conversations_Used__c, XC_AFCC_Allocated_Cost__c,
                       XC_AFCC_Calculation_Basis__c, XC_AFCC_Allocation_Method__c,
                       XC_AFCC_Usage_Timestamp__c
                FROM XC_AFCC_Cost_Ledger__c
                WHERE XC_AFCC_Case_Number__c = :caseNumber
                ORDER BY XC_AFCC_Usage_Timestamp__c ASC
                LIMIT 200
            ];
        }
        CaseExplanation ex = new CaseExplanation();
        ex.caseId = caseId;
        ex.caseNumber = caseNumber;
        ex.ledgerRows = ledger.size();
        ex.allocatedCost = 0;
        ex.credits = 0;
        ex.conversations = 0;
        ex.rows = ledger;
        for (XC_AFCC_Cost_Ledger__c row : ledger) {
            ex.allocatedCost += row.XC_AFCC_Allocated_Cost__c == null ? 0 : row.XC_AFCC_Allocated_Cost__c;
            ex.credits += row.XC_AFCC_Credits_Used__c == null ? 0 : row.XC_AFCC_Credits_Used__c;
            ex.conversations += row.XC_AFCC_Conversations_Used__c == null ? 0 : row.XC_AFCC_Conversations_Used__c;
            if (ex.caseNumber == null) {
                ex.caseNumber = row.XC_AFCC_Case_Number__c;
            }
        }
        return ex;
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> recentCasesWithCosts() {
        Set<Id> caseIds = new Set<Id>();
        for (XC_AFCC_Cost_Ledger__c row : [
            SELECT XC_AFCC_Case__c
            FROM XC_AFCC_Cost_Ledger__c
            WHERE XC_AFCC_Case__c != null
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            caseIds.add(row.XC_AFCC_Case__c);
        }
        if (caseIds.isEmpty()) {
            return new List<Case>();
        }
        return [SELECT Id, CaseNumber, Subject, Status, Priority FROM Case WHERE Id IN :caseIds ORDER BY CreatedDate DESC LIMIT 100];
    }
}
