@IsTest
private class XC_AFCC_CaseStatusTextActionTest {
    @IsTest
    static void returnsPlainTextStatus() {
        Account account = new Account(Name = 'AFCC Text Action Account');
        insert account;
        Contact contact = new Contact(
            FirstName = 'AFCC',
            LastName = 'Text',
            Email = 'afcc-text@example.invalid',
            AccountId = account.Id
        );
        insert contact;
        Case c = new Case(
            Subject = 'AFCC text lookup test',
            Status = 'New',
            Priority = 'High',
            AccountId = account.Id,
            ContactId = contact.Id
        );
        insert c;

        c = [SELECT CaseNumber FROM Case WHERE Id = :c.Id];

        Test.startTest();
        List<String> summaries = XC_AFCC_AgentforceCaseStatusTextAction.lookupCaseStatus(new List<String>{ c.CaseNumber });
        Test.stopTest();

        System.assertEquals(1, summaries.size());
        System.assert(summaries[0].contains('Case ' + c.CaseNumber), summaries[0]);
        System.assert(summaries[0].contains('status: New'), summaries[0]);
        System.assert(summaries[0].contains('priority: High'), summaries[0]);
        System.assert(summaries[0].contains('AFCC Text Action Account'), summaries[0]);
    }
}
