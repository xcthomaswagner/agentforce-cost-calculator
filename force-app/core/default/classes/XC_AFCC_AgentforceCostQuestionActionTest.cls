@IsTest
private class XC_AFCC_AgentforceCostQuestionActionTest {
    @TestSetup
    static void setupData() {
        Account account = new Account(Name = 'Cost Question Account');
        insert account;
        Contact contact = new Contact(FirstName = 'Cost', LastName = 'Contact', Email = 'cost@example.com', AccountId = account.Id);
        insert contact;
        Case c = new Case(
            Subject = 'Cost question case',
            Origin = 'Web',
            Status = 'New',
            Priority = 'High',
            AccountId = account.Id,
            ContactId = contact.Id
        );
        insert c;
        c = [SELECT Id, CaseNumber FROM Case WHERE Id = :c.Id];

        Date lastMonth = Date.today().addMonths(-1);
        Date thisMonth = Date.today();
        insert new List<XC_AFCC_Cost_Ledger__c>{
            ledger('q-1', c, lastMonth, 'Billing Support', 'Agent One', 'Billing question', 'Chat', 'DEFERRED', 'ACTUAL', 10, 0, 0.10),
            ledger('q-2', c, lastMonth, 'Billing Support', 'Agent One', 'Billing question', 'Chat', 'DEFERRED', 'ACTUAL', 15, 0, 0.15),
            ledger('q-3', c, thisMonth, 'Order Support', 'Agent Two', 'Order status', 'Messaging', 'RESOLVED', 'ESTIMATED', 20, 0, 0.20),
            new XC_AFCC_Cost_Ledger__c(
                XC_AFCC_Source_System__c = 'LIVE',
                XC_AFCC_Source_Record_Id__c = 'q-4',
                XC_AFCC_Data_Set_Type__c = 'LIVE',
                XC_AFCC_Billing_Model__c = 'FLEX_CREDITS',
                XC_AFCC_Usage_Timestamp__c = System.now(),
                XC_AFCC_Usage_Date__c = thisMonth,
                XC_AFCC_Queue_Name__c = 'Product Help',
                XC_AFCC_Agent_Name__c = 'Agent Three',
                XC_AFCC_Topic__c = 'Technical troubleshooting',
                XC_AFCC_Channel__c = 'Messaging',
                XC_AFCC_Case_Outcome__c = 'UNKNOWN',
                XC_AFCC_Calculation_Basis__c = 'ACTUAL',
                XC_AFCC_Allocation_Method__c = 'NONE',
                XC_AFCC_Credits_Used__c = 5,
                XC_AFCC_Allocated_Cost__c = 0.05
            )
        };
    }

    @IsTest
    static void answersSupportedCostQuestions() {
        Case c = [SELECT CaseNumber FROM Case LIMIT 1];
        List<String> answers = XC_AFCC_AgentforceCostQuestionAction.answerCostQuestions(new List<String>{
            'What is total Agentforce cost?',
            'What did deferred cases cost by queue last month?',
            'What did case ' + c.CaseNumber + ' cost and why?',
            'How much usage is unallocated?',
            'How many rows have estimated cost?',
            'Which agent is most expensive?'
        });

        System.assertEquals(6, answers.size());
        System.assert(answers[0].contains('Total Agentforce cost'), answers[0]);
        System.assert(answers[1].contains('Billing Support'), answers[1]);
        System.assert(answers[2].contains('Case ' + c.CaseNumber), answers[2]);
        System.assert(answers[3].contains('Unallocated Agentforce usage'), answers[3]);
        System.assert(answers[4].contains('Estimated or incomplete Agentforce cost'), answers[4]);
        System.assert(answers[5].contains('Agent One') || answers[5].contains('Agent Two'), answers[5]);
    }

    private static XC_AFCC_Cost_Ledger__c ledger(
        String sourceRecordId,
        Case c,
        Date usageDate,
        String queueName,
        String agentName,
        String topic,
        String channel,
        String outcome,
        String basis,
        Decimal credits,
        Decimal conversations,
        Decimal cost
    ) {
        return new XC_AFCC_Cost_Ledger__c(
            XC_AFCC_Source_System__c = 'LIVE',
            XC_AFCC_Source_Record_Id__c = sourceRecordId,
            XC_AFCC_Data_Set_Type__c = 'LIVE',
            XC_AFCC_Billing_Model__c = 'FLEX_CREDITS',
            XC_AFCC_Usage_Timestamp__c = DateTime.newInstance(usageDate, Time.newInstance(12, 0, 0, 0)),
            XC_AFCC_Usage_Date__c = usageDate,
            XC_AFCC_Case__c = c.Id,
            XC_AFCC_Case_Number__c = c.CaseNumber,
            XC_AFCC_Queue_Name__c = queueName,
            XC_AFCC_Agent_Name__c = agentName,
            XC_AFCC_Topic__c = topic,
            XC_AFCC_Channel__c = channel,
            XC_AFCC_Case_Outcome__c = outcome,
            XC_AFCC_Calculation_Basis__c = basis,
            XC_AFCC_Allocation_Method__c = 'PRIMARY_CASE',
            XC_AFCC_Credits_Used__c = credits,
            XC_AFCC_Conversations_Used__c = conversations,
            XC_AFCC_Allocated_Cost__c = cost
        );
    }
}
