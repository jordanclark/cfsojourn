<cfcomponent output="false" extends="sojournFlyweight">


<cffunction name="init" output="false">
	<cfargument name="mongo" type="any" required="true">
	<cfargument name="tokenName" type="string" default="token">
	<cfargument name="tokenType" type="string" default="CF"><!--- uuid --->
	<cfargument name="importScopes" type="string" default="cookie,url">
	<cfargument name="expireHours" type="numeric" default="720"><!--- 30 days --->
	<cfargument name="timeOutMins" type="numeric" default="30">
	<cfargument name="autoSave" type="boolean" default="false">
	<cfargument name="cookiesExpire" type="string" default="120">
	<cfargument name="lastVisit" type="boolean" default="false">
	<cfargument name="hitCount" type="boolean" default="false">
	
	<cfif arguments.expireHours GT 0 OR arguments.timeOutMins GT 0>
		<cfset arguments.lastVisit = true>
	</cfif>
	
	<cfset super.init( argumentCollection = arguments )>
	
	<cfset this.mongo = arguments.mongo>
	
	<cfreturn this>
</cffunction>


<cffunction name="purgeExpired" output="false" access="public">
	<cfargument name="age" type="numeric" default="#this.expireHours#">
	
	<cfset this.debugLog( "Mongo try killing expired data" )>
	
	<cftimer label="Mongo remove expired" type="debug">
		<cfset this.debugLog( "Mongo remove expired" )>
		<cfset this.mongo.remove( { "LASTVISIT"= { "$lt"= dateAdd( "D", -1 * arguments.age, now() ) } } )>
	</cftimer>
</cffunction>


<!--- REQUEST.VISIT FLY WEIGHT METHODS --->

<cffunction name="visitKill" output="false" access="public">
	<cfset var local = {}>
	
	<cfset application.sojourn.debugLog( "Mongo try killing data: #request.visit.token#" )>
	
	<cfif len( request.visit.token )>
		<!--- kill records in mongodb --->
		<cftimer label="Mongo removeByID" type="debug">
			<cfset application.sojourn.debugLog( "Mongo removeByID" )>
			<cfset local.result = application.sojourn.mongo.removeByID( listFirst( request.visit.token, ":" ) )>
		</cftimer>
	</cfif>
	
	<!--- reset local cache & toggles --->
	<cfset request.visit.data = {}>
	<cfset request.visit.stored = false>
	<cfset request.visit.modified = false>
	<cfset request.visit.loaded = false>
	<cfset request.visit.token = "">
	<cfset request.visit[ application.sojourn.tokenName ] = "">
</cffunction>


<cffunction name="visitLoad" output="false" returnType="boolean">
	<cfargument name="force" type="boolean" default="false">
	
	<cfset var local = {}>
	
	<cfset application.sojourn.debugLog( "Mongo try loading data: #request.visit.token#" )>
	
	<cfif NOT arguments.force AND request.visit.loaded AND request.visit.modified AND NOT request.visit.stored>
		<!--- save changes before loading new data --->
		<cfset application.sojourn.debugLog( "save changes before loading new data" )>
		<cfset request.visit.save()>
	</cfif>
	
	<cfif NOT request.visit.loaded OR arguments.force>
		<cfset request.visit.data = {}>
		<cfset request.visit.stored = false>
		<cfset request.visit.modified = false>
		<cfset request.visit.loaded = false>
		<cfif NOT len( request.visit.token )>
			<!--- create new tokens --->
			<cfset request.visit.loaded = true>
			<cfset application.sojourn.newVisit()>
		<cfelse>
			<!--- load data from mongodb --->
			<cftimer label="Mongo findByID" type="debug">
				<cfset application.sojourn.debugLog( "Mongo findByID" )>
				<cfset request.visit.data = application.sojourn.mongo.findById( listFirst( request.visit.token, ":" ) )>
			</cftimer>
			<cfset request.visit.stored = true>
			<cfset request.visit.loaded = true>
		</cfif>
		
		<cfif isNull( request.visit.data ) OR structIsEmpty( request.visit.data )>
			<cfset application.sojourn.debugLog( "No data found, start fresh" )>
			<cfset request.visit.data = { "_id"= listFirst( request.visit.token, ":" ) }>
		</cfif>
		
		<!--- this automatic manipulations are done manually so autoSave won't send an additional update
			the data will be saved at the end of the request with any other real data --->
		<cfif application.sojourn.lastVisit>
			<cfif structKeyExists( request.visit.data, "LASTVISIT" )>
				<!--- check if data is too old to use --->
				<cfif application.sojourn.expireHours GT 0 AND dateDiff( "H", request.visit.data.lastVisit, now() ) GT application.sojourn.expireHours>
					<cfset application.sojourn.debugLog( "Data has expired" )>
					<cfset request.visit.data = { "_id"= listFirst( request.visit.token, ":" ) }>
				</cfif>
				<!--- timeout a session if its been idle too long, this is good to re-auth without losing data --->
				<cfif application.sojourn.timeOutMins GT 0 AND dateDiff( "N", request.visit.data.lastVisit, now() ) GT application.sojourn.timeOutMins>
					<cfset application.sojourn.debugLog( "Session has timed out" )>
					<cfset request.visit.data[ "TIMEOUT" ] = true>
					<cfset request.visit.modified = true>
				</cfif>
			</cfif>
		</cfif>
		<cfif application.sojourn.hitCount>
			<cfset request.visit.data[ "HITS" ] = ( structKeyExists( request.visit.data, "HITS" ) ? request.visit.data.hits : 0 ) + 1>
			<cfset request.visit.modified = true>
		</cfif>
	</cfif>
	
	<cfreturn request.visit.loaded>
</cffunction>


<cffunction name="visitSave" output="false">
	<cfargument name="force" type="boolean" default="false">
	<cfargument name="fireAndForget" type="boolean" default="false">
	
	<cfset var local = {}>
	
	<cfset application.sojourn.debugLog( "Mongo try saving data" )>
	
	<cftry>
		<cfif arguments.force OR request.visit.modified OR NOT structIsEmpty( request.visit.data )>
		
			<cfif NOT len( request.visit.token )>
				<cfset application.sojourn.newVisit()>
			</cfif>
			
			<!--- this automatic manipulations are done only if we have data so every request doesn't end up making a session --->
			<cfif application.sojourn.lastVisit>
				<cfset request.visit.data[ "LASTVISIT" ] = now()>
				<cfset request.visit.modified = true>
			</cfif>
			
			<!--- <cfif structKeyExists( request.visit.data, "updated" ) AND abs( dateDiff( "n", request.visit.data.updated, request.now ) ) GT application.sojourn.expire>
				<!--- "session" is expired, so remove checkout and flag it as expired --->
				<cfset request.visit.remove( "checkout" )>
				<cfset request.visit.set( "expired", true )>
			</cfif>
			<cfif structKeyExists( request.visit.data, "checkout" ) AND request.visit.data.checkout.complete AND abs( dateDiff( "n", request.visit.data.checkout.datestamp, request.now ) ) GT 60>
				<!--- remove completed checkout --->
				<cfset request.visit.remove( "checkout" )>
			</cfif> --->
			
			<cfif arguments.force OR request.visit.modified>
				<!--- save data to mongodb --->
				<cftimer label="Mongo upsert" type="debug">
					<cfset application.sojourn.debugLog( "Mongo upsert" )>
					<cfif arguments.fireAndForget>
						<cfset local.result = application.sojourn.mongo.update( doc= request.visit.data, upsert= true, concern= "NONE" )>
					<cfelse>
						<cfset local.result = application.sojourn.mongo.update( doc= request.visit.data, upsert= true, concern= "SAFE" )>
						<cfset local.lastError = local.result.getLastError()>
						<cfif NOT local.lastError[ "ok" ]>
							<cfthrow message="Mongo error saving">
						<cfelseif local.lastError[ "n" ] LTE 0>
							<cfset application.sojourn.debugLog( "Mongo error: no records modified" )>
						</cfif>
					</cfif>
				</cftimer>
			</cfif>
			
			<cfset request.visit.modified = false>
			<cfset request.visit.stored = true>
		</cfif>
		<cfcatch>
			<cfif NOT arguments.fireAndForget>
				<cfset request.visit.stored = false>
				<cfrethrow>
			</cfif>
		</cfcatch>
	</cftry>
	
	<cfreturn local>
</cffunction>


</cfcomponent>