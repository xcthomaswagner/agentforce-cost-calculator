@IsTest
private class XC_AFCC_AgentforceCaseLookupV2ActionTest {
    @IsTest
    static void returnsCaseStatusDetails() {
        Account account = new Account(Name = 'AFCC Agentforce Test Account');
        insert account;
        Contact contact = new Contact(
            FirstName = 'AFCC',
            LastName = 'Tester',
            Email = 'afcc-agentforce-test@example.invalid',
            AccountId = account.Id
        );
        insert contact;
        Case c = new Case(
            Subject = 'AFCC Agentforce lookup test',
            Status = 'New',
            Priority = 'High',
            AccountId = account.Id,
            ContactId = contact.Id
        );
        insert c;

        c = [SELECT CaseNumber FROM Case WHERE Id = :c.Id];
        XC_AFCC_AgentforceCaseLookupRequest request = new XC_AFCC_AgentforceCaseLookupRequest();
        request.caseNumber = c.CaseNumber;

        Test.startTest();
        List<XC_AFCC_AgentforceCaseLookupResponse> responses =
            XC_AFCC_AgentforceCaseLookupV2Action.lookupCases(new List<XC_AFCC_AgentforceCaseLookupRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].found);
        System.assertEquals(c.CaseNumber, responses[0].caseNumber);
        System.assertEquals('New', responses[0].status);
        System.assertEquals('High', responses[0].priority);
        System.assertEquals('AFCC Agentforce Test Account', responses[0].accountName);
        System.assertEquals('AFCC Tester', responses[0].contactName);
    }
}
