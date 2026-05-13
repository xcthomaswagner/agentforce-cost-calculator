@IsTest
private class XC_AFCC_CoreServicesTest {
    @TestSetup
    static void setupData() {
        Account account = new Account(Name = 'XC AFCC Test Account');
        insert account;
        Contact contact = new Contact(FirstName = 'XC', LastName = 'AFCC Test', AccountId = account.Id);
        insert contact;
        insert new Case(Subject = 'XC AFCC Test Case', Origin = 'Web', Status = 'New', AccountId = account.Id, ContactId = contact.Id);
    }

    @IsTest
    static void calculatesFlexCreditCost() {
        XC_AFCC_Org_Config__c config = new XC_AFCC_Org_Config__c(
            XC_AFCC_Billing_Model__c = 'FLEX_CREDITS',
            XC_AFCC_Contract_Credit_Rate__c = 0.005,
            XC_AFCC_Default_Credit_Rate__c = 0.005
        );
        XC_AFCC_CostCalculationService.CalculationResult result =
            XC_AFCC_CostCalculationService.calculate('FLEX_CREDITS', 100, null, config, 'CSV_IMPORT');
        System.assertEquals(0.500, result.allocatedCost);
        System.assertEquals('IMPORTED', result.calculationBasis);
    }

    @IsTest
    static void importsCsvAndCreatesLedgerRows() {
        Case c = [SELECT CaseNumber FROM Case LIMIT 1];
        String csv = 'source_record_id,billing_model,usage_timestamp,case_number,conversation_id,agent_name,action_name,topic,channel,queue_name,credits_used,conversations_used,action_count,case_outcome\n' +
            'csv-1,FLEX_CREDITS,2026-01-01 12:00:00,' + c.CaseNumber + ',conv-1,Agent 1,Resolve,Billing,Web,Billing Support,20,0,1,RESOLVED\n';
        Test.startTest();
        XC_AFCC_CsvImportService.ImportResult result = XC_AFCC_CsvImportService.importCsv('usage.csv', csv);
        Test.stopTest();
        System.assertEquals(1, result.successCount);
        System.assertEquals(1, [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_Record_Id__c = 'csv-1']);
    }

    @IsTest
    static void handlesDuplicateImportRows() {
        String csv = 'source_record_id,billing_model,usage_timestamp,case_number,credits_used,case_outcome\n' +
            'dup-1,FLEX_CREDITS,2026-01-01 12:00:00,,10,RESOLVED\n' +
            'dup-1,FLEX_CREDITS,2026-01-01 12:00:00,,10,RESOLVED\n';
        XC_AFCC_CsvImportService.ImportResult result = XC_AFCC_CsvImportService.importCsv('dup.csv', csv);
        System.assertEquals(1, result.successCount);
        System.assertEquals(1, result.errorCount);
    }

    @IsTest
    static void missingRateUsesEstimatedBasis() {
        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        config.XC_AFCC_Contract_Credit_Rate__c = null;
        config.XC_AFCC_Default_Credit_Rate__c = 0.005;
        update config;
        insert new XC_AFCC_Usage_Staging__c(
            XC_AFCC_Source_System__c = 'CSV_IMPORT',
            XC_AFCC_Source_Record_Id__c = 'missing-rate-1',
            XC_AFCC_Billing_Model__c = 'FLEX_CREDITS',
            XC_AFCC_Usage_Timestamp__c = System.now(),
            XC_AFCC_Credits_Used__c = 10,
            XC_AFCC_Case_Outcome__c = 'UNKNOWN',
            XC_AFCC_Data_Set_Type__c = 'IMPORTED',
            XC_AFCC_Processing_Status__c = 'PENDING'
        );
        XC_AFCC_CostLedgerService.ProcessResult result = XC_AFCC_CostLedgerService.processPendingStaging();
        System.assertEquals(1, result.processedCount);
        System.assertEquals('ESTIMATED', [SELECT XC_AFCC_Calculation_Basis__c FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_Record_Id__c = 'missing-rate-1'].XC_AFCC_Calculation_Basis__c);
    }

    @IsTest
    static void reportAndCaseExplanationWork() {
        importsCsvAndCreatesLedgerRows();
        List<XC_AFCC_ReportQueryService.ReportRow> rows = XC_AFCC_ReportQueryService.groupedReport('queue');
        System.assert(!rows.isEmpty(), 'Grouped report should return rows.');
        Case c = [SELECT CaseNumber FROM Case LIMIT 1];
        XC_AFCC_CaseCostExplainService.CaseExplanation explanation = XC_AFCC_CaseCostExplainService.explainCase(null, c.CaseNumber);
        System.assert(explanation.ledgerRows > 0, 'Case explanation should find ledger rows.');
        try {
            XC_AFCC_ReportQueryService.groupedReport('bad_field');
            System.assert(false, 'Unsupported group-by should fail.');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex);
        }
    }

    @IsTest
    static void dataHealthAndSandboxReadinessWorkWithoutUsage() {
        XC_AFCC_DataHealthService.HealthSummary health = XC_AFCC_DataHealthService.validateSandboxReadiness();
        System.assertEquals('READY_FOR_IMPORT', health.result);
        System.assertEquals(false, XC_AFCC_EnvironmentService.getEnvironmentInfo().orgId == null);
    }
}
