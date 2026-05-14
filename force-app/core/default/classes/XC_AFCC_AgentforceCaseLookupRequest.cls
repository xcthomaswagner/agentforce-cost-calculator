@JsonAccess(serializable='always' deserializable='always')
global class XC_AFCC_AgentforceCaseLookupRequest {
    @AuraEnabled
    @InvocableVariable(required=true label='Case Number' description='Salesforce case number provided by the customer.')
    global String caseNumber;
}
