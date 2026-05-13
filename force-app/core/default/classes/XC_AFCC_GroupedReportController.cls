public with sharing class XC_AFCC_GroupedReportController {
    @AuraEnabled(cacheable=true)
    public static List<XC_AFCC_ReportQueryService.ReportRow> getRows(String groupByField) {
        return XC_AFCC_ReportQueryService.groupedReport(groupByField);
    }
}
