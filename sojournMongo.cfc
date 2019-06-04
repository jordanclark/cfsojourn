<cfcomponent output="false" extends="sojourn">


<cffunction name="init" access="public" output="false">
	<cfargument name="mongoCollection" type="any" required="true">
	<cfargument name="writeConcern" type="string" default="SAFE">
	<cfargument name="tokenName" type="string" default="token">
	<cfargument name="tokenType" type="string" default="CF"><!--- uuid --->
	<cfargument name="importScopes" type="string" default="cookie,url">
	<cfargument name="expireHours" type="numeric" default="1440"><!--- 60 days --->
	<cfargument name="timeOutMins" type="numeric" default="30">
	<cfargument name="autoSave" type="boolean" default="false">
	<cfargument name="cookiesExpire" type="string" default="120">
	<cfargument name="lastVisit" type="boolean" default="false">
	<cfargument name="hitCount" type="boolean" default="false">
	<cfargument name="retryCount" type="numeric" default="1">
	
	<cfif arguments.expireHours GT 0 OR arguments.timeOutMins GT 0>
		<cfset arguments.lastVisit = true>
	</cfif>
	
	<cfset super.init( argumentCollection = arguments )>
	
	<cfset this.mongoCollection = arguments.mongoCollection>
	<cfset this.mongoCollection.setWriteConcern( arguments.writeConcern )>
	<cfset this.writeConcern = arguments.writeConcern>
	
	<cfreturn this>
</cffunction>


<cffunction name="purgeExpired" access="public" output="false">
	<cfargument name="age" type="numeric" default="#this.expireHours#">
	
	<cfset var attempt = 0>
	
	<cfloop index="attempt" from="1" to="#( this.retryCount + 1 )#" step="1">
		<cftry>
			<!--- kill records in mongodb --->
			<cftimer label="Mongo expired data [#attempt#]" type="debug">
				<cfset debugLog( "Mongo expired data [#attempt#]" )>
				<cfset var result = this.mongoCollection.remove( doc= { "LASTVISIT"= { "$lt"= dateAdd( "H", -1 * arguments.age, now() ) } }, concern= this.writeConcern )>
				<cfset debugLog( results )>
				<cfif NOT result[ "ok" ]>
					<cfthrow message="Mongo error removing: #result.errmsg#">
				<!--- <cfelseif lastError[ "n" ] LTE 0>
					<cfset debugLog( "Mongo error: no records modified" )> --->
				</cfif>
			</cftimer>
			
			<cfbreak><!--- don't try again --->
			
			<cfcatch>
				<cfif attempt IS ( this.retryCount + 1 )>
					<!--- retry for "can't call something" --->
					<cfrethrow>
				</cfif>
			</cfcatch>
		</cftry>
	</cfloop>

</cffunction>


<cffunction name="visitKill" access="public" output="false" returnType="boolean">
	<cfargument name="visit" type="sojournVisit" required="true">
	
	<cfset var v = arguments.visit>
	<cfset var attempt = 0>
	
	<cfif len( v.token )>
		<cfloop index="attempt" from="1" to="#( this.retryCount + 1 )#" step="1">
			<cftry>
				<!--- kill records in mongodb --->
				<cftimer label="Mongo removeByID: #v.token# [#attempt#]" type="debug">
					<cfset debugLog( "Mongo removeByID: #v.token# [#attempt#]" )>
					<cfif this.writeConcern IS "NONE">
						<cfset var result = this.mongoCollection.removeByID( id= listFirst( v.token, ":" ), concern= "NONE" )>
						<cfset debugLog( result )>
					<cfelse>
						<cfset var result = this.mongoCollection.removeByID( id= listFirst( v.token, ":" ), concern= this.writeConcern )>
						<cfset debugLog( results )>
						<cfif NOT result[ "ok" ]>
							<cfthrow message="Mongo error removing: #result.errmsg#">
						<!--- <cfelseif lastError[ "n" ] LTE 0>
							<cfset debugLog( "Mongo error: no records modified" )> --->
						</cfif>
					</cfif>
				</cftimer>
				
				<cfbreak><!--- don't try again --->
				
				<cfcatch>
					<cfif attempt IS ( this.retryCount + 1 )>
						<!--- retry for "can't call something" --->
						<cfrethrow>
					</cfif>
				</cfcatch>
			</cftry>
		</cfloop>
	</cfif>
	
	<!--- reset local cache & toggles --->
	<cfset v.data = {}>
	<cfset v.stored = false>
	<cfset v.modified = false>
	<cfset v.loaded = false>
	<cfset v.token = "">
	
	<cfreturn true>
</cffunction>


<cffunction name="visitLoad" access="public" output="false" returnType="boolean">
	<cfargument name="visit" type="sojournVisit" required="true">
	<cfargument name="force" type="boolean" default="false">
	
	<cfset var v = arguments.visit>
	<cfset var attempt = 0>
	
	<cfif NOT v.loaded OR arguments.force>
		<cfloop index="attempt" from="1" to="#( this.retryCount + 1 )#" step="1">
			<cfset debugLog( "Mongo try loading data: #v.token# [#attempt#]" )>
			<cftry>
				<cfset v.data = {}>
				<cfset v.stored = false>
				<cfset v.modified = false>
				<cfset v.loaded = false>
				<cfif NOT len( v.token )>
					<!--- create new tokens --->
					<cfset v.loaded = true>
					<cfset v.newVisit()>
				<cfelse>
					<!--- load data from mongodb --->
					<cftimer label="Mongo findByID" type="debug">
						<cfset debugLog( "Mongo findByID" )>
						<cfset v.data = this.mongoCollection.findById( listFirst( v.token, ":" ) )>
					</cftimer>
					<cfset v.stored = true>
					<cfset v.loaded = true>
				</cfif>
				
				<cfif isNull( v.data ) OR structIsEmpty( v.data )>
					<cfset debugLog( "No data found, start fresh" )>
					<cfset v.data = { "_id"= listFirst( v.token, ":" ) }>
				</cfif>
				
				<cfbreak><!--- don't try again --->
				
				<cfcatch>
					<cfset v.loaded = false>
					<cfif attempt IS ( this.retryCount + 1 )>
						<!--- retry for "can't call something" --->
						<cfrethrow>
					</cfif>
				</cfcatch>
			</cftry>
		</cfloop>
		
		<!--- manipulate data as an extension point for more tweaking --->
		<cfset afterLoad( v )>
	</cfif>
	
	<cfreturn v.loaded>
</cffunction>


<cffunction name="visitSave" access="public" output="false">
	<cfargument name="visit" type="sojournVisit" required="true">
	<cfargument name="force" type="boolean" default="false">
	<cfargument name="autoSave" type="boolean" default="false">
	
	<cfset var v = arguments.visit>
	<cfset var attempt = 0>
	
	<cfif arguments.force OR v.modified><!---  OR v.haveData() --->
		<cfloop index="attempt" from="1" to="#( this.retryCount + 1 )#" step="1">
			<cfset debugLog( "Mongo try saving data [#attempt#]" )>
			<cftry>
				<cfif NOT len( v.token )>
					<cfset v.newVisit()>
				</cfif>
				
				<!--- manipulate data as an extension point before saving --->
				<cfset beforeSave( v )>
				
				<cfif arguments.force OR v.modified>
					<!--- save data to mongodb --->
					<cftimer label="Mongo upsert" type="debug">
						<cfset debugLog( "Mongo upsert [#this.writeConcern#]" )>
						<cfif arguments.autoSave OR this.writeConcern IS "NONE">
							<cfset var result = this.mongoCollection.update( doc= v.data, upsert= true, concern= "NONE" )>
							<cfset debugLog( result )>
						<cfelse>
							<cfset var result = this.mongoCollection.update( doc= v.data, upsert= true, concern= this.writeConcern )>
							<cfset debugLog( result )>
							<cfif NOT result[ "ok" ]>
								<cfthrow message="Mongo error saving: #result.errmsg#">
							</cfif>
						</cfif>
					</cftimer>
				</cfif>
				
				<cfset v.modified = false>
				<cfset v.stored = true>
				<cfbreak><!--- don't try again --->
				
				<cfcatch>
					<cfset v.stored = false>
					<cfif NOT arguments.autoSave OR attempt IS ( this.retryCount + 1 )>
						<!--- retry for "can't call something" --->
						<cfrethrow>
					</cfif>
				</cfcatch>
			</cftry>
		</cfloop>
	</cfif>
	
	<cfreturn v.stored>
</cffunction>


<cffunction name="afterLoad" access="public" output="false">
	<cfargument name="visit" type="sojournVisit" required="true">
	
	<cfset var v = arguments.visit>
	
	<!--- this automatic manipulations are done manually so autoSave won't send an additional update
		the data will be saved at the end of the request with any other real data --->
	<cfif this.lastVisit>
		<cfif structKeyExists( v.data, "LASTVISIT" )>
			<cfset debugLog( "LAST VISIT: #v.data[ 'LASTVISIT' ]#" )>
			<!--- check if data is too old to use --->
			<cfif this.expireHours GT 0 AND dateDiff( "H", v.data[ "LASTVISIT" ], now() ) GT this.expireHours>
				<cfset debugLog( "Data has expired: " & dateDiff( "H", v.data[ "LASTVISIT" ], now() ) )>
				<cfset v.data = {	
					"_id"= listFirst( v.token, ":" ),
					"EXPIRED"= true,
					"TIMEOUT"= true
				}>
				<cfset v.modified = true>
			<!--- timeout a session if its been idle too long, this is good to re-auth without losing data --->
			<cfelseif this.timeOutMins GT 0 AND dateDiff( "N", v.data[ "LASTVISIT" ], now() ) GT this.timeOutMins>
				<cfset debugLog( "Session has timed out" )>
				<cfset v.data[ "TIMEOUT" ] = true>
				<cfset v.modified = true>
			</cfif>
		</cfif>
	</cfif>
	<cfif this.hitCount>
		<cfset v.data[ "HITS" ] = ( structKeyExists( v.data, "HITS" ) ? v.data.hits : 0 ) + 1>
		<cfset v.modified = true>
	</cfif>
	
	<cfreturn>
</cffunction>


<cffunction name="beforeSave" access="public" output="false">
	<cfargument name="visit" type="sojournVisit" required="true">
	
	<cfset var v = arguments.visit>
	
	<!--- this automatic manipulations are done only if we have data so every request doesn't end up making a session --->
	<cfif this.lastVisit>
		<cfset v.data[ "LASTVISIT" ] = now()>
		<cfset v.modified = true>
	</cfif>
	
	<!--- unfuck the data first --->
	<cftimer label="Mongo CF unfuck" type="debug">
		<cfset v.data = deserializeJSON( serializeJSON( v.data ) )>
	</cftimer>
	
	<cfreturn>
</cffunction>


</cfcomponent>