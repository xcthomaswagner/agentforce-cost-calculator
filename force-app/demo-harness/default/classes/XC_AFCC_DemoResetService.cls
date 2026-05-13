public with sharing class XC_AFCC_DemoResetService {
    @AuraEnabled
    public static Map<String, Integer> resetSyntheticData() {
        XC_AFCC_DemoGuardService.assertCanRun();
        Map<String, Integer> counts = new Map<String, Integer>();

        List<XC_AFCC_Cost_Ledger__c> ledger = [SELECT Id FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Data_Set_Type__c = 'SYNTHETIC' OR XC_AFCC_Source_System__c = 'SYNTHETIC'];
        counts.put('ledger', ledger.size());
        delete ledger;

        List<XC_AFCC_Usage_Staging__c> staging = [SELECT Id FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Data_Set_Type__c = 'SYNTHETIC' OR XC_AFCC_Source_System__c = 'SYNTHETIC'];
        counts.put('staging', staging.size());
        delete staging;

        List<XC_AFCC_Case_Conversation_Link__c> links = [SELECT Id FROM XC_AFCC_Case_Conversation_Link__c WHERE XC_AFCC_Data_Set_Type__c = 'SYNTHETIC'];
        counts.put('links', links.size());
        delete links;

        List<Case> cases = [SELECT Id FROM Case WHERE Subject LIKE 'XC AFCC Synthetic Case%'];
        counts.put('cases', cases.size());
        delete cases;

        List<Contact> contacts = [SELECT Id FROM Contact WHERE LastName LIKE 'AFCC Contact%'];
        counts.put('contacts', contacts.size());
        delete contacts;

        List<Account> accounts = [SELECT Id FROM Account WHERE Name LIKE 'XC AFCC Synthetic Account%'];
        counts.put('accounts', accounts.size());
        delete accounts;

        List<XC_AFCC_Data_Health_Check__c> health = [SELECT Id FROM XC_AFCC_Data_Health_Check__c WHERE XC_AFCC_Data_Set_Type__c = 'SYNTHETIC'];
        counts.put('health', health.size());
        delete health;
        return counts;
    }
}
