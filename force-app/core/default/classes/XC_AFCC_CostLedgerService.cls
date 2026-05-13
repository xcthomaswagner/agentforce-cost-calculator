public with sharing class XC_AFCC_CostLedgerService {
    public class ProcessResult {
        @AuraEnabled public Integer processedCount = 0;
        @AuraEnabled public Integer skippedCount = 0;
        @AuraEnabled public Integer errorCount = 0;
    }

    public static ProcessResult processPendingStaging() {
        return processStaging([
            SELECT Id, XC_AFCC_Source_System__c, XC_AFCC_Source_Record_Id__c, XC_AFCC_Billing_Model__c,
                   XC_AFCC_Usage_Timestamp__c, XC_AFCC_Case_Id_Text__c, XC_AFCC_Case_Number__c,
                   XC_AFCC_Conversation_Id__c, XC_AFCC_Messaging_Session_Id__c, XC_AFCC_Agent_Name__c,
                   XC_AFCC_Agent_Version__c, XC_AFCC_Action_Name__c, XC_AFCC_Topic__c, XC_AFCC_Channel__c,
                   XC_AFCC_Queue_Name__c, XC_AFCC_Credits_Used__c, XC_AFCC_Conversations_Used__c,
                   XC_AFCC_Action_Count__c, XC_AFCC_Case_Outcome__c, XC_AFCC_Data_Set_Type__c,
                   XC_AFCC_Processing_Status__c, XC_AFCC_Raw_Payload__c
            FROM XC_AFCC_Usage_Staging__c
            WHERE XC_AFCC_Processing_Status__c = 'PENDING'
            LIMIT 10000
        ]);
    }

    public static ProcessResult processStaging(List<XC_AFCC_Usage_Staging__c> rows) {
        ProcessResult result = new ProcessResult();
        if (rows == null || rows.isEmpty()) {
            return result;
        }

        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        Map<String, Case> casesByNumber = new Map<String, Case>();
        Set<String> caseNumbers = new Set<String>();
        for (XC_AFCC_Usage_Staging__c row : rows) {
            if (!String.isBlank(row.XC_AFCC_Case_Number__c)) {
                caseNumbers.add(row.XC_AFCC_Case_Number__c);
            }
        }
        if (!caseNumbers.isEmpty()) {
            for (Case c : [SELECT Id, CaseNumber, AccountId, ContactId, OwnerId, Status FROM Case WHERE CaseNumber IN :caseNumbers]) {
                casesByNumber.put(c.CaseNumber, c);
            }
        }

        List<XC_AFCC_Cost_Ledger__c> ledgerRows = new List<XC_AFCC_Cost_Ledger__c>();
        for (XC_AFCC_Usage_Staging__c row : rows) {
            try {
                String sourceId = String.isBlank(row.XC_AFCC_Source_Record_Id__c) ? String.valueOf(row.Id) : row.XC_AFCC_Source_Record_Id__c;
                XC_AFCC_CostCalculationService.CalculationResult calc = XC_AFCC_CostCalculationService.calculate(
                    row.XC_AFCC_Billing_Model__c,
                    row.XC_AFCC_Credits_Used__c,
                    row.XC_AFCC_Conversations_Used__c,
                    config,
                    row.XC_AFCC_Source_System__c
                );
                XC_AFCC_Cost_Ledger__c ledger = new XC_AFCC_Cost_Ledger__c();
                ledger.XC_AFCC_Org_Id__c = UserInfo.getOrganizationId();
                ledger.XC_AFCC_Billing_Model__c = calc.billingModel;
                ledger.XC_AFCC_Source_System__c = row.XC_AFCC_Source_System__c;
                ledger.XC_AFCC_Source_Record_Id__c = sourceId;
                ledger.XC_AFCC_Source_Staging_Record__c = row.Id;
                Case linkedCase = casesByNumber.get(row.XC_AFCC_Case_Number__c);
                if (linkedCase != null) {
                    ledger.XC_AFCC_Case__c = linkedCase.Id;
                    ledger.XC_AFCC_Case_Number__c = linkedCase.CaseNumber;
                    ledger.XC_AFCC_Account_Id__c = linkedCase.AccountId;
                    ledger.XC_AFCC_Contact_Id__c = linkedCase.ContactId;
                    ledger.XC_AFCC_Case_Owner_Id__c = linkedCase.OwnerId;
                    ledger.XC_AFCC_Case_Status__c = linkedCase.Status;
                    ledger.XC_AFCC_Allocation_Method__c = 'PRIMARY_CASE';
                    ledger.XC_AFCC_Confidence_Level__c = 'HIGH';
                } else {
                    ledger.XC_AFCC_Case_Number__c = row.XC_AFCC_Case_Number__c;
                    ledger.XC_AFCC_Allocation_Method__c = 'NONE';
                    ledger.XC_AFCC_Confidence_Level__c = 'LOW';
                }
                ledger.XC_AFCC_Conversation_Id__c = row.XC_AFCC_Conversation_Id__c;
                ledger.XC_AFCC_Messaging_Session_Id__c = row.XC_AFCC_Messaging_Session_Id__c;
                ledger.XC_AFCC_Agent_Name__c = row.XC_AFCC_Agent_Name__c;
                ledger.XC_AFCC_Agent_Version__c = row.XC_AFCC_Agent_Version__c;
                ledger.XC_AFCC_Action_Name__c = row.XC_AFCC_Action_Name__c;
                ledger.XC_AFCC_Topic__c = row.XC_AFCC_Topic__c;
                ledger.XC_AFCC_Channel__c = normalizeChannel(row.XC_AFCC_Channel__c);
                ledger.XC_AFCC_Queue_Name__c = row.XC_AFCC_Queue_Name__c;
                ledger.XC_AFCC_Case_Outcome__c = row.XC_AFCC_Case_Outcome__c;
                ledger.XC_AFCC_Usage_Timestamp__c = row.XC_AFCC_Usage_Timestamp__c;
                ledger.XC_AFCC_Usage_Date__c = row.XC_AFCC_Usage_Timestamp__c == null ? null : Date.newInstance(row.XC_AFCC_Usage_Timestamp__c.year(), row.XC_AFCC_Usage_Timestamp__c.month(), row.XC_AFCC_Usage_Timestamp__c.day());
                ledger.XC_AFCC_Credits_Used__c = row.XC_AFCC_Credits_Used__c;
                ledger.XC_AFCC_Conversations_Used__c = row.XC_AFCC_Conversations_Used__c;
                ledger.XC_AFCC_Action_Count__c = row.XC_AFCC_Action_Count__c;
                ledger.XC_AFCC_Contract_Credit_Rate__c = calc.billingModel == 'FLEX_CREDITS' ? calc.rateUsed : null;
                ledger.XC_AFCC_Contract_Conversation_Rate__c = calc.billingModel == 'CONVERSATIONS' ? calc.rateUsed : null;
                ledger.XC_AFCC_Allocated_Cost__c = calc.allocatedCost;
                ledger.XC_AFCC_Calculation_Basis__c = calc.calculationBasis;
                ledger.XC_AFCC_Data_Set_Type__c = row.XC_AFCC_Data_Set_Type__c;
                ledger.XC_AFCC_Raw_Payload__c = row.XC_AFCC_Raw_Payload__c;
                ledger.XC_AFCC_Deterministic_Key__c = sourceId;
                ledgerRows.add(ledger);
                row.XC_AFCC_Processing_Status__c = 'PROCESSED';
                row.XC_AFCC_Processing_Error__c = null;
                result.processedCount++;
            } catch (Exception ex) {
                row.XC_AFCC_Processing_Status__c = 'FAILED';
                row.XC_AFCC_Processing_Error__c = ex.getMessage();
                result.errorCount++;
            }
        }
        if (!ledgerRows.isEmpty()) {
            upsert ledgerRows XC_AFCC_Deterministic_Key__c;
        }
        update rows;
        return result;
    }

    private static String normalizeChannel(String value) {
        Set<String> allowed = new Set<String>{'Web','Chat','Email','Voice','Messaging','Other'};
        return allowed.contains(value) ? value : 'Other';
    }
}
