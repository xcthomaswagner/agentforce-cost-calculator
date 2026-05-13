public with sharing class XC_AFCC_CostCalculationService {
    public class CalculationResult {
        @AuraEnabled public Decimal allocatedCost;
        @AuraEnabled public Decimal rateUsed;
        @AuraEnabled public String calculationBasis;
        @AuraEnabled public String billingModel;
    }

    public static CalculationResult calculate(String billingModel, Decimal creditsUsed, Decimal conversationsUsed, XC_AFCC_Org_Config__c config, String sourceSystem) {
        CalculationResult result = new CalculationResult();
        result.billingModel = String.isBlank(billingModel) ? 'UNKNOWN' : billingModel;
        Decimal credits = creditsUsed == null ? 0 : creditsUsed;
        Decimal conversations = conversationsUsed == null ? 0 : conversationsUsed;

        if (result.billingModel == 'CONVERSATIONS') {
            Decimal contractRate = config == null ? null : config.XC_AFCC_Contract_Conversation_Rate__c;
            Decimal defaultRate = config == null ? null : config.XC_AFCC_Default_Conversation_Rate__c;
            result.rateUsed = contractRate != null ? contractRate : (defaultRate != null ? defaultRate : 2.00);
            result.allocatedCost = conversations * result.rateUsed;
            result.calculationBasis = contractRate == null ? 'ESTIMATED' : basisForSource(sourceSystem);
            return result;
        }

        if (result.billingModel == 'FLEX_CREDITS') {
            Decimal contractRate = config == null ? null : config.XC_AFCC_Contract_Credit_Rate__c;
            Decimal defaultRate = config == null ? null : config.XC_AFCC_Default_Credit_Rate__c;
            result.rateUsed = contractRate != null ? contractRate : (defaultRate != null ? defaultRate : 0.005);
            result.allocatedCost = credits * result.rateUsed;
            result.calculationBasis = contractRate == null ? 'ESTIMATED' : basisForSource(sourceSystem);
            return result;
        }

        result.rateUsed = 0;
        result.allocatedCost = 0;
        result.calculationBasis = 'INCOMPLETE';
        return result;
    }

    private static String basisForSource(String sourceSystem) {
        if (sourceSystem == 'CSV_IMPORT') {
            return 'IMPORTED';
        }
        if (sourceSystem == 'SYNTHETIC') {
            return 'SYNTHETIC';
        }
        return 'ACTUAL';
    }
}
