@IsTest
private class XC_AFCC_AgentforceCaseLookupActionTest {
    @IsTest
    static void returnsCaseStatusDetails() {
        Account account = new Account(Name = 'Agentforce Lookup Account');
        insert account;
        Contact contact = new Contact(LastName = 'Lookup', Email = 'lookup@example.invalid', AccountId = account.Id);
        insert contact;
        Case c = new Case(
            Subject = 'Order status',
            Status = 'New',
            Priority = 'High',
            AccountId = account.Id,
            ContactId = contact.Id
        );
        insert c;
        c = [SELECT CaseNumber FROM Case WHERE Id = :c.Id];

        XC_AFCC_AgentforceCaseLookupAction.Request request = new XC_AFCC_AgentforceCaseLookupAction.Request();
        request.caseNumber = c.CaseNumber;

        Test.startTest();
        List<XC_AFCC_AgentforceCaseLookupAction.Response> responses =
            XC_AFCC_AgentforceCaseLookupAction.lookupCases(new List<XC_AFCC_AgentforceCaseLookupAction.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].found);
        System.assertEquals('Order status', responses[0].subject);
        System.assertEquals('High', responses[0].priority);
        System.assert(responses[0].summary.contains(c.CaseNumber));
    }

    @IsTest
    static void returnsHelpfulMiss() {
        XC_AFCC_AgentforceCaseLookupAction.Request request = new XC_AFCC_AgentforceCaseLookupAction.Request();
        request.caseNumber = '99999999';

        List<XC_AFCC_AgentforceCaseLookupAction.Response> responses =
            XC_AFCC_AgentforceCaseLookupAction.lookupCases(new List<XC_AFCC_AgentforceCaseLookupAction.Request>{ request });

        System.assertEquals(false, responses[0].found);
        System.assert(responses[0].nextStep.contains('confirm the case number'));
    }
}
