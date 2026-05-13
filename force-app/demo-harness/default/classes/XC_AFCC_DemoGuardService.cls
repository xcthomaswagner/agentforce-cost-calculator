public with sharing class XC_AFCC_DemoGuardService {
    @TestVisible private static Boolean bypassForTests = false;

    public class GuardResult {
        @AuraEnabled public Boolean allowed;
        @AuraEnabled public String reason;
    }

    @AuraEnabled(cacheable=true)
    public static GuardResult checkAccess() {
        GuardResult result = new GuardResult();
        try {
            assertCanRun();
            result.allowed = true;
            result.reason = 'Allowed';
        } catch (Exception ex) {
            result.allowed = false;
            result.reason = ex.getMessage();
        }
        return result;
    }

    public static void assertCanRun() {
        if (bypassForTests) {
            return;
        }
        if (!FeatureManagement.checkPermission('XC_AFCC_Access_Demo_Harness')) {
            throw new SecurityException('Current user does not have access to the Demo Harness.');
        }
        XC_AFCC_EnvironmentService.EnvironmentInfo env = XC_AFCC_EnvironmentService.getEnvironmentInfo();
        if (env.isProduction) {
            throw new SecurityException('Demo Harness cannot run in production.');
        }
        if (env.organizationType != 'Sandbox') {
            return;
        }
        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        if (config.XC_AFCC_Demo_Override_Enabled__c == true &&
            config.XC_AFCC_Demo_Override_Expires_On__c != null &&
            config.XC_AFCC_Demo_Override_Expires_On__c >= Date.today()) {
            return;
        }
        throw new SecurityException('Demo Harness requires an explicit, unexpired sandbox override outside scratch orgs.');
    }
}
