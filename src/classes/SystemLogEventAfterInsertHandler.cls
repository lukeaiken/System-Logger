// Sample Trigger Handler

public without sharing class SystemLogEventAfterInsertHandler implements TriggerDispatcher.ITriggerEntry {
    public static AppConfig__c systemLoggerConfig {
        get {
            AppConfig__c setting = AppConfig__c.getInstance('SystemLogger');
            if (setting == null) {
                setting = new AppConfig__c(Name = 'SystemLogger', IsEnabled__c = true);
                insert setting;
            }
            return setting;
        }
        private set;
    }

    public void mainEntry( List<SObject> newObjList, Map<Id, SObject> newObjMap, List<SObject> oldObjList,
            Map<Id, SObject> oldObjMap)
    {
        if (systemLoggerConfig.IsEnabled__c) {
            List<System_Log_Event__e> newList = (List<System_Log_Event__e>) newObjList;
            SystemLoggerUtils.createSystemLogs(newList);
        }
    }

    public void inProgressEntry(List<SObject> newObjList, Map<Id, SObject> newObjMap, List<SObject> oldObjList,
            Map<Id, SObject> oldObjMap)
    {

    }
}
