<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>System_Log_Apex_Email_Alert</fullName>
        <description>System Log Apex Email Alert</description>
        <protected>false</protected>
        <recipients>
            <field>Email_Notification__c</field>
            <type>email</type>
        </recipients>
        <senderAddress>laiken@bhg-inc.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>System_Logger/System_Log_Apex_Email</template>
    </alerts>
    <alerts>
        <fullName>System_Log_Flow_Email_Alert</fullName>
        <description>System Log Flow Email Alert</description>
        <protected>false</protected>
        <recipients>
            <field>Email_Notification__c</field>
            <type>email</type>
        </recipients>
        <senderAddress>laiken@bhg-inc.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>System_Logger/System_Log_Flow_Email</template>
    </alerts>
    <alerts>
        <fullName>System_Log_Script_Email_Alert</fullName>
        <description>System Log Script Email Alert</description>
        <protected>false</protected>
        <recipients>
            <field>Email_Notification__c</field>
            <type>email</type>
        </recipients>
        <senderAddress>laiken@bhg-inc.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>System_Logger/System_Log_Script_Email</template>
    </alerts>
    <rules>
        <fullName>Send Apex Log Email</fullName>
        <actions>
            <name>System_Log_Apex_Email_Alert</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>System_Log__c.Logged_From__c</field>
            <operation>equals</operation>
            <value>Apex</value>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Email_Notification__c</field>
            <operation>notEqual</operation>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Send_Email__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>If a new Apex Log record should send an email (based on System Logger Custom Metadata), and has the necessary information, launch an Email Alert.</description>
        <triggerType>onCreateOnly</triggerType>
    </rules>
    <rules>
        <fullName>Send Flow Log Email</fullName>
        <actions>
            <name>System_Log_Flow_Email_Alert</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>System_Log__c.Logged_From__c</field>
            <operation>equals</operation>
            <value>Flow</value>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Email_Notification__c</field>
            <operation>notEqual</operation>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Send_Email__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>If a new Flow Log record should send an email (based on SystemLoggerSettings), and has the necessary information, launch an Email Alert.</description>
        <triggerType>onCreateOnly</triggerType>
    </rules>
    <rules>
        <fullName>Send Script Log Email</fullName>
        <actions>
            <name>System_Log_Script_Email_Alert</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>System_Log__c.Logged_From__c</field>
            <operation>equals</operation>
            <value>Script</value>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Email_Notification__c</field>
            <operation>notEqual</operation>
        </criteriaItems>
        <criteriaItems>
            <field>System_Log__c.Send_Email__c</field>
            <operation>equals</operation>
            <value>True</value>
        </criteriaItems>
        <description>If a new Script Log record should send an email (based on SystemLoggerSettings), and has the necessary information, launch an Email Alert.</description>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
