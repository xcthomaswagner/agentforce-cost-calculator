public with sharing class XC_AFCC_DemoScenarioService {
    public class Scenario {
        @AuraEnabled public String scenarioName;
        @AuraEnabled public Integer seed;
        @AuraEnabled public String billingModel;
        @AuraEnabled public Integer caseCount;
        @AuraEnabled public Integer accountCount;
        @AuraEnabled public Integer contactCount;
        @AuraEnabled public Integer ledgerRowsPerCase;
        @AuraEnabled public Decimal creditRate;
        @AuraEnabled public Decimal conversationRate;
        @AuraEnabled public Decimal deferredRate;
        @AuraEnabled public Decimal escalatedRate;
        @AuraEnabled public Decimal abandonedRate;
        @AuraEnabled public Decimal unallocatedUsageRate;
        @AuraEnabled public String hotspotQueue;
        @AuraEnabled public List<String> queueNames;
        @AuraEnabled public Map<String, Object> expectedResults;
        @AuraEnabled public String suggestedQuestion;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> listScenarios() {
        return new List<String>{
            'known-answer-small',
            'standard-flex',
            'deferred-hotspot',
            'conversation-pricing',
            'unallocated-usage',
            'missing-contract-rate'
        };
    }

    @AuraEnabled(cacheable=true)
    public static Scenario loadScenario(String scenarioName, String volume) {
        String name = String.isBlank(scenarioName) ? 'deferred-hotspot' : scenarioName;
        Scenario s = defaults(name);
        Integer multiplier = volume == 'large' ? 3 : (volume == 'small' ? 1 : 2);
        if (name != 'known-answer-small') {
            s.caseCount *= multiplier;
            s.accountCount *= multiplier;
            s.contactCount *= multiplier;
        }
        s.expectedResults.put('minimumCases', s.caseCount);
        s.expectedResults.put('minimumDeferredCases', Math.floor(s.caseCount * s.deferredRate).intValue());
        s.expectedResults.put('minimumLedgerRows', s.caseCount * s.ledgerRowsPerCase);
        s.expectedResults.put('topQueue', s.hotspotQueue);
        s.expectedResults.put('minimumUnallocatedUsagePercent', Math.max(0, s.unallocatedUsageRate * 100 - 1));
        s.expectedResults.put('maximumUnallocatedUsagePercent', s.unallocatedUsageRate * 100 + 1);
        return s;
    }

    private static Scenario defaults(String name) {
        Scenario s = new Scenario();
        s.scenarioName = name;
        s.seed = 12345;
        s.billingModel = 'FLEX_CREDITS';
        s.caseCount = 100;
        s.accountCount = 20;
        s.contactCount = 60;
        s.ledgerRowsPerCase = 4;
        s.creditRate = 0.005;
        s.conversationRate = 2.00;
        s.deferredRate = 0.20;
        s.escalatedRate = 0.10;
        s.abandonedRate = 0.05;
        s.unallocatedUsageRate = 0.04;
        s.hotspotQueue = 'Billing Support';
        s.queueNames = new List<String>{'Billing Support','Order Support','Returns','Product Help','Account Support'};
        s.expectedResults = new Map<String, Object>();
        s.suggestedQuestion = 'Which support queue has the highest Agentforce cost per deferred case?';

        if (name == 'known-answer-small') {
            s.caseCount = 3; s.accountCount = 1; s.contactCount = 3; s.ledgerRowsPerCase = 0;
            s.deferredRate = 0.34; s.escalatedRate = 0.33; s.abandonedRate = 0; s.unallocatedUsageRate = 0;
            s.expectedResults.put('totalCredits', 100);
            s.expectedResults.put('totalCost', 0.50);
        } else if (name == 'deferred-hotspot') {
            s.caseCount = 150; s.accountCount = 30; s.contactCount = 90; s.ledgerRowsPerCase = 5;
            s.deferredRate = 0.35; s.escalatedRate = 0.15; s.abandonedRate = 0.05; s.unallocatedUsageRate = 0.08;
        } else if (name == 'conversation-pricing') {
            s.billingModel = 'CONVERSATIONS'; s.ledgerRowsPerCase = 1; s.conversationRate = 2.00;
            s.suggestedQuestion = 'Which topics drive the most conversation-priced cost?';
        } else if (name == 'unallocated-usage') {
            s.unallocatedUsageRate = 0.18;
            s.suggestedQuestion = 'How much usage is not linked back to a Salesforce case?';
        } else if (name == 'missing-contract-rate') {
            s.creditRate = null;
            s.suggestedQuestion = 'Which rows are estimated because the contract rate is missing?';
        } else if (name == 'standard-flex') {
            s.suggestedQuestion = 'Where are Flex Credits concentrated by queue, topic, and outcome?';
        } else {
            throw new AuraHandledException('Unknown scenario: ' + name);
        }
        return s;
    }
}
