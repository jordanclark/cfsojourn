<cfcomponent output="false">


<cffunction name="init" output="false">
	<cfargument name="tokenEncode" type="string" default="new">
	<cfargument name="tokenType" type="string" default="CF"><!--- uuid --->
	<cfargument name="importScopes" type="string" default="cookie,url">
	<cfargument name="autoSave" type="boolean" default="false">
	<cfargument name="cookieName" type="string" default="token">
	<cfargument name="cookiesExpire" type="string" default="120">
	<cfargument name="debug" type="boolean" default="false">
	
	<cfset structAppend( this, arguments, true )>
	
	<cfset this.debugLog( "Init" )>
	<!--- <cfset this.debugLog( arguments )> --->
	
	<cfset application.sojourn = this>
	
	<cfreturn this>
</cffunction>


<cffunction name="debugLog" access="public" output="false">
	<cfargument name="input" type="any" required="true">
	
	<cfif structKeyExists( request, "log" ) AND isCustomFunction( request.log )>
		<cfif isSimpleValue( arguments.input )>
			<cfset request.log( "Sojourn: " & arguments.input )>
		<cfelse>
			<cfset request.log( "Sojourn: (complex type)" )>
			<cfset request.log( arguments.input )>
		</cfif>
	<cfelse>
		<cftrace
			type="information"
			category="Sojourn"
			text="#( isSimpleValue( arguments.input ) ? arguments.input : "" )#"
			var="#arguments.input#"
		>
	</cfif>
	
	<cfreturn>
</cffunction>


<cffunction name="visitKill" output="false" returnType="boolean">
	<cfthrow message="The visitKill method must be overwritten">
</cffunction>


<cffunction name="visitLoad" output="false" returnType="boolean">
	<cfthrow message="The visitLoad method must be overwritten">
</cffunction>


<cffunction name="visitSave" output="false" returnType="boolean">
	<cfthrow message="The visitSave method must be overwritten">
</cffunction>


<cffunction name="isBot" access="public" output="false" returnType="boolean">
	<cfif reFind( "(googlebot|slurp|msnbot|jeeves/teoma|scooter)", lCase( cgi.http_user_agent ) )>
		<cfreturn true>
	</cfif>
	<cfreturn false>
</cffunction>


<cffunction name="isValidToken" access="public" output="false" returnType="boolean">
	<cfargument name="token" type="string" required="true">
	
	<cfif arguments.token IS "false" OR listLen( arguments.token, ":" ) IS NOT 3>
		<cfreturn false>
	</cfif>
	
	<cfif listGetAt( arguments.token, 2, ":" ) IS NOT lCase( left( hash( listGetAt( arguments.token, 1, ":" ) ), 4 ) )>
		<!--- ignore user agent hash:  OR listGetAt( arguments.token, 3, ":" ) IS NOT lCase( left( hash( cgi.http_user_agent ), 4 ) ) --->
		<cfreturn false>
	</cfif>
	
	<cfreturn true>
</cffunction>


<cffunction name="isOldToken" access="public" output="false" returnType="boolean">
	<cfargument name="token" type="string" required="true">
	
	<cfif arguments.token IS "false">
		<cfreturn false>
	</cfif>
	
	<cftry>
		<cfset arguments.token = listFirst( arguments.token, "|" )>
		<!--- ignore user agent hash: ( cgi.http_user_agent IS "" OR left( arguments.token, 4 ) IS "!!!!" OR left( arguments.token, 4 ) IS left( hash( cgi.http_user_agent ), 4 ) ) --->
		<cfreturn right( arguments.token, 4 ) IS left( hash( mid( arguments.token, 5, len( arguments.token ) - 8 ) ), 4 )>
		<cfcatch></cfcatch>
	</cftry>
	
	<cfreturn false>
</cffunction>


<cffunction name="visitStart" access="public" output="false"
	hint="Run this in onRequest or onRequestStart"
>
	<cfargument name="autoReady" type="boolean" default="false">
	
	<cfset this.debugLog( "Visit Start" )>
	
	<cfset request.visit = {
		haveCookies = structKeyExists( cookie, this.cookieName )
	,	token = request.visit.token
	,	data = {}
	,	loaded = false
	,	stored = false
	,	modified = false
	,	haveData = this.haveData
	,	haveToken = this.haveToken
	,	set = this.visitDataSet
	,	remove = this.visitDataRemove
	,	exists = this.visitDataExists
	,	get = this.visitDataGet
	,	save = this.visitSave
	,	load = this.visitLoad
	,	kill = this.visitKill
	,	ready = this.ready
	}>
	
	<!--- <cfset request.visit.ready().data = { fname= "Jordan", lname = "Clark" }> --->
	
	<cfif this.isBot()>
		<cfreturn>
	</cfif>
	
	<cfset this.importToken()>
	
	<cfif arguments.autoReady>
		<cfset this.debugLog( "Auto-ready data" )>
		<cfset request.visit.load()>
	</cfif>
</cffunction>


<cffunction name="visitEnd" access="public" output="false"
	hint="Run this in onRequestEnd or onError"
>
	<cfset this.debugLog( "Visit End." )>
	
	<cftry>
		<cfset request.visit.save()>
		<cfcatch>
			<cfset this.debugLog( "Failed to save data" )>
			<cfset this.debugLog( cfcatch )>
		</cfcatch>
	</cftry>
	
	<cfset this.debugLog( "Bake cookie #this.cookieName# = #request.visit.token#" )>
	
	<cfcookie
		name="#this.cookieName#"
		value="#request.visit.token#"
		httpOnly="true"
		expires="#this.cookiesExpire#"
	>
</cffunction>


<cffunction name="newToken" access="public" output="false" returnType="string">
	<cfif this.tokenType IS "CF">
		<cfreturn randRange( 100000, 99999999 ) &"-"& randRange( 100000, 99999999 )>
	</cfif>
	
	<cfreturn createUUID()>
</cffunction>



<!--- REQUEST.VISIT FLY WEIGHT METHODS --->


<cffunction name="ready" access="public" output="false">
	<cfif NOT request.visit.loaded>
		<cfset request.visit.load()>
	</cfif>
	
	<cfreturn request.visit>
</cffunction>


<cffunction name="haveData" access="public" output="false" returnType="boolean">
	<cfreturn NOT structIsEmpty( request.visit.data )>
</cffunction>


<cffunction name="haveToken" access="public" output="false" returnType="boolean">
	<cfreturn len( request.visit.token ) ? true : false>
</cffunction>


<cffunction name="setToken" access="public" output="false" returnType="string">
	<cfargument name="token" type="string" default="">
	<cfargument name="userAgent" type="string" default="#cgi.http_user_agent#">
	
	<cfif NOT len( arguments.token )>
		<cfset arguments.token = this.newToken()>
	</cfif>

	<cfset var agentHash = "0000">
	<cfif arguments.userAgent IS "!!!!" OR arguments.userAgent IS "FAKE">
		<cfset agentHash = "!!!!">
	<cfelseif len( arguments.userAgent )>
		<cfset agentHash = left( hash( arguments.userAgent ), 4 )>
	</cfif>
	
	<!--- <cfset this.debugLog( "Set token: #arguments.token#" )> --->
	
	<cfif this.tokenEncode IS "old">
		<cfset var cfid = listGetAt( arguments.token, 1, "-" )>
		<cfset var cftoken = listGetAt( arguments.token, 2, "-" )>
		<cfset request.visit.token = uCase( agentHash ) &
			min( len( cfid ), 9 ) &
			left( cfid, 9 ) &
			min( len( cftoken ), 9 ) &
			left( cftoken, 9 ) & 
			uCase( left( hash( len( cfid ) & cfid & len( cftoken ) & cftoken ), 4 ) )>
	<cfelse><!--- new --->
		<cfset request.visit.token = arguments.token & ":" &
			lCase( left( hash( arguments.token ), 4 ) ) & ":" &
			lCase( agentHash )
		>
	</cfif>

</cffunction>


<cffunction name="newVisit" access="public" output="false">
	<cfset application.sojourn.debugLog( "New Visit old[#request.visit.token#]" )>
	
	<cfset this.setToken( this.newToken() )>
</cffunction>


<cffunction name="visitDataSet" access="public" output="false">
	<cfargument name="name" type="variableName">
	<cfargument name="value" type="any">
	
	<cfset arguments.name = uCase( arguments.name )>
	
	<cfset application.sojourn.debugLog( "Data set #arguments.name#" )>
	
	<cfif NOT request.visit.loaded>
		<!--- lazy load --->
		<cfset application.sojourn.debugLog( "Lazy Load" )>
		<cfset request.visit.load()>
	</cfif>
	
	<cfif NOT structKeyExists( request.visit.data, arguments.name ) OR request.visit.data[ arguments.name ] IS NOT arguments.value>
		<cfset request.visit.data[ arguments.name ] = arguments.value>
		<cfset request.visit.modified = true>
	</cfif>
	
	<cfif application.sojourn.autoSave>
		<cfset application.sojourn.debugLog( "Auto save" )>
		<cfset request.visit.save( fireAndForget= true )>
	</cfif>
</cffunction>


<cffunction name="visitDataRemove" access="public" output="false">
	<cfargument name="name" type="variableName">
	
	<cfset application.sojourn.debugLog( "Data remove #arguments.name#" )>
	
	<cfif NOT request.visit.loaded>
		<!--- lazy load --->
		<cfset application.sojourn.debugLog( "Lazy Load" )>
		<cfset request.visit.load()>
	</cfif>
	
	<cfif structKeyExists( request.visit.data, arguments.name )>
		<cfset structDelete( request.visit.data, arguments.name )>
		<cfset request.visit.modified = true>
	</cfif>
	
	<cfif application.sojourn.autoSave>
		<cfset application.sojourn.debugLog( "Auto save" )>
		<cfset request.visit.save( fireAndForget= true )>
	</cfif>
</cffunction>


<cffunction name="visitDataExists" access="public" output="false" returnType="boolean">
	<cfargument name="name" type="variableName">
	
	<cfset application.sojourn.debugLog( "Data exists #arguments.name#" )>
	
	<cfif NOT request.visit.loaded>
		<!--- lazy load --->
		<cfset application.sojourn.debugLog( "Lazy Load" )>
		<cfset request.visit.load()>
	</cfif>
	
	<cfreturn structKeyExists( request.visit.data, arguments.name )>
</cffunction>


<cffunction name="visitDataGet" access="public" output="false">
	<cfargument name="name" type="variableName">
	<cfargument name="default" required="false">
	
	<cfset application.sojourn.debugLog( "Data get #arguments.name#" )>
	
	<cfif NOT request.visit.loaded>
		<!--- lazy load --->
		<cfset application.sojourn.debugLog( "Lazy Load" )>
		<cfset request.visit.load()>
	</cfif>
	
	<cfif NOT structKeyExists( request.visit.data, arguments.name ) AND structKeyExists( arguments, "default" )>
		<cfreturn arguments.default>
	</cfif>
	
	<cfreturn request.visit.data[ arguments.name ]>
</cffunction>


<cffunction name="importToken" access="public" output="false">
	<cfset var local = {}>
	<cfset local.token = "">
	
	<cfset this.debugLog( "Importing tokens" )>
	
	<cfloop index="local.index" list="#this.importScopes#">
		<cfset local.scope = evaluate( local.index )>
		<cfset this.debugLog( "Searching #uCase( local.index )# scope" )>
		
		<cfif structKeyExists( local.scope, this.cookieName ) AND len( local.scope[ this.cookieName ] )>
			<cfset local.token = urlDecode( local.scope[ this.cookieName ] )>
			<cfif this.isOldToken( local.token )>
				<!--- get the id --->
				<cfset local.cfid = mid( local.token, 2, left( local.token, 1 ) )>
				<!--- get the token + length --->
				<cfset local.cftoken = right( local.token, len( local.token ) - len( local.cfid ) - 1 )>
				<!--- get the token --->
				<cfset local.cftoken = mid( local.cftoken, 2, left( local.cftoken, 1 ) )>
				<!--- <cfset local.token = local.cfid &"-"& local.cftoken> --->
				<cfset this.debugLog( "Found #uCase(local.index)#.#uCase(this.cookieName)#: cfid[#local.cfid#] cftoken[#local.cftoken#]" )>
				<cfbreak>
			<cfelseif this.isValidToken( local.token )>
				<!--- trim off the useragent hash --->
				<cfset local.token = listFirst( local.token, ":" )>
				<cfset this.debugLog( "Found #uCase(local.index)#.#uCase(this.cookieName)# [#local.token#]" )>
				<cfbreak>
			<cfelse>
				<cfset this.debugLog( "Invalid token '#this.cookieName#' [#local.token#] from #lCase(local.index)#" )>
				<cfset local.token = "">
			</cfif>
		</cfif>
	</cfloop>
	
	<cfif len( local.token )>
		<cfset this.setToken( local.token )>
	<cfelse>
		<cfset this.debugLog( "NO token found!" )>
	</cfif>
</cffunction>


</cfcomponent>