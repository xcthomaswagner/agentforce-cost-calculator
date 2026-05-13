public with sharing class XC_AFCC_CsvImportService {
    public class ImportResult {
        @AuraEnabled public Id importRunId;
        @AuraEnabled public Integer rowCount = 0;
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer errorCount = 0;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static ImportResult importCsv(String fileName, String csvBody) {
        if (String.isBlank(csvBody)) {
            throw new AuraHandledException('CSV body is required.');
        }
        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        if (config.XC_AFCC_Csv_Import_Enabled__c != true) {
            throw new AuraHandledException('CSV import is disabled.');
        }

        ImportResult result = new ImportResult();
        XC_AFCC_Import_Run__c run = new XC_AFCC_Import_Run__c();
        run.XC_AFCC_File_Name__c = String.isBlank(fileName) ? 'usage-import.csv' : fileName;
        run.XC_AFCC_Import_Type__c = 'CSV';
        run.XC_AFCC_Status__c = 'RUNNING';
        run.XC_AFCC_Started_At__c = System.now();
        insert run;
        result.importRunId = run.Id;

        List<List<String>> parsed = parseCsv(csvBody);
        if (parsed.isEmpty()) {
            run.XC_AFCC_Status__c = 'FAILED';
            run.XC_AFCC_Error_Message__c = 'CSV has no rows.';
            update run;
            result.status = run.XC_AFCC_Status__c;
            result.message = run.XC_AFCC_Error_Message__c;
            return result;
        }

        Map<String, Integer> headerIndex = headerMap(parsed[0]);
        Set<String> sourceIds = new Set<String>();
        for (Integer i = 1; i < parsed.size(); i++) {
            String sourceId = value(parsed[i], headerIndex, 'source_record_id');
            if (!String.isBlank(sourceId)) {
                sourceIds.add(sourceId);
            }
        }
        Set<String> existingSourceIds = new Set<String>();
        if (!sourceIds.isEmpty()) {
            for (XC_AFCC_Usage_Staging__c row : [SELECT XC_AFCC_Source_Record_Id__c FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Source_Record_Id__c IN :sourceIds]) {
                existingSourceIds.add(row.XC_AFCC_Source_Record_Id__c);
            }
        }

        List<XC_AFCC_Usage_Staging__c> rows = new List<XC_AFCC_Usage_Staging__c>();
        for (Integer i = 1; i < parsed.size(); i++) {
            List<String> csvRow = parsed[i];
            if (csvRow.size() == 1 && String.isBlank(csvRow[0])) {
                continue;
            }
            result.rowCount++;
            try {
                String sourceId = value(csvRow, headerIndex, 'source_record_id');
                if (String.isBlank(sourceId)) {
                    sourceId = 'CSV-' + EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.join(csvRow, '|')))).left(40);
                }
                if (existingSourceIds.contains(sourceId)) {
                    result.errorCount++;
                    continue;
                }
                rows.add(toStaging(run.Id, csvRow, headerIndex, sourceId));
                existingSourceIds.add(sourceId);
                result.successCount++;
            } catch (Exception ex) {
                result.errorCount++;
            }
        }
        if (!rows.isEmpty()) {
            insert rows;
            XC_AFCC_CostLedgerService.processStaging(rows);
        }

        run.XC_AFCC_Row_Count__c = result.rowCount;
        run.XC_AFCC_Success_Count__c = result.successCount;
        run.XC_AFCC_Error_Count__c = result.errorCount;
        run.XC_AFCC_Status__c = result.errorCount > 0 ? 'COMPLETED_WITH_ERRORS' : 'COMPLETED';
        run.XC_AFCC_Completed_At__c = System.now();
        update run;
        result.status = run.XC_AFCC_Status__c;
        result.message = 'Imported ' + result.successCount + ' of ' + result.rowCount + ' rows.';
        return result;
    }

    private static XC_AFCC_Usage_Staging__c toStaging(Id runId, List<String> row, Map<String, Integer> headerIndex, String sourceId) {
        XC_AFCC_Usage_Staging__c staging = new XC_AFCC_Usage_Staging__c();
        staging.XC_AFCC_Import_Run__c = runId;
        staging.XC_AFCC_Source_System__c = 'CSV_IMPORT';
        staging.XC_AFCC_Source_Record_Id__c = sourceId;
        staging.XC_AFCC_Billing_Model__c = cleanPick(value(row, headerIndex, 'billing_model'), new Set<String>{'FLEX_CREDITS','CONVERSATIONS','UNKNOWN'}, 'UNKNOWN');
        staging.XC_AFCC_Usage_Timestamp__c = parseDateTime(value(row, headerIndex, 'usage_timestamp'));
        staging.XC_AFCC_Case_Number__c = value(row, headerIndex, 'case_number');
        staging.XC_AFCC_Conversation_Id__c = value(row, headerIndex, 'conversation_id');
        staging.XC_AFCC_Agent_Name__c = value(row, headerIndex, 'agent_name');
        staging.XC_AFCC_Agent_Version__c = value(row, headerIndex, 'agent_version');
        staging.XC_AFCC_Action_Name__c = value(row, headerIndex, 'action_name');
        staging.XC_AFCC_Topic__c = value(row, headerIndex, 'topic');
        staging.XC_AFCC_Channel__c = value(row, headerIndex, 'channel');
        staging.XC_AFCC_Queue_Name__c = value(row, headerIndex, 'queue_name');
        staging.XC_AFCC_Credits_Used__c = parseDecimal(value(row, headerIndex, 'credits_used'));
        staging.XC_AFCC_Conversations_Used__c = parseDecimal(value(row, headerIndex, 'conversations_used'));
        staging.XC_AFCC_Action_Count__c = parseDecimal(value(row, headerIndex, 'action_count'));
        staging.XC_AFCC_Case_Outcome__c = cleanPick(value(row, headerIndex, 'case_outcome'), new Set<String>{'RESOLVED','DEFERRED','ESCALATED','ABANDONED','UNKNOWN'}, 'UNKNOWN');
        staging.XC_AFCC_Data_Set_Type__c = 'IMPORTED';
        staging.XC_AFCC_Processing_Status__c = 'PENDING';
        staging.XC_AFCC_Raw_Payload__c = JSON.serialize(row);
        return staging;
    }

    private static List<List<String>> parseCsv(String body) {
        List<List<String>> rows = new List<List<String>>();
        List<String> current = new List<String>();
        String cell = '';
        Boolean inQuotes = false;
        for (Integer i = 0; i < body.length(); i++) {
            String ch = body.substring(i, i + 1);
            if (ch == '\"') {
                if (inQuotes && i + 1 < body.length() && body.substring(i + 1, i + 2) == '\"') {
                    cell += '\"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                current.add(cell);
                cell = '';
            } else if ((ch == '\n' || ch == '\r') && !inQuotes) {
                if (ch == '\r' && i + 1 < body.length() && body.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
                current.add(cell);
                rows.add(current);
                current = new List<String>();
                cell = '';
            } else {
                cell += ch;
            }
        }
        current.add(cell);
        rows.add(current);
        return rows;
    }

    private static Map<String, Integer> headerMap(List<String> headers) {
        Map<String, Integer> indexes = new Map<String, Integer>();
        for (Integer i = 0; i < headers.size(); i++) {
            indexes.put(headers[i].trim().toLowerCase(), i);
        }
        return indexes;
    }

    private static String value(List<String> row, Map<String, Integer> headerIndex, String name) {
        Integer idx = headerIndex.get(name);
        return idx == null || idx >= row.size() ? null : row[idx].trim();
    }

    private static Decimal parseDecimal(String value) {
        return String.isBlank(value) ? null : Decimal.valueOf(value);
    }

    private static Datetime parseDateTime(String value) {
        if (String.isBlank(value)) {
            return System.now();
        }
        return value.contains('T') ? (Datetime) JSON.deserialize('\"' + value + '\"', Datetime.class) : Datetime.valueOf(value);
    }

    private static String cleanPick(String value, Set<String> allowed, String fallback) {
        String normalized = String.isBlank(value) ? fallback : value.trim().toUpperCase();
        return allowed.contains(normalized) ? normalized : fallback;
    }
}
