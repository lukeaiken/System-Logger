@IsTest
private class SystemLoggerTest {
    //========================================================================================
    // Method: testLogFromApex()
    @isTest static void testLogFromApex()
    {
        Contact testContact = new Contact(FirstName='Test',LastName='Test',Email='testing@here.now');
        insert testContact;
        system.assertNotEquals(testContact.Id,null);
        String testMsg = 'Test Error: Error';
        String testId = testContact.Id;

        System_Logger_Setting__mdt setting = [SELECT Id,DeveloperName,User_Name__c,On_Debug__c,On_Error__c,On_Info__c,On_Warn__c
        FROM System_Logger_Setting__mdt
        WHERE User_Name__c = :SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME
        LIMIT 1];
        Integer expectedLogCount = 0;
        expectedLogCount += (setting.On_Error__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Warn__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Info__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Debug__c == 'System Log') ? 1 : 0;

        Test.startTest();
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - About to generate system logs! ...');
        SystemLogger.log(LoggingLevel.ERROR,testMsg,testId);
        SystemLogger.log(LoggingLevel.WARN,testMsg,testId);
        SystemLogger.log(LoggingLevel.INFO,testMsg,testId);
        SystemLogger.log(LoggingLevel.DEBUG,testMsg,testId);
        SystemLogger.log(LoggingLevel.NONE,testMsg,testId);
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - ... Done generate system logs!');
        Test.getEventBus().deliver(); // <= Force deliver the messages in the event bus
        Test.stopTest();

        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c,Running_User__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.size(),expectedLogCount);
        system.assertEquals(sysLogRecords[0].Logged_From__c,'Apex');
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Related_Object_Id__c,testId);
    }

    //========================================================================================
    // Method: testLogWebService()
    @isTest static void testLogWebService()
    {
        String testMsg = 'Something bad happened.';
        list<String> testLogLevels = new list<String>{'Error','Warn','Info','Debug','None'};
        String testLoggedFrom = 'Script';
        Contact testContact = new Contact(FirstName='Test',LastName='Test',Email='testing@here.now');
        insert testContact;
        system.assertNotEquals(testContact.Id,null);

        System_Logger_Setting__mdt setting = [SELECT Id,DeveloperName,User_Name__c,On_Debug__c,On_Error__c,On_Info__c,On_Warn__c
        FROM System_Logger_Setting__mdt
        WHERE User_Name__c = :SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME
        LIMIT 1];
        Integer expectedLogCount = 0;
        expectedLogCount += (setting.On_Error__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Warn__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Info__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Debug__c == 'System Log') ? 1 : 0;

        Test.startTest();
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - About to generate system logs! ...');
        SystemLogger.createLog(testLogLevels[0],testMsg,testContact.Id,testLoggedFrom);
        SystemLogger.createLog(testLogLevels[1],testMsg,testContact.Id,testLoggedFrom);
        SystemLogger.createLog(testLogLevels[2],testMsg,testContact.Id,testLoggedFrom);
        SystemLogger.createLog(testLogLevels[3],testMsg,testContact.Id,testLoggedFrom);
        SystemLogger.createLog(testLogLevels[4],testMsg,testContact.Id,testLoggedFrom);
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - ... Done generate system logs!');
        Test.getEventBus().deliver(); // <= Force deliver the messages in the event bus
        Test.stopTest();

        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c,Running_User__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.size(),expectedLogCount);
        system.assertEquals(sysLogRecords[0].Logged_From__c,testLoggedFrom);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Related_Object_Id__c,testContact.Id);
    }

    //========================================================================================
    // Method: testLogInvocable()
    @isTest static void testLogInvocable()
    {
        String testMsg = 'Something bad happened.';
        list<String> testLogLevels = new list<String>{'Error','Warn','Info','Debug','None'};
        String testLoggedFrom = 'Flow';
        String testStackTrace = 'Class.TestClassName1.TestClassMethod1: line 123, column 1 \n'
                + 'Class.TestClassName2.TestClassMethod2: line 42, column 1';
        Contact testContact = new Contact(FirstName='Test',LastName='Test',Email='testing@here.now');
        insert testContact;
        system.assertNotEquals(testContact.Id,null);

        System_Logger_Setting__mdt setting = [SELECT Id,DeveloperName,User_Name__c,On_Debug__c,On_Error__c,On_Info__c,On_Warn__c
        FROM System_Logger_Setting__mdt
        WHERE User_Name__c = :SystemLoggerUtils.DEFAULT_SYSLOG_USERNAME
        LIMIT 1];
        Integer expectedLogCount = 0;
        expectedLogCount += (setting.On_Error__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Warn__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Info__c == 'System Log') ? 1 : 0;
        expectedLogCount += (setting.On_Debug__c == 'System Log') ? 1 : 0;

        list<System_Log_Event__e> eventsToPublish = new list<System_Log_Event__e>();
        for (String logLevel : testLogLevels)
        {
            eventsToPublish.add(new System_Log_Event__e
                    (
                            Flow_Log_Event__c = true,
                            Log_Level__c = logLevel,
                            Message__c = testMsg,
                            Running_UserName__c = UserInfo.getUserName(),
                            Stack_Trace__c = testStackTrace,
                            Related_Object_Id__c = testContact.Id
                    ));
        }

        Test.startTest();
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - About to generate system logs! ...');
        SystemLogger.log(eventsToPublish);
        system.debug(LoggingLevel.WARN,'SystemLoggerTest.testLogFromApex() - ... Done generate system logs!');
        Test.getEventBus().deliver(); // <= Force deliver the messages in the event bus
        Test.stopTest();

        list<System_Log__c> sysLogRecords = [SELECT Id,Logged_From__c,Apex_Class__c,Apex_Method__c,Line_Number__c,
                Log_Level__c,Message__c,Related_Object_Id__c,Running_UserName__c,
                Stack_Trace__c,Flow_Name__c,Flow_Stage__c,Running_User__c
        FROM System_Log__c];
        system.assertNotEquals(sysLogRecords,null);
        system.assertEquals(sysLogRecords.size(),expectedLogCount);
        system.assertEquals(sysLogRecords[0].Logged_From__c,testLoggedFrom);
        system.assertEquals(sysLogRecords[0].Message__c,testMsg);
        system.assertEquals(sysLogRecords[0].Related_Object_Id__c,testContact.Id);
    }


}