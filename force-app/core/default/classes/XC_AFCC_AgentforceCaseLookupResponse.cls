@JsonAccess(serializable='always' deserializable='always')
global class XC_AFCC_AgentforceCaseLookupResponse {
    @AuraEnabled
    @InvocableVariable(label='Found')
    global Boolean found;

    @AuraEnabled
    @InvocableVariable(label='Case Number')
    global String caseNumber;

    @AuraEnabled
    @InvocableVariable(label='Subject')
    global String subject;

    @AuraEnabled
    @InvocableVariable(label='Status')
    global String status;

    @AuraEnabled
    @InvocableVariable(label='Priority')
    global String priority;

    @AuraEnabled
    @InvocableVariable(label='Account Name')
    global String accountName;

    @AuraEnabled
    @InvocableVariable(label='Contact Name')
    global String contactName;

    @AuraEnabled
    @InvocableVariable(label='Contact Email')
    global String contactEmail;

    @AuraEnabled
    @InvocableVariable(label='Next Step')
    global String nextStep;

    @AuraEnabled
    @InvocableVariable(label='Summary')
    global String summary;
}
