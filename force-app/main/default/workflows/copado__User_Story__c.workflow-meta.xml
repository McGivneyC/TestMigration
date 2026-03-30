<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Ready_To_Promote_Is_True</fullName>
        <field>copado__Promote_Change__c</field>
        <literalValue>1</literalValue>
        <name>Ready To Promote Is True</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
    <rules>
        <fullName>Set Ready To Promote To True</fullName>
        <actions>
            <name>Ready_To_Promote_Is_True</name>
            <type>FieldUpdate</type>
        </actions>
        <active>false</active>
        <criteriaItems>
            <field>copado__User_Story__c.copado__Status__c</field>
            <operation>equals</operation>
            <value>No Merge Conflicts,QA Complete,Ready for Production</value>
        </criteriaItems>
        <triggerType>onCreateOrTriggeringUpdate</triggerType>
    </rules>
</Workflow>
