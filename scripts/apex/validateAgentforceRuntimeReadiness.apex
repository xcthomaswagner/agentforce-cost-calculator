Map<String, Object> result = new Map<String, Object>();
Map<String, Schema.SObjectType> described = Schema.getGlobalDescribe();
List<String> requiredObjects = new List<String>{'Account', 'Contact', 'Case'};
List<String> runtimeObjects = new List<String>{'MessagingSession', 'AgentWork', 'Conversation', 'ConversationDefinitionSession'};

for (String objectName : requiredObjects) {
    Boolean available = described.containsKey(objectName);
    Boolean accessible = available && described.get(objectName).getDescribe().isAccessible();
    Integer rows = 0;
    if (accessible) {
        try {
            rows = Database.countQuery('SELECT COUNT() FROM ' + objectName);
        } catch (Exception ex) {
            rows = 0;
        }
    }
    result.put(objectName + 'Available', available);
    result.put(objectName + 'Accessible', accessible);
    result.put(objectName + 'Rows', rows);
}

Integer runtimeRows = 0;
List<Map<String, Object>> runtimeSources = new List<Map<String, Object>>();
for (String objectName : runtimeObjects) {
    Map<String, Object> source = new Map<String, Object>();
    Boolean available = described.containsKey(objectName);
    Boolean accessible = available && described.get(objectName).getDescribe().isAccessible();
    Integer rows = 0;
    if (accessible) {
        try {
            rows = Database.countQuery('SELECT COUNT() FROM ' + objectName);
        } catch (Exception ex) {
            rows = 0;
        }
    }
    runtimeRows += rows;
    source.put('source', objectName);
    source.put('available', available);
    source.put('accessible', accessible);
    source.put('rows', rows);
    runtimeSources.add(source);
}

result.put('runtimeSources', runtimeSources);
result.put('runtimeSourceRows', runtimeRows);
result.put('liveStagingRows', [SELECT COUNT() FROM XC_AFCC_Usage_Staging__c WHERE XC_AFCC_Source_System__c = 'LIVE']);
result.put('liveLedgerRows', [SELECT COUNT() FROM XC_AFCC_Cost_Ledger__c WHERE XC_AFCC_Source_System__c = 'LIVE']);
result.put('nativeReadiness', XC_AFCC_NativeUsageService.getReadiness());
System.debug(JSON.serializePretty(result));
