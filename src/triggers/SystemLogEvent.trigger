trigger SystemLogEvent on System_Log_Event__e (after insert) {
    TriggerDispatcher.handleTriggers(trigger.operationType, trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
}