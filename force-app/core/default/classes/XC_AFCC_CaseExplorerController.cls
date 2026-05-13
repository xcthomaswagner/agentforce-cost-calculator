public with sharing class XC_AFCC_CaseExplorerController {
    @AuraEnabled(cacheable=true)
    public static List<Case> recentCases() {
        return XC_AFCC_CaseCostExplainService.recentCasesWithCosts();
    }

    @AuraEnabled(cacheable=true)
    public static XC_AFCC_CaseCostExplainService.CaseExplanation explain(Id caseId, String caseNumber) {
        return XC_AFCC_CaseCostExplainService.explainCase(caseId, caseNumber);
    }
}
