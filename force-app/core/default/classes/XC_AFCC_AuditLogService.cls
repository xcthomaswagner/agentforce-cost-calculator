public with sharing class XC_AFCC_AuditLogService {
    public static void log(String action, String oldValue, String newValue, String detail) {
        XC_AFCC_Audit_Log__c row = new XC_AFCC_Audit_Log__c();
        row.XC_AFCC_Action__c = action;
        row.XC_AFCC_User__c = UserInfo.getUserId();
        row.XC_AFCC_Timestamp__c = System.now();
        row.XC_AFCC_Old_Value__c = oldValue;
        row.XC_AFCC_New_Value__c = newValue;
        row.XC_AFCC_Environment_Mode__c = XC_AFCC_EnvironmentService.isProduction() ? 'PRODUCTION' : 'NON_PRODUCTION';
        row.XC_AFCC_Detail__c = detail;
        insert row;
    }
}
