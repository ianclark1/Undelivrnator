<!--- ===========================================================================
// CLASS/COMPONENT:Undelivrnator
//
// AUTHOR:
// Andy Matthews (ADM), amatthews@dealerskins.com
//
// COPYRIGHT:
// Copyright (c) 2008 Dealerskins
//
// PURPOSE:
// Automates the spooling of undelivered messages found in ColdFusion's built in Undelivr folder
//
// CREDITS:
// Undelivernator is based on SpoolMail by Ray Camden
//
// REVISION HISTORY:
// Initial Creation
//
// DETAILS
// Created to remove the necessity of manually running SpoolMail.
// Run this CFC as a scheduled task to manage undelivered ColdFusion emails.
//
// ******************************************************************************
// User: ADM  Date: 2/8/2007
// Initial Creation
// ******************************************************************************
=========================================================================== --->
<cfcomponent name="Undelivernator" displayname="Undelivrnator" hint="Handles mail in the Undelivr folder" output="false">

	<cfset VARIABLES.maildir = ''>
	<cfset VARIABLES.spooldir = ''>
	<cfset VARIABLES.timesToTry = 3>
	<cfset VARIABLES.deletetimeframe = 90>
	<cfset VARIABLES.server = 'S1'>
	<cfset VARIABLES.DSN = ''>

	<cffunction name="init" output="true" returnType="Undelivernator" hint="I return an instance of the Undelivernator CFC">
		<cfargument name="serverid" type="string" required="true" hint="A 4 character (or less) string with which to identify one, of many, servers which might be running Undelivrnator">
		<cfargument name="serverRoot" type="string" required="true" hint="Path to ColdFusion on this server">
		<cfargument name="timesToTry" type="numeric" required="true" hint="How many times should Undelivrnator respool the email before deleting it">
		<cfargument name="deleteTimeFrame" type="numeric" required="true" hint="How long should Undelivrnator keep record of deleted emails before removing them from the table">
		<cfargument name="DSN" type="string" required="true" hint="DSN under which Undelivrnator is running">

		<!--- initialization variables --->
		<cfset VARIABLES.maildir = ARGUMENTS.serverRoot & "/Mail/Undelivr/">
		<cfset VARIABLES.spooldir = ARGUMENTS.serverRoot & "/Mail/Spool/">
		<cfset VARIABLES.timesToTry = ARGUMENTS.timesToTry>
		<cfset VARIABLES.deletetimeframe = ARGUMENTS.deleteTimeFrame>
		<cfset VARIABLES.server = ARGUMENTS.serverid>
		<cfset VARIABLES.DSN = ARGUMENTS.DSN>

		<!--- return an instance of the whole CFC with vars set up. --->
		<cfreturn this>
	</cffunction>

	<cffunction name="run" output="true" returnType="numeric" hint="I kick off the Undelivernator process">

		<cftry>

				<!--- check the undelivr folder --->
				<cfdirectory action="list" name="VARIABLES.mail" directory="#VARIABLES.maildir#" filter="*.cfmail" sort="datelastmodified desc">

				<!--- make sure there's at least one email in the folder --->
				<cfif VARIABLES.mail.recordcount>

					<!--- loop over whatever's in the Undelivr folder --->
					<cfloop query="VARIABLES.mail">

						<!--- get some details on "this" email --->
						<cfset VARIABLES.info = THIS.getMailInfo(VARIABLES.mail.name,VARIABLES.maildir)>

						<!--- create the structure to be used when passing this data around --->
						<cfset VARIABLES.thisMail = StructNew()>
						<cfset VARIABLES.thisMail.EmailFile = VARIABLES.mail.name>
						<cfset VARIABLES.thisMail.ToAddress = VARIABLES.info.to>
						<cfset VARIABLES.thisMail.FromAddress = VARIABLES.info.sender>
						<cfset VARIABLES.thisMail.SentDate = VARIABLES.info.sent>

						<!---
							perform check against the database
							This method creates the initial record if one does not exist,
							or updates an existing record
							it returns the count for that record
						--->
						<cfset VARIABLES.Attempts = THIS.updateRecord(VARIABLES.thisMail,VARIABLES.timesToTry)>

						<!--- if the number of the attempts is less then VARIABLES.timesToTry --->
						<cfif VARIABLES.attempts LT VARIABLES.timesToTry>
							<!--- we move the email into the Spool folder --->
							<cfset THIS.moveEmail(VARIABLES.thisMail.EmailFile,VARIABLES.maildir,VARIABLES.spooldir)>
						<cfelse>
							<!--- but this one is greater than three so we're deleting the email --->
							<cfset THIS.deleteEmail(VARIABLES.thisMail.EmailFile,VARIABLES.maildir)>
						</cfif>

					</cfloop><!--- end VARIABLES.mail loop --->

					<!--- delete all emails past a certain age --->
					<cfset THIS.deleteOldRecords()>

				</cfif>
				<cfcatch type="any">
					<cfreturn 0>
				</cfcatch>
			</cftry>
		<cfreturn 1>
	</cffunction>

	<cffunction name="getMailInfo" output="true" returnType="struct" hint="Parses a mail file for info.">
		<cfargument name="EmailFile" type="string" required="true">
		<cfargument name="maildir" type="string" required="true">
		<cfset var pos = 0 />
		<cfset var maildetails = "" />
		<cfset var result = structNew()>
		<cfset result.sender = "">
		<cfset result.to = "">
		<cfset result.sent = "">

		<!--- read in the file --->
		<cffile action="read" file="#VARIABLES.maildir#/#ARGUMENTS.EmailFile#" variable="maildetails">

		<!--- start parsing --->
		<!--- look for a from address --->
		<cfset pos = reFindNoCase("(?m)^from: (.*?)\n", maildetails, 1, 1)>
		<cfif pos.len[1] is not 0>
			<!--- and get the sender if it exists --->
			<cfset result.sender = trim(mid(maildetails, pos.pos[2], pos.len[2]))>
		</cfif>
		<!--- look for a to address --->
		<cfset pos = reFindNoCase("(?m)^to: (.*?)\n", maildetails, 1, 1)>
		<cfif pos.len[1] is not 0>
			<!--- and get the recipient if it exists --->
			<cfset result.to = trim(mid(maildetails, pos.pos[2], pos.len[2]))>
		</cfif>
		<!--- get the sent date --->
		<cfset result.sent = fileLastModified("#VARIABLES.maildir#/#ARGUMENTS.EmailFile#")>

		<cfreturn result>
	</cffunction>

	<cffunction name="fileLastModified" output="false" returnType="string" hint="Gets the file creation date">
		<cfargument name="EmailFile" type="string" required="true">

		<cfset var _File =  CreateObject("java","java.io.File")>
		<cfset var _Offset = ((GetTimeZoneInfo().utcHourOffset)+1)*-3600>
		<cfset _File.init(JavaCast("string", EmailFile))>

		<cfreturn DateAdd('s', (Round(_File.lastModified()/1000))+_Offset, CreateDateTime(1970, 1, 1, 0, 0, 0))>
	</cffunction>

	<cffunction name="updateRecord" output="true" returnType="numeric" hint="Determines whether this email (EmailFile) is already in the database">
		<cfargument name="filedetails" type="struct" required="true">
		<cfset var checkFile = "" />
		<cfset var insertRecord = "" />
		<cfset var updateRecord = "" />
		<!--- check for an existing record  --->
		<cfquery name="checkFile" datasource="#VARIABLES.DSN#">
			SELECT ID, attempts
			FROM Undelivrnator
			WHERE EmailFile = <cfqueryparam value="#Trim(ARGUMENTS.filedetails.EmailFile)#" cfsqltype="CF_SQL_VARCHAR">
			AND Server = <cfqueryparam value="#VARIABLES.server#" cfsqltype="CF_SQL_VARCHAR">
		</cfquery>
		<cfset VARIABLES.attempts = checkFile.attempts>

		<!--- if there is one --->
		<cfif VARIABLES.attempts IS "">
			<!--- and there's not, then we insert a record --->
			<cfquery name="insertRecord" datasource="#VARIABLES.DSN#">
				INSERT INTO Undelivrnator (
					EmailFile,
					ToAddress,
					FromAddress,
					SentDate,
					Attempts,
					Server)
				VALUES (
					'#Trim(ARGUMENTS.filedetails.EmailFile)#',
					'#Left(Trim(ARGUMENTS.filedetails.ToAddress),100)#',
					'#Left(Trim(ARGUMENTS.filedetails.FromAddress),100)#',
					#ARGUMENTS.filedetails.SentDate#,
					1,
					'#VARIABLES.server#')
			</cfquery>
			<!--- and we mark attempts as 1 --->
			<cfset VARIABLES.attempts = 1>
		<cfelseif VARIABLES.attempts LT  VARIABLES.timesToTry>
			<!--- and there is, then we update the record --->
			<cfquery name="updateRecord" datasource="#VARIABLES.DSN#">
				UPDATE Undelivrnator
				SET attempts = attempts + 1
				WHERE ID = <cfqueryparam value="#checkFile.ID#" cfsqltype="CF_SQL_INTEGER">
				AND Server = <cfqueryparam value="#VARIABLES.server#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
		</cfif>

		<cfreturn VARIABLES.attempts>
	</cffunction>

	<cffunction name="deleteOldRecords" output="false" returnType="void" hint="Deletes records older than a specified date">
		<cfset var deleteOldEmails = "" />
		<!--- check for an existing record  --->
		<cfquery name="deleteOldEmails" datasource="#VARIABLES.DSN#">
			DELETE
			FROM Undelivrnator
			WHERE SentDate < (GETDATE() - <cfqueryparam value="#VARIABLES.deletetimeframe#" cfsqltype="cf_sql_integer">)
		</cfquery>

	</cffunction>

	<cffunction name="moveEmail" output="false" returnType="void" hint="Moves the email file from the Undelivr folder into the Spool folder">
		<cfargument name="EmailFile" type="string" required="true">
		<cfargument name="from" type="string" required="true">
		<cfargument name="to" type="string" required="true">
		<cffile action="move" source="#ARGUMENTS.from#/#EmailFile#" destination="#ARGUMENTS.to#/#EmailFile#">
	</cffunction>

	<cffunction name="deleteEmail" output="false" returnType="void" hint="Deletes the email file">
		<cfargument name="EmailFile" type="string" required="true">
		<cfargument name="from" type="string" required="true">
		<cffile action="delete" file="#ARGUMENTS.from#/#EmailFile#">
	</cffunction>

</cfcomponent>