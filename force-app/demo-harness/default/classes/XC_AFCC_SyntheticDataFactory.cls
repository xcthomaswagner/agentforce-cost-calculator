public with sharing class XC_AFCC_SyntheticDataFactory {
    public class SeedResult {
        @AuraEnabled public String scenario;
        @AuraEnabled public Integer accounts;
        @AuraEnabled public Integer contacts;
        @AuraEnabled public Integer cases;
        @AuraEnabled public Integer stagingRows;
        @AuraEnabled public Integer ledgerRows;
        @AuraEnabled public Integer deferredCases;
        @AuraEnabled public Decimal unallocatedUsagePercent;
        @AuraEnabled public String suggestedQuestion;
    }

    public static SeedResult seed(XC_AFCC_DemoScenarioService.Scenario scenario) {
        XC_AFCC_DemoGuardService.assertCanRun();
        configureOrg(scenario);

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < scenario.accountCount; i++) {
            accounts.add(new Account(Name = 'XC AFCC Synthetic Account ' + scenario.scenarioName + ' ' + i));
        }
        insert accounts;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < scenario.contactCount; i++) {
            contacts.add(new Contact(
                FirstName = 'XC',
                LastName = 'AFCC Contact ' + i,
                AccountId = accounts[Math.mod(i, accounts.size())].Id,
                Email = 'xc.afcc.' + scenario.scenarioName.replace('-', '.') + '.' + i + '@example.invalid'
            ));
        }
        insert contacts;

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < scenario.caseCount; i++) {
            Contact c = contacts[Math.mod(i, contacts.size())];
            cases.add(new Case(
                Subject = 'XC AFCC Synthetic Case ' + scenario.scenarioName + ' ' + i,
                Origin = 'Web',
                Status = 'New',
                Priority = Math.mod(i, 5) == 0 ? 'High' : 'Medium',
                AccountId = c.AccountId,
                ContactId = c.Id
            ));
        }
        insert cases;
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        cases = [SELECT Id, CaseNumber, AccountId, ContactId FROM Case WHERE Id IN :caseIds ORDER BY CreatedDate ASC, Id ASC];

        List<XC_AFCC_Case_Conversation_Link__c> links = new List<XC_AFCC_Case_Conversation_Link__c>();
        List<XC_AFCC_Usage_Staging__c> stagingRows = scenario.scenarioName == 'known-answer-small'
            ? knownAnswerRows(scenario, cases)
            : generatedRows(scenario, cases);
        for (Case c : cases) {
            links.add(new XC_AFCC_Case_Conversation_Link__c(
                XC_AFCC_Case__c = c.Id,
                XC_AFCC_Case_Number__c = c.CaseNumber,
                XC_AFCC_Conversation_Id__c = 'xc-afcc-' + scenario.scenarioName + '-' + c.CaseNumber,
                XC_AFCC_Link_Method__c = 'SYNTHETIC',
                XC_AFCC_Confidence_Level__c = 'HIGH',
                XC_AFCC_Data_Set_Type__c = 'SYNTHETIC',
                XC_AFCC_Demo_Scenario_Id__c = scenario.scenarioName
            ));
        }
        insert links;
        insert stagingRows;
        XC_AFCC_CostLedgerService.processStaging(stagingRows);
        List<XC_AFCC_Cost_Ledger__c> ledgersToTag = new List<XC_AFCC_Cost_Ledger__c>();
        for (XC_AFCC_Cost_Ledger__c row : [
            SELECT Id FROM XC_AFCC_Cost_Ledger__c
            WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Demo_Scenario_Id__c = null
        ]) {
            row.XC_AFCC_Demo_Scenario_Id__c = scenario.scenarioName;
            ledgersToTag.add(row);
        }
        if (!ledgersToTag.isEmpty()) {
            update ledgersToTag;
        }

        XC_AFCC_DataHealthService.runDataHealth();
        return summarize(scenario);
    }

    private static void configureOrg(XC_AFCC_DemoScenarioService.Scenario scenario) {
        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        config.XC_AFCC_Install_Mode__c = 'DEMO';
        config.XC_AFCC_Billing_Model__c = scenario.billingModel;
        config.XC_AFCC_Contract_Credit_Rate__c = scenario.creditRate;
        config.XC_AFCC_Contract_Conversation_Rate__c = scenario.conversationRate;
        config.XC_AFCC_Default_Credit_Rate__c = 0.005;
        config.XC_AFCC_Default_Conversation_Rate__c = 2.00;
        config.XC_AFCC_Csv_Import_Enabled__c = true;
        update config;
    }

    private static List<XC_AFCC_Usage_Staging__c> knownAnswerRows(XC_AFCC_DemoScenarioService.Scenario scenario, List<Case> cases) {
        List<Decimal> credits = new List<Decimal>{10, 20, 30, 15, 25};
        List<String> outcomes = new List<String>{'RESOLVED','DEFERRED','ESCALATED','DEFERRED','RESOLVED'};
        List<XC_AFCC_Usage_Staging__c> rows = new List<XC_AFCC_Usage_Staging__c>();
        for (Integer i = 0; i < credits.size(); i++) {
            Case c = cases[Math.mod(i, cases.size())];
            rows.add(baseRow(scenario, c, i, credits[i], 0, outcomes[i], 'Billing Support'));
        }
        return rows;
    }

    private static List<XC_AFCC_Usage_Staging__c> generatedRows(XC_AFCC_DemoScenarioService.Scenario scenario, List<Case> cases) {
        List<XC_AFCC_Usage_Staging__c> rows = new List<XC_AFCC_Usage_Staging__c>();
        Integer totalRows = scenario.caseCount * scenario.ledgerRowsPerCase;
        Integer unallocatedEvery = 0;
        if (scenario.unallocatedUsageRate != null && scenario.unallocatedUsageRate > 0) {
            unallocatedEvery = Integer.valueOf(Math.floor(1 / scenario.unallocatedUsageRate));
            if (unallocatedEvery < 1) {
                unallocatedEvery = 1;
            }
        }
        for (Integer i = 0; i < totalRows; i++) {
            Integer caseIndex = Math.mod(i, cases.size());
            Case linkedCase = unallocatedEvery > 0 && Math.mod(i + scenario.seed, unallocatedEvery) == 0 ? null : cases[caseIndex];
            String queueName = chooseQueue(scenario, i);
            String outcome = chooseOutcome(scenario, i, queueName);
            Decimal credits = scenario.billingModel == 'FLEX_CREDITS' ? (queueName == scenario.hotspotQueue ? 30 : 20) : 0;
            Decimal conversations = scenario.billingModel == 'CONVERSATIONS' ? 1 : 0;
            rows.add(baseRow(scenario, linkedCase, i, credits, conversations, outcome, queueName));
        }
        return rows;
    }

    private static XC_AFCC_Usage_Staging__c baseRow(XC_AFCC_DemoScenarioService.Scenario scenario, Case c, Integer index, Decimal credits, Decimal conversations, String outcome, String queueName) {
        Datetime ts = System.now().addDays(-1 * Math.mod(index + scenario.seed, 21));
        XC_AFCC_Usage_Staging__c row = new XC_AFCC_Usage_Staging__c();
        row.XC_AFCC_Source_System__c = 'SYNTHETIC';
        row.XC_AFCC_Source_Record_Id__c = 'XC-AFCC-' + scenario.scenarioName + '-' + index;
        row.XC_AFCC_Billing_Model__c = scenario.billingModel;
        row.XC_AFCC_Usage_Timestamp__c = ts;
        row.XC_AFCC_Case_Number__c = c == null ? null : c.CaseNumber;
        row.XC_AFCC_Conversation_Id__c = 'xc-afcc-' + scenario.scenarioName + '-' + index;
        row.XC_AFCC_Agent_Name__c = 'Agent ' + (Math.mod(index, 4) + 1);
        row.XC_AFCC_Agent_Version__c = 'v' + (Math.mod(index, 3) + 1);
        row.XC_AFCC_Action_Name__c = 'Resolve Request';
        row.XC_AFCC_Topic__c = chooseTopic(index);
        row.XC_AFCC_Channel__c = 'Web';
        row.XC_AFCC_Queue_Name__c = queueName;
        row.XC_AFCC_Credits_Used__c = credits;
        row.XC_AFCC_Conversations_Used__c = conversations;
        row.XC_AFCC_Action_Count__c = 1;
        row.XC_AFCC_Case_Outcome__c = outcome;
        row.XC_AFCC_Data_Set_Type__c = 'SYNTHETIC';
        row.XC_AFCC_Processing_Status__c = 'PENDING';
        row.XC_AFCC_Raw_Payload__c = '{"scenario":"' + scenario.scenarioName + '","index":' + index + '}';
        return row;
    }

    private static String chooseQueue(XC_AFCC_DemoScenarioService.Scenario scenario, Integer index) {
        if (scenario.scenarioName == 'deferred-hotspot' && Math.mod(index, 2) == 0) {
            return scenario.hotspotQueue;
        }
        return scenario.queueNames[Math.mod(index + scenario.seed, scenario.queueNames.size())];
    }

    private static String chooseOutcome(XC_AFCC_DemoScenarioService.Scenario scenario, Integer index, String queueName) {
        Integer bucket = Math.mod(index + scenario.seed, 100);
        Integer deferredThreshold = Integer.valueOf(Math.floor(scenario.deferredRate * 100));
        if (scenario.scenarioName == 'deferred-hotspot' && queueName == scenario.hotspotQueue && bucket < 65) {
            return 'DEFERRED';
        }
        if (bucket < deferredThreshold) return 'DEFERRED';
        if (bucket < deferredThreshold + Integer.valueOf(Math.floor(scenario.escalatedRate * 100))) return 'ESCALATED';
        if (bucket < deferredThreshold + Integer.valueOf(Math.floor((scenario.escalatedRate + scenario.abandonedRate) * 100))) return 'ABANDONED';
        return 'RESOLVED';
    }

    private static String chooseTopic(Integer index) {
        List<String> topics = new List<String>{'Billing', 'Order Status', 'Returns', 'Product Fit', 'Account Access'};
        return topics[Math.mod(index, topics.size())];
    }

    private static SeedResult summarize(XC_AFCC_DemoScenarioService.Scenario scenario) {
        SeedResult r = new SeedResult();
        r.scenario = scenario.scenarioName;
        r.accounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'XC AFCC Synthetic Account%'];
        r.contacts = [SELECT COUNT() FROM Contact WHERE LastName LIKE 'AFCC Contact%'];
        r.cases = [SELECT COUNT() FROM Case WHERE Subject LIKE 'XC AFCC Synthetic Case%'];
        r.stagingRows = [SELECT COUNT() FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'];
        r.ledgerRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC'];
        r.deferredCases = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case_Outcome__c = 'DEFERRED'];
        Integer unallocated = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC' AND XC_AFCC_Case__c = null];
        r.unallocatedUsagePercent = r.ledgerRows == 0 ? 0 : (Decimal.valueOf(unallocated) * 100 / r.ledgerRows).setScale(2);
        r.suggestedQuestion = scenario.suggestedQuestion;
        return r;
    }
}
