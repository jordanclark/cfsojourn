component {

	function init( required sojourn store, string token= false, boolean haveCookies= false ) {
		variables.store = arguments.store;
		this.haveCookies = arguments.haveCookies;
		this.data = {};
		this.loaded = false;
		this.stored = false;
		this.modified = false;
		this.hits = 0;
		this.lastvisit = "";
		this.debugLog( "create visit haveCookies[#arguments.haveCookies#]" );
		this.setToken( arguments.token );
		return this;
	}

	function debugLog( required input ) {
		if ( !variables.store.debug ) {
			return;
		}
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "visit: " & arguments.input );
			} else {
				request.log( "visit: (complex type)" );
				request.log( arguments.input );
			}
		} else {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="visit", type="information" );
		}
		return;
	}

	boolean function kill() {
		return variables.store.visitKill( this );
	}

	boolean function load( boolean force= false ) {
		if ( !arguments.force && this.loaded && this.modified ) {
			// save changes before loading new data 
			this.debugLog( "save changes before loading new data" );
			variables.store.visitSave( this );
		}
		return variables.store.visitLoad( this, arguments.force );
	}

	boolean function save( boolean force= false ) {
		return variables.store.visitSave( this, arguments.force );
	}

	function end( boolean force= false ) {
		variables.store.visitEnd( this );
	}

	function ready() {
		this.debugLog( "ready" );
		if ( !this.loaded ) {
			this.load();
		}
		return this;
	}

	boolean function haveData() {
		return !structIsEmpty( this.data );
	}

	boolean function haveToken() {
		return len( this.token ) ? true : false;
	}

	function newVisit() {
		this.debugLog( "new visit" );
		this.setToken( variables.store.newToken() );
	}

	function setToken( string token= "", string userAgent= cgi.http_user_agent ) {
		this.debugLog( "setToken[#arguments.token#]" );
		this.token = arguments.token;
		if ( len( this.token ) ) {
			this.token &= ":" &
				lCase( left( hash( this.token ), 4 ) ) & ":" &
				lCase( left( hash( arguments.userAgent ), 4 ) );
		}
	}

	function set( variableName name, value ) {
		arguments.name = lCase( arguments.name );
		if ( !this.loaded ) {
			// lazy load 
			this.load();
		}
	//	if( isSimpleValue( arguments.value ) ) {
	//		arguments.value = toString( arguments.value );
	//	}
		if ( isNull( arguments.value ) ) {
			this.debugLog( "data #arguments.name# == NULL" );
		} else if ( !structKeyExists( this.data, arguments.name ) ) {
			this.debugLog( "data #arguments.name# == new " & ( isSimpleValue( arguments.value ) ? arguments.value : "" ) );
			this.data[ arguments.name ] = arguments.value;
			this.modified = true;
		} else if ( !isSimpleValue( this.data[ arguments.name ] ) || !isSimpleValue( arguments.value ) ) {
			this.debugLog( "data #arguments.name# == complex" );
			this.data[ arguments.name ] = arguments.value;
			this.modified = true;
		} else if ( this.data[ arguments.name ] != arguments.value ) {
			this.debugLog( "data #arguments.name# == different" );
			this.data[ arguments.name ] = arguments.value;
			this.modified = true;
		} else {
			this.debugLog( "data #arguments.name# == the same" );
		}
		if ( variables.store.autoSave && this.modified ) {
			try {
				this.debugLog( "auto save" );
				this.save();
			} catch (any cfcatch) {
				this.debugLog( "save failed: #cfcatch.messge# #cfcatch.detail#" );
			}
		}
	}

	function remove( variableName name ) {
		arguments.name = lCase( arguments.name );
		this.debugLog( "remove #arguments.name#" );
		if ( !this.loaded ) {
			// lazy load 
			this.load();
		}
		if ( structKeyExists( this.data, arguments.name ) ) {
			structDelete( this.data, arguments.name );
			this.modified = true;
		}
		if ( variables.store.autoSave ) {
			try {
				this.debugLog( "auto save" );
				this.save();
			} catch (any cfcatch) {
				this.debugLog( "save failed: #cfcatch.messge# #cfcatch.detail#" );
			}
		}
	}

	boolean function exists( variableName name ) {
		arguments.name = lCase( arguments.name );
		if ( !this.loaded ) {
			// lazy load 
			this.load();
		}
		this.debugLog( "exists #arguments.name#: #structKeyExists( this.data, arguments.name )#" );
		return structKeyExists( this.data, arguments.name ) && !isNull( this.data[ arguments.name ] );
	}

	function get( variableName name, default ) {
		arguments.name = lCase( arguments.name );
		if ( !this.loaded ) {
			try {
				// lazy load 
				this.load();
			} catch (any cfcatch) {
				this.debugLog( "failed to load data, fail silently" );
			}
		}
		if ( !structKeyExists( this.data, arguments.name ) && structKeyExists( arguments, "default" ) ) {
			return arguments.default;
		} else if ( isNull( this.data[ arguments.name ] ) && structKeyExists( arguments, "default" ) ) {
			return arguments.default;
		}
		if ( structKeyExists( this.data, arguments.name ) && isSimpleValue( this.data[ arguments.name ] ) ) {
			this.debugLog( "get #arguments.name# [#this.data[ arguments.name ]#]" );
		} else {
			this.debugLog( "get #arguments.name# [complex]" );
		}
		return this.data[ arguments.name ];
	}

}
