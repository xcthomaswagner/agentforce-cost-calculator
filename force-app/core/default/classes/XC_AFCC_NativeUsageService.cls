public with sharing class XC_AFCC_NativeUsageService {
    private static final List<String> SOURCE_OBJECTS = new List<String>{
        'MessagingSession',
        'AgentWork',
        'Conversation',
        'ConversationDefinitionSession'
    };
    private static final String AGENTFORCE_EVENT_OBJECT = 'ConversationDefinitionEventLog';

    public class ObjectStatus {
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean available;
        @AuraEnabled public Boolean accessible;
        @AuraEnabled public Integer rowCount;
    }

    public class NativeReadiness {
        @AuraEnabled public String result;
        @AuraEnabled public Boolean accountAvailable;
        @AuraEnabled public Boolean contactAvailable;
        @AuraEnabled public Boolean caseAvailable;
        @AuraEnabled public Integer accountCount = 0;
        @AuraEnabled public Integer contactCount = 0;
        @AuraEnabled public Integer caseCount = 0;
        @AuraEnabled public Integer nativeSourceRows = 0;
        @AuraEnabled public Integer liveLedgerRows = 0;
        @AuraEnabled public List<ObjectStatus> sources = new List<ObjectStatus>();
        @AuraEnabled public List<String> messages = new List<String>();
    }

    public class NativeSyncResult {
        @AuraEnabled public Id runId;
        @AuraEnabled public String status;
        @AuraEnabled public Integer sourceRows = 0;
        @AuraEnabled public Integer stagedRows = 0;
        @AuraEnabled public Integer ledgerRows = 0;
        @AuraEnabled public Integer skippedRows = 0;
        @AuraEnabled public Integer errorRows = 0;
        @AuraEnabled public List<String> messages = new List<String>();
        @AuraEnabled public NativeReadiness readiness;
    }

    @AuraEnabled(cacheable=true)
    public static NativeReadiness getReadiness() {
        return inspectNativeReadiness();
    }

    @AuraEnabled
    public static NativeSyncResult syncNativeUsage() {
        return syncNativeUsage(2000);
    }

    public static NativeSyncResult syncNativeUsage(Integer limitSize) {
        Integer rowLimit = limitSize == null || limitSize <= 0 ? 2000 : Math.min(limitSize, 10000);
        NativeSyncResult result = new NativeSyncResult();
        result.readiness = inspectNativeReadiness();

        XC_AFCC_Import_Run__c run = new XC_AFCC_Import_Run__c();
        run.XC_AFCC_File_Name__c = 'Native Salesforce source sync';
        run.XC_AFCC_Import_Type__c = 'NATIVE_SYNC';
        run.XC_AFCC_Status__c = 'RUNNING';
        run.XC_AFCC_Started_At__c = System.now();
        insert run;
        result.runId = run.Id;

        if (result.readiness.nativeSourceRows == 0) {
            run.XC_AFCC_Status__c = result.readiness.result == 'MISSING_NATIVE_SOURCE' ? 'FAILED' : 'COMPLETED';
            run.XC_AFCC_Row_Count__c = 0;
            run.XC_AFCC_Success_Count__c = 0;
            run.XC_AFCC_Error_Count__c = 0;
            run.XC_AFCC_Completed_At__c = System.now();
            run.XC_AFCC_Error_Message__c = result.readiness.result == 'MISSING_NATIVE_SOURCE'
                ? 'No supported native Agentforce or Service Cloud source object is available.'
                : null;
            update run;
            result.status = run.XC_AFCC_Status__c;
            result.messages.addAll(result.readiness.messages);
            return result;
        }

        Set<String> sourceIds = existingSourceIds();
        List<XC_AFCC_Usage_Staging__c> stagingRows = new List<XC_AFCC_Usage_Staging__c>();
        Map<Id, Case> casesById = loadCasesById();
        Map<String, Case> casesByNumber = loadCasesByNumber();
        Map<String, Id> caseIdByAgentforceSession = loadAgentforceCaseLinks(casesByNumber);
        XC_AFCC_Org_Config__c config = XC_AFCC_SetupController.ensureDefaultConfig();
        String billingModel = String.isBlank(config.XC_AFCC_Billing_Model__c) ? 'CONVERSATIONS' : config.XC_AFCC_Billing_Model__c;

        for (String objectName : SOURCE_OBJECTS) {
            if (stagingRows.size() >= rowLimit || !isObjectAccessible(objectName)) {
                continue;
            }
            List<SObject> nativeRows = queryNativeRows(objectName, rowLimit - stagingRows.size());
            result.sourceRows += nativeRows.size();
            for (SObject nativeRow : nativeRows) {
                String sourceId = objectName + ':' + String.valueOf(nativeRow.get('Id'));
                if (sourceIds.contains(sourceId)) {
                    result.skippedRows++;
                    continue;
                }
                try {
                    XC_AFCC_Usage_Staging__c row = toStaging(run.Id, objectName, nativeRow, casesById, casesByNumber, caseIdByAgentforceSession, billingModel);
                    stagingRows.add(row);
                    sourceIds.add(sourceId);
                } catch (Exception ex) {
                    result.errorRows++;
                    result.messages.add(objectName + ' ' + String.valueOf(nativeRow.get('Id')) + ': ' + ex.getMessage());
                }
            }
        }

        if (!stagingRows.isEmpty()) {
            insert stagingRows;
            XC_AFCC_CostLedgerService.ProcessResult processResult = XC_AFCC_CostLedgerService.processStaging(stagingRows);
            result.stagedRows = stagingRows.size();
            result.ledgerRows = processResult.processedCount;
            result.errorRows += processResult.errorCount;
        }

        run.XC_AFCC_Row_Count__c = result.sourceRows;
        run.XC_AFCC_Success_Count__c = result.stagedRows;
        run.XC_AFCC_Error_Count__c = result.errorRows;
        run.XC_AFCC_Status__c = result.errorRows > 0 ? 'COMPLETED_WITH_ERRORS' : 'COMPLETED';
        run.XC_AFCC_Completed_At__c = System.now();
        update run;

        result.status = run.XC_AFCC_Status__c;
        result.readiness = inspectNativeReadiness();
        return result;
    }

    private static NativeReadiness inspectNativeReadiness() {
        NativeReadiness readiness = new NativeReadiness();
        readiness.accountAvailable = isObjectAccessible('Account');
        readiness.contactAvailable = isObjectAccessible('Contact');
        readiness.caseAvailable = isObjectAccessible('Case');
        readiness.accountCount = readiness.accountAvailable ? countRows('Account') : 0;
        readiness.contactCount = readiness.contactAvailable ? countRows('Contact') : 0;
        readiness.caseCount = readiness.caseAvailable ? countRows('Case') : 0;
        readiness.liveLedgerRows = [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'LIVE'];

        for (String objectName : SOURCE_OBJECTS) {
            ObjectStatus status = new ObjectStatus();
            status.apiName = objectName;
            status.available = Schema.getGlobalDescribe().containsKey(objectName);
            status.accessible = isObjectAccessible(objectName);
            status.rowCount = status.accessible ? countRows(objectName) : 0;
            readiness.nativeSourceRows += status.rowCount;
            readiness.sources.add(status);
        }

        if (!readiness.accountAvailable || !readiness.contactAvailable || !readiness.caseAvailable) {
            readiness.result = 'MISSING_SERVICE_CLOUD_DATA';
            readiness.messages.add('Account, Contact, and Case access is required for native analysis.');
        } else if (!hasAnyNativeSourceObject(readiness)) {
            readiness.result = 'MISSING_NATIVE_SOURCE';
            readiness.messages.add('No supported native Agentforce or Service Cloud source object is visible to the running user.');
        } else if (readiness.nativeSourceRows == 0) {
            readiness.result = 'READY_FOR_NATIVE_DATA';
            readiness.messages.add('Native source objects are available, but no source rows were found yet.');
        } else if (readiness.liveLedgerRows == 0) {
            readiness.result = 'NATIVE_READY';
            readiness.messages.add('Native source rows are available. Run native analysis to build live ledger rows.');
        } else {
            readiness.result = 'ANALYSIS_READY';
            readiness.messages.add('Live ledger rows are available for dashboard, reports, and case analysis.');
        }
        return readiness;
    }

    private static Boolean hasAnyNativeSourceObject(NativeReadiness readiness) {
        for (ObjectStatus status : readiness.sources) {
            if (status.accessible) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isObjectAccessible(String objectName) {
        Schema.SObjectType typeRef = Schema.getGlobalDescribe().get(objectName);
        return typeRef != null && typeRef.getDescribe().isAccessible();
    }

    private static Integer countRows(String objectName) {
        try {
            return Database.countQuery('SELECT COUNT() FROM ' + objectName);
        } catch (Exception ex) {
            return 0;
        }
    }

    private static Set<String> existingSourceIds() {
        Set<String> sourceIds = new Set<String>();
        for (XC_AFCC_Usage_Staging__c row : [
            SELECT XC_AFCC_Source_Record_Id__c
            FROM XC_AFCC_Usage_Staging__c
            WHERE XC_AFCC_Source_System__c = 'LIVE'
            LIMIT 50000
        ]) {
            sourceIds.add(row.XC_AFCC_Source_Record_Id__c);
        }
        for (XC_AFCC_Cost_Ledger__c row : [
            SELECT XC_AFCC_Source_Record_Id__c
            FROM XC_AFCC_Cost_Ledger__c
            WHERE XC_AFCC_Source_System__c = 'LIVE'
            LIMIT 50000
        ]) {
            sourceIds.add(row.XC_AFCC_Source_Record_Id__c);
        }
        return sourceIds;
    }

    private static Map<Id, Case> loadCasesById() {
        Map<Id, Case> casesById = new Map<Id, Case>();
        if (!isObjectAccessible('Case')) {
            return casesById;
        }
        for (Case c : [SELECT Id, CaseNumber, AccountId, ContactId, OwnerId, Status FROM Case LIMIT 10000]) {
            casesById.put(c.Id, c);
        }
        return casesById;
    }

    private static Map<String, Case> loadCasesByNumber() {
        Map<String, Case> casesByNumber = new Map<String, Case>();
        if (!isObjectAccessible('Case')) {
            return casesByNumber;
        }
        for (Case c : [SELECT Id, CaseNumber, AccountId, ContactId, OwnerId, Status FROM Case LIMIT 10000]) {
            casesByNumber.put(c.CaseNumber, c);
        }
        return casesByNumber;
    }

    private static Map<String, Id> loadAgentforceCaseLinks(Map<String, Case> casesByNumber) {
        Map<String, Id> links = new Map<String, Id>();
        if (casesByNumber.isEmpty() || !isObjectAccessible(AGENTFORCE_EVENT_OBJECT)) {
            return links;
        }
        for (SObject eventRow : queryNativeRows(AGENTFORCE_EVENT_OBJECT, 10000)) {
            String parentId = directString(eventRow, 'ParentId');
            if (String.isBlank(parentId)) {
                continue;
            }
            String sourceText = String.join(new List<String>{
                directString(eventRow, 'EventLabel'),
                directString(eventRow, 'EventDetails')
            }, ' ');
            Id caseId = caseIdFromText(sourceText, casesByNumber);
            if (caseId != null) {
                links.put(parentId, caseId);
            }
        }
        return links;
    }

    private static List<SObject> queryNativeRows(String objectName, Integer limitSize) {
        Schema.DescribeSObjectResult describe = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Map<String, Schema.SObjectField> fields = describe.fields.getMap();
        Set<String> selected = new Set<String>{'Id'};
        for (String fieldName : preferredFields(objectName)) {
            if (fields.containsKey(fieldName)) {
                selected.add(fieldName);
            }
        }
        String orderField = selected.contains('CreatedDate') ? 'CreatedDate' : 'Id';
        return Database.query(
            'SELECT ' + String.join(new List<String>(selected), ',') +
            ' FROM ' + objectName +
            ' ORDER BY ' + orderField + ' DESC LIMIT ' + limitSize
        );
    }

    private static List<String> preferredFields(String objectName) {
        List<String> commonFields = new List<String>{
            'Name', 'CreatedDate', 'LastModifiedDate', 'Status', 'OwnerId', 'UserId',
            'CaseId', 'Case__c', 'WorkItemId', 'RelatedToId', 'TargetObjectId',
            'ConversationId', 'MessagingSessionId', 'MessagingChannelId', 'ChannelType',
            'AgentName', 'AgentId', 'QueueName', 'ServiceChannelId', 'CloseDateTime', 'EndTime',
            'StartTime', 'AcceptDateTime', 'HandleTime', 'HandleTimeSeconds',
            'ExternalSessionKey', 'SessionStartTime', 'SessionDuration', 'SessionStatus',
            'SessionEndType', 'SessionTransferResult', 'WasSessionEngaged', 'HasErrorLogs',
            'ConversationDefinitionId', 'ParentId', 'EventDateTime', 'EventLabel', 'EventDetails',
            'LogType', 'LogLevel', 'Action', 'IsSuccessful', 'IntegrationName', 'IntegrationType',
            'ChannelType', 'Mode'
        };
        return commonFields;
    }

    private static XC_AFCC_Usage_Staging__c toStaging(Id runId, String objectName, SObject nativeRow, Map<Id, Case> casesById, Map<String, Case> casesByNumber, Map<String, Id> caseIdByAgentforceSession, String billingModel) {
        Id caseId = findCaseId(nativeRow, casesById, casesByNumber, caseIdByAgentforceSession);
        Case linkedCase = caseId == null ? null : casesById.get(caseId);
        Boolean isAgentforceSession = objectName == 'ConversationDefinitionSession';
        Boolean isAgentforceEvent = objectName == 'ConversationDefinitionEventLog';

        XC_AFCC_Usage_Staging__c row = new XC_AFCC_Usage_Staging__c();
        row.XC_AFCC_Import_Run__c = runId;
        row.XC_AFCC_Source_System__c = 'LIVE';
        row.XC_AFCC_Source_Record_Id__c = objectName + ':' + String.valueOf(nativeRow.get('Id'));
        row.XC_AFCC_Billing_Model__c = billingModel;
        row.XC_AFCC_Usage_Timestamp__c = firstDateTime(nativeRow, new List<String>{'SessionStartTime', 'EventDateTime', 'CreatedDate', 'StartTime', 'AcceptDateTime', 'LastModifiedDate'});
        row.XC_AFCC_Case_Id_Text__c = caseId == null ? null : String.valueOf(caseId);
        row.XC_AFCC_Case_Number__c = linkedCase == null ? null : linkedCase.CaseNumber;
        row.XC_AFCC_Conversation_Id__c = isAgentforceSession
            ? firstString(nativeRow, new List<String>{'ExternalSessionKey', 'Id'})
            : firstString(nativeRow, new List<String>{'ConversationId', 'ParentId', 'ConversationDefinitionId', 'Id'});
        if (String.isBlank(row.XC_AFCC_Conversation_Id__c)) {
            row.XC_AFCC_Conversation_Id__c = firstString(nativeRow, new List<String>{'ExternalSessionKey', 'ConversationId', 'ParentId', 'ConversationDefinitionId', 'Id'});
        }
        row.XC_AFCC_Messaging_Session_Id__c = objectName == 'MessagingSession' ? String.valueOf(nativeRow.get('Id')) : firstString(nativeRow, new List<String>{'MessagingSessionId'});
        row.XC_AFCC_Agent_Name__c = left(firstString(nativeRow, new List<String>{'AgentName', 'UserId', 'OwnerId', 'IntegrationName'}), 255);
        row.XC_AFCC_Action_Name__c = left(isAgentforceSession ? 'Agentforce Session' : (isAgentforceEvent ? firstString(nativeRow, new List<String>{'Action', 'LogType'}) : objectName), 255);
        row.XC_AFCC_Topic__c = left(firstString(nativeRow, new List<String>{'Name', 'EventLabel', 'SessionStatus', 'LogType'}), 255);
        row.XC_AFCC_Channel__c = isAgentforceSession || isAgentforceEvent ? 'Other' : (objectName == 'MessagingSession' ? 'Messaging' : 'Other');
        row.XC_AFCC_Queue_Name__c = firstString(nativeRow, new List<String>{'QueueName', 'ServiceChannelId'});
        row.XC_AFCC_Credits_Used__c = billingModel == 'FLEX_CREDITS' && (isAgentforceSession || !isAgentforceEvent) ? 1 : null;
        row.XC_AFCC_Conversations_Used__c = billingModel == 'CONVERSATIONS' && !isAgentforceEvent ? 1 : null;
        row.XC_AFCC_Action_Count__c = 1;
        row.XC_AFCC_Case_Outcome__c = outcomeFor(linkedCase, nativeRow);
        row.XC_AFCC_Data_Set_Type__c = 'LIVE';
        row.XC_AFCC_Processing_Status__c = 'PENDING';
        row.XC_AFCC_Raw_Payload__c = JSON.serialize(new Map<String, Object>{
            'sourceObject' => objectName,
            'sourceRecordId' => String.valueOf(nativeRow.get('Id')),
            'conversationIdentifier' => row.XC_AFCC_Conversation_Id__c
        });
        return row;
    }

    private static Id findCaseId(SObject nativeRow, Map<Id, Case> casesById, Map<String, Case> casesByNumber, Map<String, Id> caseIdByAgentforceSession) {
        String rowId = directString(nativeRow, 'Id');
        if (!String.isBlank(rowId) && caseIdByAgentforceSession.containsKey(rowId)) {
            return caseIdByAgentforceSession.get(rowId);
        }
        for (String fieldName : new List<String>{'CaseId', 'Case__c', 'WorkItemId', 'RelatedToId', 'TargetObjectId'}) {
            Object value = safeGet(nativeRow, fieldName);
            if (value == null) {
                continue;
            }
            try {
                Id candidate = (Id) value;
                if (casesById.containsKey(candidate)) {
                    return candidate;
                }
            } catch (Exception ex) {
                // Ignore non-ID values.
            }
        }
        String sourceText = String.join(new List<String>{
            directString(nativeRow, 'ExternalSessionKey'),
            firstString(nativeRow, new List<String>{'EventLabel'}),
            firstString(nativeRow, new List<String>{'EventDetails'})
        }, ' ');
        Id caseIdFromText = caseIdFromText(sourceText, casesByNumber);
        if (caseIdFromText != null) {
            return caseIdFromText;
        }
        return null;
    }

    private static Id caseIdFromText(String sourceText, Map<String, Case> casesByNumber) {
        if (String.isBlank(sourceText) || casesByNumber.isEmpty()) {
            return null;
        }
        for (String token : sourceText.split('[^A-Za-z0-9]+')) {
            if (!String.isBlank(token) && casesByNumber.containsKey(token)) {
                return casesByNumber.get(token).Id;
            }
        }
        return null;
    }

    private static Datetime firstDateTime(SObject row, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            Object value = safeGet(row, fieldName);
            if (value instanceof Datetime) {
                return (Datetime) value;
            }
        }
        return System.now();
    }

    private static String firstString(SObject row, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            String value = directString(row, fieldName);
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    private static String directString(SObject row, String fieldName) {
        Object value = safeGet(row, fieldName);
        return value == null ? null : String.valueOf(value);
    }

    private static String left(String value, Integer maxLength) {
        if (String.isBlank(value) || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static Object safeGet(SObject row, String fieldName) {
        try {
            return row.get(fieldName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static String outcomeFor(Case linkedCase, SObject nativeRow) {
        if (linkedCase != null) {
            if (linkedCase.Status == 'Closed') {
                return 'RESOLVED';
            }
            return 'DEFERRED';
        }
        String status = firstString(nativeRow, new List<String>{'Status'});
        if (status != null && status.toLowerCase().contains('closed')) {
            return 'RESOLVED';
        }
        return 'UNKNOWN';
    }
}
