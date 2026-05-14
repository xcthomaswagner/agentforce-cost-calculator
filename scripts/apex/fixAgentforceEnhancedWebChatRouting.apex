String channelDeveloperName = 'XC_AFCC_Agentforce_Cost_Chat';
Map<String, Object> result = new Map<String, Object>();

List<MessagingChannel> channels = [
    SELECT Id, DeveloperName, MasterLabel, FallbackQueueId, SessionHandlerId
    FROM MessagingChannel
    WHERE DeveloperName = :channelDeveloperName
    LIMIT 1
];
if (channels.isEmpty()) {
    throw new AuraHandledException('Enhanced Web Chat messaging channel not found: ' + channelDeveloperName);
}

MessagingChannel channel = channels[0];
if (channel.FallbackQueueId == null) {
    throw new AuraHandledException('Messaging channel has no fallback queue: ' + channelDeveloperName);
}

List<ServiceChannel> serviceChannels = [
    SELECT Id, DeveloperName, MasterLabel, RelatedEntity, RoutingConfigurationId
    FROM ServiceChannel
    WHERE RelatedEntity = 'MessagingSession'
    LIMIT 1
];
if (serviceChannels.isEmpty() || serviceChannels[0].RoutingConfigurationId == null) {
    throw new AuraHandledException('MessagingSession service channel has no routing configuration.');
}

ServiceChannel messagingServiceChannel = serviceChannels[0];
Group fallbackQueue = [
    SELECT Id, Name, DeveloperName, Type, QueueRoutingConfigId
    FROM Group
    WHERE Id = :channel.FallbackQueueId
    LIMIT 1
];
if (fallbackQueue.Type != 'Queue') {
    throw new AuraHandledException('Fallback target is not a queue: ' + channel.FallbackQueueId);
}

Boolean queueUpdated = false;
if (fallbackQueue.QueueRoutingConfigId != messagingServiceChannel.RoutingConfigurationId) {
    fallbackQueue.QueueRoutingConfigId = messagingServiceChannel.RoutingConfigurationId;
    update fallbackQueue;
    queueUpdated = true;
}

List<QueueSobject> queueSobjects = [
    SELECT Id
    FROM QueueSobject
    WHERE QueueId = :fallbackQueue.Id
    AND SobjectType = 'MessagingSession'
    LIMIT 1
];
Boolean queueSobjectInserted = false;
if (queueSobjects.isEmpty()) {
    insert new QueueSobject(
        QueueId = fallbackQueue.Id,
        SobjectType = 'MessagingSession'
    );
    queueSobjectInserted = true;
}

result.put('channelId', channel.Id);
result.put('channelDeveloperName', channel.DeveloperName);
result.put('sessionHandlerId', channel.SessionHandlerId);
result.put('fallbackQueueId', fallbackQueue.Id);
result.put('fallbackQueueName', fallbackQueue.Name);
result.put('routingConfigurationId', messagingServiceChannel.RoutingConfigurationId);
result.put('queueRoutingConfigUpdated', queueUpdated);
result.put('queueSobjectInserted', queueSobjectInserted);
result.put('status', 'READY_FOR_ENHANCED_WEB_CHAT_ROUTING');

System.debug(JSON.serializePretty(result));
