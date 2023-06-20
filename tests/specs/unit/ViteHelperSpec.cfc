component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	include "/vite-helpers/includes/helpers.cfm";

	variables.hotServerUrl         = "http://127.0.0.1:5173";
	variables.hotFilePath          = expandPath( "/app/includes/hot" );
	variables.manifestFilePath     = expandPath( "/app/includes/build/manifest.json" );
	variables.manifestFileContents = {
		"resources/assets/css/app.css" : {
			"file"    : "assets/app-00d284d6.css",
			"isEntry" : true,
			"src"     : "resources/assets/css/app.css"
		},
		"resources/assets/js/Pages/Main/Index.vue" : {
			"file"           : "assets/Index-c853f713.js",
			"imports"        : [ "resources/assets/js/app.js" ],
			"isDynamicEntry" : true,
			"src"            : "resources/assets/js/Pages/Main/Index.vue"
		},
		"resources/assets/js/Pages/Registrations/New.vue" : {
			"file"           : "assets/New-10bf5ed4.js",
			"imports"        : [ "resources/assets/js/app.js" ],
			"isDynamicEntry" : true,
			"src"            : "resources/assets/js/Pages/Registrations/New.vue"
		},
		"resources/assets/js/Pages/Sessions/New.vue" : {
			"file"           : "assets/New-a9170e24.js",
			"imports"        : [ "resources/assets/js/app.js" ],
			"isDynamicEntry" : true,
			"src"            : "resources/assets/js/Pages/Sessions/New.vue"
		},
		"resources/assets/js/app.js" : {
			"dynamicImports" : [
				"resources/assets/js/Pages/Main/Index.vue",
				"resources/assets/js/Pages/Registrations/New.vue",
				"resources/assets/js/Pages/Sessions/New.vue"
			],
			"file"    : "assets/app-5b5efed9.js",
			"isEntry" : true,
			"src"     : "resources/assets/js/app.js"
		}
	};

	function run() {
		describe( "vite helper", function() {
			describe( "dev", () => {
				beforeEach( () => {
					fileWrite( variables.hotFilePath, variables.hotServerUrl );
				} );

				afterEach( () => {
					if ( fileExists( variables.hotFilePath ) ) {
						fileDelete( variables.hotFilePath );
					}
				} );

				it( "appends the vite client in dev", () => {
					savecontent variable="local.output" {
						vite( "resources/assets/js/app.js" );
					}
					expect( output ).toInclude( '<script type="module" src="#variables.hotServerUrl & "/@vite/client"#"></script>' );
				} );

				it( "can generate css assets in dev", () => {
					savecontent variable="local.output" {
						vite( "resources/assets/css/app.css" );
					}
					expect( output ).toInclude( '<link rel="stylesheet" href="#variables.hotServerUrl & "/resources/assets/css/app.css"#" />' );
				} );

				it( "can generate js assets in dev", () => {
					savecontent variable="local.output" {
						vite( "resources/assets/js/app.js" );
					}
					expect( output ).toInclude( '<script type="module" src="#variables.hotServerUrl & "/resources/assets/js/app.js"#"></script>' );
				} );
			} );

			describe( "prod", () => {
				beforeEach( () => {
					fileWrite( variables.manifestFilePath, serializeJSON( variables.manifestFileContents ) );
				} );

				afterEach( () => {
					if ( fileExists( variables.manifestFilePath ) ) {
						fileDelete( variables.manifestFilePath );
					}
				} );

				it( "can generate css assets in prod", () => {
					savecontent variable="local.output" {
						vite( "resources/assets/css/app.css" );
					}
					expect( output ).toInclude( '<link rel="preload" as="style" href="#getRequestContext().buildLink( to = "includes/build/assets/app-00d284d6.css", translate = false )#" />' );
					expect( output ).toInclude( '<link rel="stylesheet" href="#getRequestContext().buildLink( to = "includes/build/assets/app-00d284d6.css", translate = false )#" />' );
				} );

				it( "can generate js assets in prod", () => {
					savecontent variable="local.output" {
						vite( "resources/assets/js/app.js" );
					}
					expect( output ).toInclude( '<link rel="modulepreload" href="#getRequestContext().buildLink( to = "includes/build/assets/app-5b5efed9.js", translate = false )#" />' );
					expect( output ).toInclude( '<script type="module" src="#getRequestContext().buildLink( to = "includes/build/assets/app-5b5efed9.js", translate = false )#"></script>' );
				} );
			} );

			describe( "custom paths", () => {
				it( "can generate using custom buildDirectory and manifestFileName parameters", () => {
					var customBuildDirectory   = "/includes/somewhere-else";
					var customManifestFileName = "app-manifest.json";
					var customManifestFilePath = expandPath( "/app#customBuildDirectory#/#customManifestFileName#" );
					try {
						fileWrite( customManifestFilePath, serializeJSON( variables.manifestFileContents ) );
						savecontent variable="local.output" {
							vite()
								.setBuildDirectory( customBuildDirectory )
								.setManifestFileName( customManifestFileName )
								.render( [
									"resources/assets/js/app.js",
									"resources/assets/css/app.css"
								] )
						}
						expect( output ).toInclude( '<link rel="preload" as="style" href="#getRequestContext().buildLink(
							to = "includes/somewhere-else/assets/app-00d284d6.css",
							translate = false
						)#" />' );
						expect( output ).toInclude( '<link rel="modulepreload" href="#getRequestContext().buildLink(
							to = "includes/somewhere-else/assets/app-5b5efed9.js",
							translate = false
						)#" />' );
						expect( output ).toInclude( '<link rel="stylesheet" href="#getRequestContext().buildLink(
							to = "includes/somewhere-else/assets/app-00d284d6.css",
							translate = false
						)#" />' );
						expect( output ).toInclude( '<script type="module" src="#getRequestContext().buildLink(
							to = "includes/somewhere-else/assets/app-5b5efed9.js",
							translate = false
						)#"></script>' );
					} finally {
						if ( fileExists( customManifestFilePath ) ) {
							fileDelete( customManifestFilePath );
						}
					}
				} );
			} );
		} );
	}

	private string function localhostUrl() {
		return ( ( CGI.keyExists( "HTTPS" ) and CGI.HTTPS eq "on" ) ? "https://" : "http://" ) & CGI.HTTP_HOST
	}

}
