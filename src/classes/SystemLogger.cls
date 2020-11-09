global class SystemLogger {
    public static String stackTraceString;
    // This method can be called directly from Apex.
    // Arguments:
    //      @logLevel            System.LoggingLevel enum - log level ('Error','Warn','Info','Debug')
    //      @msg                 String - The message to log
    //      @relatedObjectId     String - Id of related Object for which the log is generated

    global static void log (LoggingLevel logLevel, Exception ex) {
        stackTraceString  = ex.getStackTraceString();
        SystemLogger.log(logLevel, ex, null);
    }

    global static void log (LoggingLevel logLevel, Exception ex, String relatedObjectId) {
        stackTraceString  = ex.getStackTraceString();
        SystemLogger.log(logLevel, ex.getMessage(), relatedObjectId);
    }

    global static void log (LoggingLevel logLevel, String msg) {
        SystemLogger.log(logLevel, msg, null);
    }

    global static void log (LoggingLevel logLevel, String msg, String relatedObjectId) {
        if (stackTraceString == null) stackTraceString  = new DmlException().getStackTraceString(); // Fast way to get trace string
        String stackTraceLine = stackTraceString.substringAfter('\n').substringBefore('\n');
        String logLevelString = String.isBlank(String.valueOf(logLevel)) ? '' : String.valueOf(logLevel).toLowerCase().capitalize();

        System.debug('@@logLevelString'+logLevelString);
        
        String userLogType = SystemLoggerUtils.userLogLevel2TypeMap.get(logLevelString);

        System.debug('@@userLogType'+userLogType);

        if (String.isBlank(userLogType) || userLogType == 'None') return;

        SystemLoggerUtils.addDebugLine(logLevel, stackTraceLine, msg);

        if (userLogType == 'System Log')
            SystemLoggerUtils.createAndPublishLogEvent(logLevel, stackTraceString, msg, relatedObjectId,'Apex');
    }

    // As a web service, this method can be called via the AJAX Toolkit:
    //   sforce.apex.execute('SystemLogger','createLog',{logLevel:'Error',msg:'Some message here',relatedObjectId:null});
    // Arguments:
    //      @logLevelString      String - log level ('Error','Warn','Info','Debug')
    //      @msg                 String - The message to log
    //      @relatedObjectId     String - Id of related Object for which the log is generated
    //      @loggedFrom          String - What type of process generated the log ('Apex','Flow','Script') 
    webService static void createLog (String logLevelString, String msg, String relatedObjectId, String loggedFrom) {
        System.debug('@@msg'+msg);
        
        // Get the trace string for the class/method that called this method (this is the fast way)
        if (stackTraceString == null) stackTraceString  = new DmlException().getStackTraceString(); // Fast way to get trace string
        String stackTraceLine = stackTraceString.substringAfter('\n').substringBefore('\n');
        String loggedFromPretty = (String.isBlank(loggedFrom)) ? 'Unknown' : loggedFrom.toLowerCase().capitalize(); 
        system.debug('@@loggedFromPretty'+loggedFromPretty);
        
        String logLevelStringPretty = String.isBlank(logLevelString) ? '' : String.valueOf(logLevelString).toLowerCase().capitalize();
        system.debug('@@logLevelStringPretty'+logLevelStringPretty);
        
        String userLogType = SystemLoggerUtils.userLogLevel2TypeMap.get(logLevelStringPretty);
        system.debug('@@userLogType'+userLogType);
        if (String.isBlank(userLogType) || userLogType == 'None')
            {return;}
        System.LoggingLevel logLevel;
        switch on logLevelStringPretty 
        {
            when 'Error' {logLevel = LoggingLevel.Error;}   
            when 'Warn' {logLevel = LoggingLevel.Warn;}
            when 'Info' {logLevel = LoggingLevel.Info;}
            when 'Debug' {logLevel = LoggingLevel.Debug;}
            when else {logLevel = LoggingLevel.None;}
        }
        SystemLoggerUtils.addDebugLine(logLevel,stackTraceLine,msg);
        if (userLogType == 'System Log')
            {SystemLoggerUtils.createAndPublishLogEvent(logLevel,stackTraceString,msg,relatedObjectId,loggedFromPretty);}
    }


    // This invocable method is for Flows or Process Builders. It takes a list of System_Log_Event__e
    // records to be published (sent as a single record from a flow, but bulkified by SF internally).  
    // Letting the Apex method publishEvents() handle the DML allows for: 
    //      - Asynchronous processing, if necessary
    //      - Capturing of the stack trace
    // Arguments:
    //      @systemLogEvents    list<System_Log_Event__e> - List of events to be published

    @InvocableMethod (label = 'Publish System Log Event' description = 'Takes a System_Log_Event__e record as an argument.')
    global static void log (list<System_Log_Event__e> systemLogEvents) {
        String stackTraceString = new DmlException().getStackTraceString();
        
        if (systemLogEvents.isEmpty()) return;
        
        
        List<System_Log_Event__e> eventsToPublish = new List<System_Log_Event__e>();
        Integer stackTraceFieldLength = System_Log_Event__e.Stack_Trace__c.getDescribe().getLength();

        for (System_Log_Event__e sle : systemLogEvents) {
            if(sle.message__c.length() > 250 ){
                sle.message__c = sle.message__c.substring(0, 250);
            }
            String logLevelString = String.isBlank(sle.Log_Level__c) ? '' : sle.Log_Level__c.toLowerCase().capitalize();
            String userLogType = String.isBlank(logLevelString) ? '' : SystemLoggerUtils.userLogLevel2TypeMap.get(logLevelString);
            if (!String.isBlank(userLogType) && userLogType != 'None') {
                System.LoggingLevel logLevel;
                switch on sle.Log_Level__c.toLowerCase().capitalize() {
                    when 'Error' {logLevel = LoggingLevel.Error;}   
                    when 'Warn' {logLevel = LoggingLevel.Warn;}
                    when 'Info' {logLevel = LoggingLevel.Info;}
                    when 'Debug' {logLevel = LoggingLevel.Debug;}
                    when else {logLevel = LoggingLevel.None;}
                }
                String debugLine = 'Flow: "' + sle.Flow_Name__c + '" Stage: "'+ sle.Flow_Stage__c + '" Object Id: "' +  sle.Related_Object_Id__c + '" - Message: '+ sle.Message__c;
                System.debug(logLevel, debugLine);
            }
            if (userLogType == 'System Log') {
                sle.Stack_Trace__c = stackTraceString.left(stackTraceFieldLength);
                eventsToPublish.add(sle);
            }
        }
        if (!eventsToPublish.isEmpty()) SystemLoggerUtils.publishEvents(eventsToPublish);
    }
}