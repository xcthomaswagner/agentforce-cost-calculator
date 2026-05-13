public with sharing class XC_AFCC_SetupController {
    @AuraEnabled(cacheable=false)
    public static XC_AFCC_Org_Config__c ensureDefaultConfig() {
        List<XC_AFCC_Org_Config__c> existing = [
            SELECT Id, Name, XC_AFCC_Org_Id__c, XC_AFCC_Org_Name__c, XC_AFCC_Is_Sandbox__c,
                   XC_AFCC_Install_Mode__c, XC_AFCC_Billing_Model__c,
                   XC_AFCC_Contract_Credit_Rate__c, XC_AFCC_Contract_Conversation_Rate__c,
                   XC_AFCC_Default_Credit_Rate__c, XC_AFCC_Default_Conversation_Rate__c,
                   XC_AFCC_Allocation_Method__c, XC_AFCC_Csv_Import_Enabled__c,
                   XC_AFCC_Demo_Override_Enabled__c, XC_AFCC_Demo_Override_Expires_On__c,
                   XC_AFCC_Demo_Override_Reason__c
            FROM XC_AFCC_Org_Config__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }

        XC_AFCC_EnvironmentService.EnvironmentInfo env = XC_AFCC_EnvironmentService.getEnvironmentInfo();
        XC_AFCC_Org_Config__c config = new XC_AFCC_Org_Config__c();
        config.XC_AFCC_Org_Id__c = env.orgId;
        config.XC_AFCC_Org_Name__c = env.orgName;
        config.XC_AFCC_Is_Sandbox__c = env.isSandbox;
        config.XC_AFCC_Install_Mode__c = env.isProduction ? 'PRODUCTION' : 'SANDBOX';
        config.XC_AFCC_Billing_Model__c = 'FLEX_CREDITS';
        config.XC_AFCC_Contract_Credit_Rate__c = 0.005;
        config.XC_AFCC_Contract_Conversation_Rate__c = 2.00;
        config.XC_AFCC_Default_Credit_Rate__c = 0.005;
        config.XC_AFCC_Default_Conversation_Rate__c = 2.00;
        config.XC_AFCC_Allocation_Method__c = 'PRIMARY_CASE';
        config.XC_AFCC_Csv_Import_Enabled__c = false;
        insert config;
        XC_AFCC_AuditLogService.log('DEFAULT_CONFIG_CREATED', null, JSON.serialize(config), 'Default configuration created.');
        return config;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSetupState() {
        Map<String, Object> state = new Map<String, Object>();
        List<XC_AFCC_Org_Config__c> configs = [
            SELECT Id, Name, XC_AFCC_Org_Id__c, XC_AFCC_Org_Name__c, XC_AFCC_Is_Sandbox__c,
                   XC_AFCC_Install_Mode__c, XC_AFCC_Billing_Model__c,
                   XC_AFCC_Contract_Credit_Rate__c, XC_AFCC_Contract_Conversation_Rate__c,
                   XC_AFCC_Default_Credit_Rate__c, XC_AFCC_Default_Conversation_Rate__c,
                   XC_AFCC_Allocation_Method__c, XC_AFCC_Csv_Import_Enabled__c,
                   XC_AFCC_Demo_Override_Enabled__c, XC_AFCC_Demo_Override_Expires_On__c,
                   XC_AFCC_Demo_Override_Reason__c
            FROM XC_AFCC_Org_Config__c
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        state.put('environment', XC_AFCC_EnvironmentService.getEnvironmentInfo());
        state.put('configCount', [SELECT COUNT() FROM XC_AFCC_Org_Config__c]);
        state.put('config', configs.isEmpty() ? null : configs[0]);
        state.put('csvImportAvailable', false);
        state.put('csvImportFallbackOnly', true);
        return state;
    }
}
