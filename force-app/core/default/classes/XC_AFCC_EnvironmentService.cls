public with sharing class XC_AFCC_EnvironmentService {
    public class EnvironmentInfo {
        @AuraEnabled public String orgId;
        @AuraEnabled public String orgName;
        @AuraEnabled public Boolean isSandbox;
        @AuraEnabled public String organizationType;
        @AuraEnabled public String instanceName;
        @AuraEnabled public Boolean isProduction;
    }

    @AuraEnabled(cacheable=true)
    public static EnvironmentInfo getEnvironmentInfo() {
        Organization orgInfo = [
            SELECT Id, Name, IsSandbox, OrganizationType, InstanceName
            FROM Organization
            LIMIT 1
        ];
        EnvironmentInfo info = new EnvironmentInfo();
        info.orgId = orgInfo.Id;
        info.orgName = orgInfo.Name;
        info.isSandbox = orgInfo.IsSandbox;
        info.organizationType = orgInfo.OrganizationType;
        info.instanceName = orgInfo.InstanceName;
        info.isProduction = isProductionOrg(orgInfo);
        return info;
    }

    public static Boolean isProduction() {
        return getEnvironmentInfo().isProduction;
    }

    public static Boolean isNonProduction() {
        return !isProduction();
    }

    private static Boolean isProductionOrg(Organization orgInfo) {
        return orgInfo.IsSandbox == false && orgInfo.OrganizationType == 'Production';
    }
}
