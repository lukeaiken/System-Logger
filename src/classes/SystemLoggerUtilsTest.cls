@IsTest
private class SystemLoggerUtilsTest {
    //========================================================================================
    // Method: testGetUserLogLevelMap()
    @isTest static void testGetUserLogLevelMap()
    {
        map<String,System_Logger_Setting__mdt> sysLogSettingsByUserName = new map<String,System_Logger_Setting__mdt>();
        System_Logger_Setting__mdt sls = [SELECT Id,DeveloperName,User_Name__c,On_Debug__c,On_Error__c,On_Info__c,On_Warn__c
        FROM System_Logger_Setting__mdt
        WHERE User_Name__c = :SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME
        LIMIT 1];

        system.assertNotEquals(sysLogSettingsByUserName,null);
        String debugKey = String.valueOf(LoggingLevel.DEBUG).toLowerCase().capitalize();
        String infoKey = String.valueOf(LoggingLevel.INFO).toLowerCase().capitalize();
        String warnKey = String.valueOf(LoggingLevel.WARN).toLowerCase().capitalize();
        String errorKey = String.valueOf(LoggingLevel.ERROR).toLowerCase().capitalize();

        Test.startTest();
        map<String,String> userLogLevelMap = SystemLoggerUtils.getUserLogLevelMap();
        Test.stopTest();

        system.assertNotEquals(userLogLevelMap,null);
        system.assertEquals(userLogLevelMap.get(debugKey),sls.On_Debug__c);
        system.assertEquals(userLogLevelMap.get(infoKey),sls.On_Info__c);
        system.assertEquals(userLogLevelMap.get(warnKey),sls.On_Warn__c);
        system.assertEquals(userLogLevelMap.get(errorKey),sls.On_Error__c);
    }

    //==========================================================================
    // Method: testCreateSystemLogs()
    @isTest static void testCreateSystemLogs()
    {
        String testClassName = 'TestClass';
        String testMethodName = 'TestClass';
        String testLineNumber = 'line 42';
        String testMsg = 'Test Error: Error';
        String testUserName = UserInfo.getUserName();
        String testLogLevel = String.valueOf(LoggingLevel.Error).toLowerCase().capitalize();
        String testStackTrace = 'Stack Trace Here';

        list<System_Log_Event__e> testSystemLogEvents = new list<System_Log_Event__e>();
        testSystemLogEvents.add(new System_Log_Event__e
                (
                        Apex_Log_Event__c = true,
                        Apex_Class__c = testClassName,
                        Apex_Method__c = testMethodName,
                        Line_Number__c = testLineNumber,
                        Log_Level__c = testLogLevel,
                        Message__c = testMsg,
                        Running_UserName__c = testUserName,
                        Stack_Trace__c = testStackTrace
                ));

        Test.startTest();
        SystemLoggerUtils.createSystemLogs(testSystemLogEvents);
        Test.stopTest();

        // Technically, these asserts require the System_Log_Event__e trigger to run!
        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertNotEquals(sysLogRecords.isEmpty(),true);

        system.assertEquals(sysLogRecords[0].Logged_From__c,'Apex');
        system.assertEquals(sysLogRecords[0].Apex_Class__c,testClassName);
        system.assertEquals(sysLogRecords[0].Apex_Method__c,testMethodName);
        system.assertEquals(sysLogRecords[0].Line_Number__c,testLineNumber);
        system.assertEquals(sysLogRecords[0].Log_Level__c,testLogLevel);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Running_UserName__c,testUserName);
        system.assertEquals(sysLogRecords[0].Stack_Trace__c,testStackTrace);
    }

    //==========================================================================
    // Method: testCreateLogEvent()
    @isTest static void testCreateLogEvent()
    {
        String testLoggedFrom = '';
        String testMsg = 'Test Error: Error';
        String testUserName = UserInfo.getUserName();
        String testLogLevel = String.valueOf(LoggingLevel.Error).toLowerCase().capitalize();
        String testStackTrace = 'Class.TestClassName1.TestClassMethod1: line 123, column 1 \n'
                + 'Class.TestClassName2.TestClassMethod2: line 42, column 1';
        System_Log_Event__e sysLogEvent;

        Test.startTest();

        testLoggedFrom = 'Apex';
        sysLogEvent = SystemLoggerUtils.createLogEvent(LoggingLevel.Error,testStackTrace,testMsg,null,testLoggedFrom);

        system.assertNotEquals(sysLogEvent,null);
        system.assertEquals(sysLogEvent.Apex_Log_Event__c,true);
        system.assertEquals(sysLogEvent.Apex_Class__c,'TestClassName2');
        system.assertEquals(sysLogEvent.Apex_Method__c,'TestClassMethod2');
        system.assertEquals(sysLogEvent.Line_Number__c,'line 42');
        system.assertEquals(sysLogEvent.Log_Level__c,testLogLevel);
        system.assertEquals(sysLogEvent.Message__c,testMsg);
        system.assertEquals(sysLogEvent.Running_UserName__c,testUserName);
        system.assertEquals(sysLogEvent.Stack_Trace__c,testStackTrace);

        testLoggedFrom = 'Script';
        sysLogEvent = SystemLoggerUtils.createLogEvent(LoggingLevel.Error,testStackTrace,testMsg,null,testLoggedFrom);

        system.assertNotEquals(sysLogEvent,null);
        system.assertEquals(sysLogEvent.Script_Log_Event__c,true);
        system.assertEquals(sysLogEvent.Log_Level__c,testLogLevel);
        system.assertEquals(sysLogEvent.Message__c,testMsg);
        system.assertEquals(sysLogEvent.Running_UserName__c,testUserName);
        system.assertEquals(sysLogEvent.Stack_Trace__c,testStackTrace);

        testLoggedFrom = 'Flow';
        sysLogEvent = SystemLoggerUtils.createLogEvent(LoggingLevel.Error,testStackTrace,testMsg,null,testLoggedFrom);

        system.assertNotEquals(sysLogEvent,null);
        system.assertEquals(sysLogEvent.Flow_Log_Event__c,true);
        system.assertEquals(sysLogEvent.Log_Level__c,testLogLevel);
        system.assertEquals(sysLogEvent.Message__c,testMsg);
        system.assertEquals(sysLogEvent.Running_UserName__c,testUserName);
        system.assertEquals(sysLogEvent.Stack_Trace__c,testStackTrace);

        Test.stopTest();
    }

    //==========================================================================
    // Method: testGetCallingTraceLine()
    @isTest static void testGetCallingTraceLine()
    {
        String testStackTrace = 'Class.TestClassName1.TestClassMethod1: line 123, column 1 \n';
        testStackTrace += 'Class.TestClassName2.TestClassMethod2: line 42, column 1';

        Test.startTest();
        String traceLine = SystemLoggerUtils.getCallingTraceLine(testStackTrace);
        Test.stopTest();

        system.assertNotEquals(traceLine,null);
        system.assertEquals(traceLine.contains('TestClassName2.TestClassMethod2'),true);
    }

    //==========================================================================
    // Method: testGetMethodName()
    @isTest static void testGetMethodName()
    {
        String testTraceLine = 'Class.TestClassName2.TestClassMethod2: line 42, column 1';

        Test.startTest();
        String methodName = SystemLoggerUtils.getMethodName(testTraceLine);
        Test.stopTest();

        system.assertNotEquals(methodName,null);
        system.assertEquals(methodName,'TestClassMethod2');
    }

    //==========================================================================
    // Method: testGetLineNumberString()
    @isTest static void testGetLineNumberString()
    {
        String testTraceLine = 'Class.TestClassName2.TestClassMethod2: line 42, column 1';

        Test.startTest();
        String lineNumber = SystemLoggerUtils.getLineNumberString(testTraceLine);
        Test.stopTest();

        system.assertNotEquals(lineNumber,null);
        system.assertEquals(lineNumber,'line 42');
    }

    //==========================================================================
    // Method: testGetClassName()
    @isTest static void testGetClassName()
    {
        String testTraceLine = 'Class.TestClassName2.TestClassMethod2: line 42, column 1';

        Test.startTest();
        String className = SystemLoggerUtils.getClassName(testTraceLine);
        Test.stopTest();

        system.assertNotEquals(className,null);
        system.assertEquals(className,'TestClassName2');
    }

    //========================================================================================
    // Method: testAddDebugLine()
    @isTest static void testAddDebugLine()
    {
        String testTraceLine = 'Class.TestClassName.TestClassMethod: line 42, column 1';
        String testMsg = 'Test Error: Error';

        Test.startTest();
        SystemLoggerUtils.addDebugLine(LoggingLevel.DEBUG,testTraceLine,testMsg);
        Test.stopTest();
    }

    //========================================================================================
    // Method: testCreateAndPublishLogEvent()
    @isTest static void testCreateAndPublishLogEvent()
    {
        String testLoggedFrom = 'Apex';
        String testMsg = 'Test Error: Some error.';
        System.LoggingLevel testLogLevel = LoggingLevel.Error;
        String testStackTrace = 'Class.TestClassName1.TestClassMethod1: line 123, column 1 \n'
                + 'Class.TestClassName2.TestClassMethod2: line 42, column 1';

        Test.startTest();
        SystemLoggerUtils.createAndPublishLogEvent(testLogLevel,testStackTrace,testMsg,null,testLoggedFrom);
        Test.getEventBus().deliver(); // <= Force deliver the messages in the event bus
        Test.stopTest();

        // Technically, these asserts require the System_Log_Event__e trigger to run! (can't query events)
        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.isEmpty(),false);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Logged_From__c,testLoggedFrom);
    }

    //========================================================================================
    // Method: testPublishEvent()
    @isTest static void testPublishEvent()
    {
        String testClassName = 'TestClass';
        String testMethodName = 'TestClass';
        String testLineNumber = 'line 42';
        String testMsg = 'Test Error: Error';
        String testUserName = UserInfo.getUserName();
        String testLogLevel = String.valueOf(LoggingLevel.Error).toLowerCase().capitalize();
        String testStackTrace = 'Stack Trace Here';

        list<System_Log_Event__e> testSystemLogEvents = new list<System_Log_Event__e>();
        testSystemLogEvents.add(new System_Log_Event__e
                (
                        Apex_Log_Event__c = true,
                        Apex_Class__c = testClassName,
                        Apex_Method__c = testMethodName,
                        Line_Number__c = testLineNumber,
                        Log_Level__c = testLogLevel,
                        Message__c = testMsg,
                        Running_UserName__c = testUserName,
                        Stack_Trace__c = testStackTrace
                ));

        Test.startTest();
        SystemLoggerUtils.publishEvents(testSystemLogEvents);
        Test.stopTest();

        // Technically, these asserts require the System_Log_Event__e trigger to run! (can't query events)
        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.isEmpty(),false);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Logged_From__c,'Apex');
    }
    
    //========================================================================================
    // Method: testPublishEventAsync()
    @isTest static void testPublishEventAsync()
    {
        String testClassName = 'TestClass';
        String testMethodName = 'TestClass';
        String testLineNumber = 'line 42';
        String testMsg = 'Test Error: Error';
        String testUserName = UserInfo.getUserName();
        String testLogLevel = String.valueOf(LoggingLevel.Error).toLowerCase().capitalize();
        String testStackTrace = 'Stack Trace Here';

        list<System_Log_Event__e> testSystemLogEvents = new list<System_Log_Event__e>();
        testSystemLogEvents.add(new System_Log_Event__e
                (
                        Apex_Log_Event__c = true,
                        Apex_Class__c = testClassName,
                        Apex_Method__c = testMethodName,
                        Line_Number__c = testLineNumber,
                        Log_Level__c = testLogLevel,
                        Message__c = testMsg,
                        Running_UserName__c = testUserName,
                        Stack_Trace__c = testStackTrace
                ));

        Test.startTest();
        // !!! Create enough records to use up the DML limit !!!
        /*list<Lead> testLeads = new list<Lead>();
        for (Integer i=0; i < Limits.getLimitDmlRows(); i++)
        {
            testLeads.add(new Lead
                    (
                            FirstName = 'Tester'+i,
                            LastName='Testing'+i,
                            Email='me' + i + '@here.now',
                            Company ='Test Company XX',
                            Status = 'New',
                            LeadSource = 'Other',
                            Industry = 'Aerospace'
                    ));
        }
        insert testLeads; // Use up the DML limit*/
        SystemLoggerUtils.publishEvents(testSystemLogEvents); // Now try to publish
        Test.stopTest();

        // Technically, these asserts require the System_Log_Event__e trigger to run! (can't query events)
        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.isEmpty(),false);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Logged_From__c,'Apex');
    }

    //========================================================================================
    // Method: testGetActionMap()
    @isTest static void testGetActionMap()
    {
        list<String> testLogLevels = new list<String>{'Error','Warn','Info','Debug'};
        set<String> userNames = new set<String>{SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME};
        System_Logger_Setting__mdt sls = [SELECT Id,DeveloperName,User_Name__c,Create_Case_On__c,Send_Email_On__c
        FROM System_Logger_Setting__mdt
        WHERE User_Name__c IN :userNames
        LIMIT 1];
        String emailOnSetting = sls.Send_Email_On__c;
        Boolean emailOnDebug = (emailOnSetting == 'Debug') ? true : false;
        Boolean emailOnInfo = (emailOnSetting == 'Info' || emailOnDebug) ? true : false;
        Boolean emailOnWarn = (emailOnSetting.contains('Warn') || emailOnInfo || emailOnDebug) ? true : false;
        Boolean emailOnError = (emailOnSetting.contains('Error') || emailOnWarn || emailOnInfo || emailOnDebug) ? true : false;

        map<String,map<String,Boolean>> userName2DebugLevel2EmailCreationMap = new map<String,map<String,Boolean>>();

        Test.startTest();
        userName2DebugLevel2EmailCreationMap = SystemLoggerUtils.getActionMap(userNames,'Send_Email_On__c');
        Test.stopTest();
        system.debug('userName2DebugLevel2EmailCreationMap--->'+userName2DebugLevel2EmailCreationMap);
        system.assertNotEquals(userName2DebugLevel2EmailCreationMap,null);
        system.assertEquals(userName2DebugLevel2EmailCreationMap.isEmpty(),false);
        system.assertEquals(userName2DebugLevel2EmailCreationMap.get(SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME).get('Debug'),emailOnDebug);
        system.assertEquals(userName2DebugLevel2EmailCreationMap.get(SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME).get('Info'),emailOnInfo);
        system.assertEquals(userName2DebugLevel2EmailCreationMap.get(SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME).get('Warn'),emailOnWarn);
        system.assertEquals(userName2DebugLevel2EmailCreationMap.get(SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME).get('Error'),emailOnError);
    }
}