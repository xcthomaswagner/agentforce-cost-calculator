@IsTest
private class XC_AFCC_DemoHarnessTest {
    @IsTest
    static void guardFailsWithoutPermission() {
        XC_AFCC_DemoGuardService.bypassForTests = false;
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'afccnp',
            Email = 'afcc-no-permission@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'No Permission',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'afcc-no-permission-' + System.now().getTime() + '@example.invalid'
        );
        insert u;
        System.runAs(u) {
            try {
                XC_AFCC_DemoGuardService.assertCanRun();
                System.assert(false, 'Guard should refuse execution without the custom permission.');
            } catch (Exception ex) {
                System.assert(ex.getMessage().contains('Demo Harness') || ex.getMessage().contains('access'));
            }
        }
    }

    @IsTest
    static void generatorCreatesKnownAnswerData() {
        XC_AFCC_DemoGuardService.bypassForTests = true;
        Test.startTest();
        XC_AFCC_SyntheticDataFactory.SeedResult seed = XC_AFCC_DemoSeeder.seed('known-answer-small', 'small');
        XC_AFCC_DemoReadinessService.ReadinessResult readiness = XC_AFCC_DemoReadinessService.validateCurrentScenario();
        Test.stopTest();
        System.assertEquals(3, seed.cases);
        System.assertEquals(5, seed.ledgerRows);
        System.assertEquals('PASS', readiness.result);
    }

    @IsTest
    static void resetRemovesGeneratedRows() {
        XC_AFCC_DemoGuardService.bypassForTests = true;
        XC_AFCC_DemoSeeder.seed('known-answer-small', 'small');
        Map<String, Integer> counts = XC_AFCC_DemoResetService.resetSyntheticData();
        System.assert(counts.get('ledger') > 0);
        System.assertEquals(0, [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'SYNTHETIC']);
    }
}
