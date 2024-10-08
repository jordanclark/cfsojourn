<cfcomponent output="false">


<cffunction name="init" output="false">
	<cfargument name="tokenType" type="string" default="CF"><!--- uuid --->
	<cfargument name="importScopes" type="string" default="cookie,url">
	<cfargument name="autoSave" type="boolean" default="false">
	<cfargument name="cookieName" type="string" default="token">
	<cfargument name="cookiesExpire" type="string" default="120">
	<cfargument name="debug" type="boolean" default="false">
	
	<cfset structAppend( this, arguments, true )>
	
	<cfset this.debugLog( "Init" )>
	
	<cfreturn this>
</cffunction>


<cffunction name="debugLog" access="public" output="false">
	<cfargument name="input" type="any" required="true">
	
	<cfif NOT this.debug>
		<cfreturn>
	</cfif>

	<cfif structKeyExists( request, "log" ) AND isCustomFunction( request.log )>
		<cfif isSimpleValue( arguments.input )>
			<cfset request.log( "sojourn: " & arguments.input )>
		<cfelse>
			<cfset request.log( "sojourn: (complex type)" )>
			<cfset request.log( arguments.input )>
		</cfif>
	<cfelse>
		<cftrace
			type="information"
			category="sojourn"
			text="#( isSimpleValue( arguments.input ) ? arguments.input : "" )#"
			var="#arguments.input#"
		>
	</cfif>
	
	<cfreturn>
</cffunction>


<cffunction name="visitStart" access="public" output="false" returnType="sojournVisit"
	hint="Run this in onRequest or onRequestStart"
>
	<cfargument name="autoReady" type="boolean" default="false">
	<cfargument name="token" type="string" default="">
	
	<cfset this.debugLog( "visit start: autoReady[#arguments.autoReady#]" )>
	
	<cfif NOT len( arguments.token )>
		<cfset arguments.token = this.importToken()>
	</cfif>
	<cfset var visit = new sojournVisit( this, arguments.token, NOT structIsEmpty( cookie ) )>
	
	<cfif NOT this.isBot() AND len( arguments.token ) AND arguments.autoReady>
		<cfset this.debugLog( "auto-ready data" )>
		<cfset this.visitLoad( visit )>
	</cfif>
	
	<cfreturn visit>
</cffunction>


<cffunction name="visitEnd" access="public" output="false"
	hint="Run this in onRequestEnd or onError"
>
	<cfargument name="visit" type="sojournVisit" required="true">
	
	<cfset var v = arguments.visit>

	<cfif len( v.token )>
		<cfset this.debugLog( "bake cookie #this.cookieName#" )>
		<cfcookie
			name="#this.cookieName#"
			value="#this.encodeToken( v.token )#"
			httpOnly="true"
			expires="#this.cookiesExpire#"
		>
	</cfif>

	<!--- <cfif v.loaded AND v.modified> --->
	<cfset this.visitSave( v )>
	<!--- </cfif> --->
	
</cffunction>


<cffunction name="visitKill" access="public" output="false" returnType="boolean">
	<cfargument name="visit" type="sojournVisit" required="true">
	
	<cfthrow message="The visitKill method must be overwritten">
</cffunction>


<cffunction name="visitLoad" access="public" output="false" returnType="boolean">
	<cfargument name="visit" type="sojournVisit" required="true">
	<cfargument name="force" type="boolean" default="false">
	
	<cfthrow message="The visitLoad method must be overwritten">
</cffunction>


<cffunction name="visitSave" access="public" output="false" returnType="boolean">
	<cfargument name="visit" type="sojournVisit" required="true">
	<cfargument name="force" type="boolean" default="false">
	
	<cfthrow message="The visitSave method must be overwritten">
</cffunction>


<cffunction name="isBot" access="public" output="false" returnType="boolean">
	<cfif reFind( "(googlebot|applebot|bingbot|duckduckgo|slurp|msnbot|jeeves/teoma|scooter)", lCase( cgi.http_user_agent ) )>
		<cfreturn true>
	</cfif>
	<cfreturn false>
</cffunction>


<cffunction name="encodeToken" access="public" output="false" returnType="string">
	<cfargument name="token" type="string" required="true">
	
	<cfreturn arguments.token>
</cffunction>


<cffunction name="isValidToken" access="public" output="false" returnType="boolean">
	<cfargument name="token" type="string" required="true">
	
	<cfif arguments.token IS "false" OR listLen( arguments.token, ":" ) IS NOT 3>
		<cfreturn false>
	</cfif>
	
	<cfif listGetAt( arguments.token, 2, ":" ) IS NOT lCase( left( hash( listGetAt( arguments.token, 1, ":" ) ), 4 ) )
		OR listGetAt( arguments.token, 3, ":" ) IS NOT lCase( left( hash( cgi.http_user_agent ), 4 ) )>
		<cfreturn false>
	</cfif>
	
	<cfreturn true>
</cffunction>


<cffunction name="newToken" access="public" output="false" returnType="string">
	<cfif this.tokenType IS "CF">
		<cfreturn randRange( 100000, 99999999 ) &"-"& randRange( 100000, 99999999 )>
	</cfif>
	
	<cfreturn replace( createUUID(), "-", "", "all" )>
</cffunction>


<cffunction name="importToken" access="public" output="false" returnType="string">
	<cfset var local = {}>
	<cfset local.token = "">
	
	<cfset this.debugLog( "Importing tokens" )>
	
	<cfloop index="local.index" list="#this.importScopes#">
		<cfset local.scope = evaluate( local.index )>
		<cfset this.debugLog( "Searching #uCase( local.index )# scope" )>
		
		<cfif structKeyExists( local.scope, this.cookieName ) AND len( local.scope[ this.cookieName ] )>
			<cfset local.token = listFirst( urlDecode( local.scope[ this.cookieName ] ), "|" )>
			<cfif this.isValidToken( local.token )>
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
	
	<cfreturn local.token>
</cffunction>


</cfcomponent>