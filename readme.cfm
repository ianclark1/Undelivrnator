<!--- 
	The code found below is simply one way of using Undelivrnator. The only
	requirements are the parameters in the init() method and the run method.
	Everything else can be used or not at your discretion.

	Currently Undelivrnator requires a database connection, and a table in said
	database named "Undelivrnator". A schema can be found included in this
	zip file with a create table statement for this table.
--->

<!--- set the start time --->
<cfset VARIABLES.startTick = GetTickCount()>

<!--- set the beginning log file title --->
<cfset VARIABLES.logEntryTitle = "Undelivernator run STARTING: #Now()#">

<!--- log the start time --->
<cflog file="DailyUndelivernatorRun" type="information" text="#VARIABLES.logEntryTitle#">

<!--- Instantiate the Undelivernator CFC --->
<cfset VARIABLES.Undelivernator = CreateObject("component", "Undelivernator").init(
	DSN='Dealerskinsversion2',
	serverRoot=SERVER.coldfusion.rootdir,
	serverid='S1',
	timesToTry=3,
	deleteTimeFrame=90
)>

<!--- Run Undelivernator --->
<cfset VARIABLES.UndelivernatorStatus = VARIABLES.Undelivernator.run()>

<!--- Did Undelivernator run successfully --->
<!--- set final log entry title --->
<cfset VARIABLES.logEntryTitle = Iif(VARIABLES.UndelivernatorStatus,De("Undelivernator run finished successfully:"),De("Undelivernator run failed:"))>

<!--- set the end time --->
<cfset VARIABLES.endTick = GetTickCount()>

<!--- set the closing log file title --->
<cfset VARIABLES.logEntryTitle = VARIABLES.logEntryTitle & " #Now()# in #VARIABLES.endTick - VARIABLES.startTick# ms">

<!--- log the end time, and status --->
<cflog file="DailyUndelivernatorRun" type="information" text="#VARIABLES.logEntryTitle#">

<!--- output the status --->
<cfoutput>#VARIABLES.logEntryTitle#</cfoutput>