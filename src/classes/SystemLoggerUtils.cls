public class SystemLoggerUtils {
    public static final String DEFAULT_SYSLOG_USERNAME = 'DEFAULT';
    public static final Map<String, System_Logger_Setting__mdt> sysLogSettingsByUserName = getLogSettingsByUserName(new set<String>{UserInfo.getUserName()});
    public static final Map<String, String> userLogLevel2TypeMap = getUserLogLevelMap();

    // Given a LoggingLevel, Stack Trace string, and a message string, creates
    // and publishes a System Log Event record. Called by SystemLogger.
    public static void createAndPublishLogEvent (LoggingLevel logLevel,String stackTraceString,String msg,String relatedObjectId,String loggedFrom) {
        System_Log_Event__e newLogEvent = createLogEvent(logLevel,stackTraceString,msg,relatedObjectId,loggedFrom);
        System.debug('@@newLogEvent'+newLogEvent);
        publishEvents(new List<System_Log_Event__e>{newLogEvent});
    }

    // Given a list of System Log Event records, creates and inserts associated
    // System Log records. Called by SystemLogEventAfterInsertHandler.
    public static void createSystemLogs (List<System_Log_Event__e> newSystemLogEvents) {
        List<System_Log__c> newSysLogs = new List<System_Log__c>();
        Set<String> userNames = new Set<String>();
        
        if (newSystemLogEvents !=null) {
            for (System_Log_Event__e sle : newSystemLogEvents) {
                userNames.add(sle.Running_UserName__c);
            }
        
            Map<String,System_Logger_Setting__mdt> logSettingsByUserName = getLogSettingsByUserName(userNames);
            Map<String,Map<String,Boolean>> userName2DebugLevel2CaseCreationMap = getActionMap(userNames,'Create_Case_On__c');
            Map<String,Map<String,Boolean>> userName2DebugLevel2EmailCreationMap = getActionMap(userNames,'Send_Email_On__c');
    
            for (System_Log_Event__e sle : newSystemLogEvents) {
                String loggedFrom = (sle.Apex_Log_Event__c) ? 'Apex' : ((sle.Flow_Log_Event__c) ? 'Flow' : ((sle.Script_Log_Event__c) ? 'Script' : 'Unknown'));
                Id recordTypeId = getRecordTypeId(loggedFrom);
                String logLevelString = capitalizeFirst(sle.Log_Level__c);
                Boolean createCase = userName2DebugLevel2CaseCreationMap.containsKey(sle.Running_UserName__c) && !Test.isRunningTest() 
                                            ? userName2DebugLevel2CaseCreationMap.get(sle.Running_UserName__c).get(logLevelString) 
                                            : userName2DebugLevel2CaseCreationMap.get(DEFAULT_SYSLOG_USERNAME).get(logLevelString); // <= Unit Tests always use default!!
                Boolean sendEmail = userName2DebugLevel2EmailCreationMap.containsKey(sle.Running_UserName__c) && !Test.isRunningTest() 
                                            ? userName2DebugLevel2EmailCreationMap.get(sle.Running_UserName__c).get(logLevelString) 
                                            : userName2DebugLevel2EmailCreationMap.get(DEFAULT_SYSLOG_USERNAME).get(logLevelString); // <= Unit Tests always use default!!
                String emailAddr = (logSettingsByUserName.containsKey(sle.Running_UserName__c) && !Test.isRunningTest()) 
                                            ? logSettingsByUserName.get(sle.Running_UserName__c).Email_Address__c
                                            : logSettingsByUserName.get(DEFAULT_SYSLOG_USERNAME).Email_Address__c;
                newSysLogs.add(new System_Log__c
                (
                    Logged_From__c = loggedFrom,
                    RecordTypeId = recordTypeId,
                    Apex_Class__c = sle.Apex_Class__c,
                    Apex_Method__c = sle.Apex_Method__c,
                    Line_Number__c = sle.Line_Number__c,
                    Log_Level__c = logLevelString,
                    Message__c = sle.Message__c,
                    Related_Object_Id__c = sle.Related_Object_Id__c,
                    Running_UserName__c = sle.Running_UserName__c,
                    Running_User__c = sle.Running_UserId__c,
                    Stack_Trace__c = sle.Stack_Trace__c,
                    Flow_Name__c = sle.Flow_Name__c,
                    Flow_Stage__c = sle.Flow_Stage__c,
                    Script_Name__c = sle.Script_Name__c,
                    Send_Email__c = sendEmail,
                    Create_Case__c = createCase,
                    Email_Notification__c = emailAddr
                ));
            }
            try {
                insert newSysLogs;
            } catch (Exception e) {
                System.debug(LoggingLevel.Error,'SystemLoggerUtils.createSystemLogs() - Error inserting System Log record(s). Error: ' + e + ' - Record(s): ' + newSysLogs);
            }
        }
    }

    // Called by SystemLogger.
    public static void addDebugLine (LoggingLevel logLevel,String traceLine,String msg) {
        String logMsg = '** ' + SystemLoggerUtils.getClassName(traceLine) + '.' + SystemLoggerUtils.getMethodName(traceLine) 
                        + '() - ' + SystemLoggerUtils.getLineNumberString(traceLine) +' - '+ msg;
        System.debug('@@logLevel'+logLevel+logMsg);
    }

    // Called by SystemLogger and method createAndPublishLogEvent().
    public static void publishEvents (List<System_Log_Event__e> newLogEvents) {
        Boolean hasDML = (Limits.getLimitDmlRows() > (Limits.getDmlRows() + newLogEvents.size())) && (Limits.getLimitDmlStatements() > Limits.getDmlStatements());
        if (hasDML) {
            // The EventBus.publish() method does not throw exceptions caused by an unsuccessful publish operation. Hence processing the saveresult.
            List<Database.SaveResult> srList = EventBus.publish(newLogEvents); 
            for (Integer i=0; i < srList.size(); i++) {
                if (!srList[i].isSuccess()) {
                    for (Database.Error err : srList[i].getErrors()) {
                        System.debug(LoggingLevel.ERROR,'SystemLogger.publishEvents() - Error publishing System Log Event record: ' + newLogEvents[i] + ' - ERROR: ' + err.getMessage() + ' - FIELDS: ' + err.getFields());
                    }
                }
            }
        } else {
            try {
                System.enqueueJob (new SystemLoggerAsync(newLogEvents));
            } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR,'SystemLogger.publishEvents() - Error enqueueing System Log Event records. Error: ' + e + ' - Records: ' + newLogEvents);
            }
        }
    }

    //============================================= -- PRIVATE METHODS -- ==============================================//

    // Method: getLogSettingsByUserName(set<String> userNames) => map<String,System_Logger_Setting__mdt>
    // Returns a map of Username to SystemLoggerSetting. Called during static initialization.
    @TestVisible private static map<String, System_Logger_Setting__mdt> getLogSettingsByUserName (Set<String> userNames) {
        map<String, System_Logger_Setting__mdt> sysLogSettingsByUserName = new map<String, System_Logger_Setting__mdt>();
        userNames.add(DEFAULT_SYSLOG_USERNAME);
        for (System_Logger_Setting__mdt logger : [SELECT Id,DeveloperName,User_Name__c,On_Debug__c,On_Error__c,On_Info__c,
                                                On_Warn__c,Create_Case_On__c,Send_Email_On__c,Email_Address__c
                                            FROM System_Logger_Setting__mdt ])
                                            //WHERE User_Name__c IN :userNames])
        {sysLogSettingsByUserName.put(logger.User_Name__c, logger);}
        System.debug('@@sysLogSettingsByUserName' + sysLogSettingsByUserName);
        return sysLogSettingsByUserName;
    }

    // Returns the SystemLoggerSetting relevant to the current User.
    @TestVisible private static System_Logger_Setting__mdt getLogSetting (String userName) {
        System_Logger_Setting__mdt logger =
            sysLogSettingsByUserName.containsKey(UserInfo.getUserName()) ?
            sysLogSettingsByUserName.get(UserInfo.getUserName()) :
            sysLogSettingsByUserName.get(DEFAULT_SYSLOG_USERNAME); // <= Unit Tests always use default!!

        return logger;
    }

    // Returns a map of LoggingLevel to a string representing the desired "type"
    // of actions to perform. Called during static initialization.
    @TestVisible
    private static Map<String,String> getUserLogLevelMap() {
        Map<String,String> userLogLevel2TypeMap = new Map<String,String>();
        System_Logger_Setting__mdt setting = getLogSetting(UserInfo.getUserName());

        System.debug('@@setting'+setting);

        if (setting != null) {
            userLogLevel2TypeMap.put(capitalizeFirst(String.valueOf(LoggingLevel.DEBUG)),setting.On_Debug__c);
            userLogLevel2TypeMap.put(capitalizeFirst(String.valueOf(LoggingLevel.INFO)),setting.On_Info__c);
            userLogLevel2TypeMap.put(capitalizeFirst(String.valueOf(LoggingLevel.WARN)),setting.On_Warn__c);
            userLogLevel2TypeMap.put(capitalizeFirst(String.valueOf(LoggingLevel.ERROR)),setting.On_Error__c);
        }

        System.debug('@@userLogLevel2TypeMap' + userLogLevel2TypeMap);

        return userLogLevel2TypeMap;
    }

    // Given a set of usernames and the API name of a field on the
    // System_Logger_Setting__mdt metadata object, creates a map of Username to
    // LogLevel to Boolean, representing for which User and LogLevel the specified 
    // action should occur.
    @TestVisible private static Map<String, Map<String,Boolean>> getActionMap (Set<String> userNames, String actionField) {
        Map<String, Map<String,Boolean>> userName2DebugLevel2ActionMap = new Map<String, Map<String,Boolean>>();
        Set<String> settingFields = Schema.SObjectType.System_Logger_Setting__mdt.fields.getMap().keySet();
 
        if (String.isBlank(actionField) || !settingFields.contains(actionField.toLowerCase()))
            {return userName2DebugLevel2ActionMap;}
        userNames.add(DEFAULT_SYSLOG_USERNAME);

        for (System_Logger_Setting__mdt sls : [SELECT Id,DeveloperName,User_Name__c,Email_Address__c,
                                                Create_Case_On__c,Send_Email_On__c 
                                             FROM System_Logger_Setting__mdt
                                             WHERE User_Name__c IN :userNames])
        {
            system.debug('SystemLoggerUtils.getActionMap() - Reviewing SystemLoggerSetting: ' + sls);
            if (!userName2DebugLevel2ActionMap.containsKey(sls.User_Name__c))
                {userName2DebugLevel2ActionMap.put(sls.User_Name__c,new map<String,Boolean>());}
            userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', false);
            userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Warn', false);
            userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Info', false);
            userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Debug', false);
            switch on String.valueOf(sls.get(actionField))
            {
                when 'Error' {
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', true);
                }   
                when 'Warn' {
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Warn', true);
                }
                when 'Warn,Error' {
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Warn', true);
                }
                when 'Info' {
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Warn', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Info', true);
                }
                when 'Debug' {
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Error', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Warn', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Info', true);
                    userName2DebugLevel2ActionMap.get(sls.User_Name__c).put('Debug', true);
                }
            }
        }
        system.debug('SystemLoggerUtils.getActionMap() - Action Map: ' + userName2DebugLevel2ActionMap);
        return userName2DebugLevel2ActionMap;
    }

    // Given a LoggingLevel, Stack Trace string, and a message string
    // returns a valid System Log Event record.
    @TestVisible private static System_Log_Event__e createLogEvent (LoggingLevel logLevel, String stackTraceString, String msg, String relatedObjectId, String loggedFrom) {
        String traceLine  = getCallingTraceLine(stackTraceString);
        Integer stackTraceFieldLength = System_Log_Event__e.Stack_Trace__c.getDescribe().getLength();
        Integer messageFieldLength = System_Log_Event__e.Message__c.getDescribe().getLength();
        Integer relatedObjectIdFieldLength = System_Log_Event__e.Related_Object_Id__c.getDescribe().getLength();
        String loggedFromPretty = capitalizeFirst(loggedFrom);
        System_Log_Event__e newLogEvent = new System_Log_Event__e
        ( 
            Flow_Log_Event__c = (loggedFromPretty == 'Flow') ? true : false,
            Script_Log_Event__c = (loggedFromPretty == 'Script') ? true : false,
            Script_Name__c = (loggedFromPretty == 'Script') ? getClassName(traceLine) + '.' + getMethodName(traceLine) + '()' : null,
            Apex_Log_Event__c = (loggedFromPretty == 'Apex') ? true : false,
            Apex_Class__c = (loggedFromPretty == 'Apex') ? getClassName(traceLine) : null,
            Apex_Method__c = (loggedFromPretty == 'Apex') ? getMethodName(traceLine) : null,
            Line_Number__c = (loggedFromPretty == 'Apex' || loggedFromPretty == 'Script') ? getLineNumberString(traceLine) : null,
            Log_Level__c = capitalizeFirst(String.valueOf(logLevel)),
            Message__c = msg.left(messageFieldLength),
            Running_UserName__c = UserInfo.getUserName(),
            Running_UserId__c = UserInfo.getUserId(),
            Stack_Trace__c = stackTraceString.left(stackTraceFieldLength),
            Related_Object_Id__c = (relatedObjectId!=null)?relatedObjectId.left(relatedObjectIdFieldLength):null
        );
        return newLogEvent;
    }
    
    // Method: getCallingTraceLine (String stackTraceString) => String
    @TestVisible private static String getCallingTraceLine (String stackTraceString) {
        return stackTraceString.substringAfter('\n').substringBefore('\n');
    }
    
    // Method: getMethodName (String traceLine) => String
    @TestVisible private static String getMethodName (String traceLine) {
        return traceLine.substringBefore(':').substringAfterLast('.');
    }
    
    // Method: getLineNumberString (String traceLine) => String
    @TestVisible private static String getLineNumberString (String traceLine) {
        return traceLine.substringAfter(':').trim().substringBefore(',');
        // <= Ditch the column number - it's always 1.
    }
    
    // Method: getClassName (String traceLine) => String
    @TestVisible private static String getClassName (String traceLine) {
        return traceLine.startsWith('Class.') ? traceLine.substringAfter('Class.').substringBefore(':').substringBeforeLast('.')
                                            : traceLine.substringBefore(':').substringBeforeLast('.');
    }

    // Method: capitalizeFirst (String str) => String
    @TestVisible private static String capitalizeFirst (String str) {
        return String.isBlank(str) ? '' : str.toLowerCase().capitalize();
    }

    @TestVisible private static Id getRecordTypeId(String loggedFrom) {
        switch on loggedFrom {
            when 'Apex' {
                return Schema.SObjectType.System_Log__c.getRecordTypeInfosByDeveloperName().get('Apex').getRecordTypeId();
            }
            when 'Script' {
                return Schema.SObjectType.System_Log__c.getRecordTypeInfosByDeveloperName().get('Script').getRecordTypeId();
            }
            when 'Flow' {
                return Schema.SObjectType.System_Log__c.getRecordTypeInfosByDeveloperName().get('Flow').getRecordTypeId();
            }
        }
        return null;
    }
}