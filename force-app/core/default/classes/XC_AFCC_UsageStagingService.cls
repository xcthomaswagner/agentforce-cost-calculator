public with sharing class XC_AFCC_UsageStagingService {
    @AuraEnabled(cacheable=true)
    public static List<XC_AFCC_Usage_Staging__c> recentRows(Integer limitSize) {
        Integer rowLimit = limitSize == null || limitSize <= 0 ? 50 : Math.min(limitSize, 200);
        return [
            SELECT Id, Name, XC_AFCC_Source_System__c, XC_AFCC_Source_Record_Id__c, XC_AFCC_Billing_Model__c,
                   XC_AFCC_Usage_Timestamp__c, XC_AFCC_Case_Number__c, XC_AFCC_Conversation_Id__c,
                   XC_AFCC_Agent_Name__c, XC_AFCC_Action_Name__c, XC_AFCC_Credits_Used__c,
                   XC_AFCC_Conversations_Used__c, XC_AFCC_Processing_Status__c, XC_AFCC_Processing_Error__c
            FROM XC_AFCC_Usage_Staging__c
            ORDER BY CreatedDate DESC
            LIMIT :rowLimit
        ];
    }
}
