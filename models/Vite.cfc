/**
 * Vite Helper Service
 *
 * This service provides integration with Vite bundler for ColdBox applications.
 * It handles both development mode (hot reload) and production mode (manifest-based) asset loading.
 *
 * @author Eric Peterson
 * @since 1.0.0
 */
component singleton accessors="true" {

	property name="hotFilePath"      inject="box:setting:hotFilePath@vite-helpers";
	property name="buildDirectory"   inject="box:setting:buildDirectory@vite-helpers";
	property name="manifestFileName" inject="box:setting:manifestFileName@vite-helpers";

	/**
	 * Gets the asset paths based on the entrypoints passed
	 *
	 * @entrypoints The entrypoints to get the assets for. Can be a string or array of strings.
	 *
	 * @return array The resolved asset paths for the given entrypoints
	 */
	function getAssetPaths( required any entrypoints ) {
		arguments.entrypoints = arrayWrap( arguments.entrypoints );
		if ( isRunningHot() ) {
			return arguments.entrypoints.map( ( entrypoint ) => generateHotAssetPath( entrypoint ) );
		}

		var manifest = readManifest();
		return arguments.entrypoints.map( ( entrypoint ) => generateAssetPath( getEntrypointChunk( entrypoint ).file ) );
	}
	/**
	 * Renders the HTML tags for the assets based on the entrypoints passed.
	 * In development mode, includes the Vite client and serves assets from the dev server.
	 * In production mode, generates preload tags and proper script/link tags based on the manifest.
	 *
	 * @entrypoints The entrypoints to render assets for. Can be a string or array of strings.
	 *
	 * @return void Outputs HTML directly to the response stream
	 */
	function render( required any entrypoints ) output="true" {
		arguments.entrypoints = arrayWrap( arguments.entrypoints );

		if ( isRunningHot() ) {
			arrayPrepend( arguments.entrypoints, "/@vite/client" );
			write( getAssetPaths( arguments.entrypoints ).map( ( path ) => generateTag( path ) ) );
			return;
		}

		var manifest = readManifest();
		var preloads = [];
		var tags     = [];
		for ( var entrypoint in arguments.entrypoints ) {
			var chunk = getEntrypointChunk( entrypoint );
			preloads.append( {
				"src"      : chunk.src,
				"path"     : generateAssetPath( chunk.file ),
				"chunk"    : chunk,
				"manifest" : manifest
			} );

			for ( var assetImport in ( chunk.imports ?: [] ) ) {
				preloads.append( {
					"src"      : assetImport,
					"path"     : generateAssetPath( manifest[ assetImport ].file ),
					"chunk"    : manifest[ assetImport ],
					"manifest" : manifest
				} );

				for ( var css in ( manifest[ assetImport ].css ?: [] ) ) {
					var partialManifest = manifest.filter( ( key, value ) => value.file == css );

					if ( partialManifest.isEmpty() ) continue;

					var firstEntryKey = partialManifest.keyArray().first();
					preloads.append( {
						"src"      : firstEntryKey,
						"path"     : generateAssetPath( css ),
						"chunk"    : partialManifest[ firstEntryKey ],
						"manifest" : manifest
					} );

					tags.append(
						generateTagForChunk(
							src      = firstEntryKey,
							path     = generateAssetPath( css ),
							chunk    = partialManifest[ firstEntryKey ],
							manifest = manifest
						)
					);
				}
			}

			tags.append(
				generateTagForChunk(
					src      = entrypoint,
					path     = generateAssetPath( chunk.file ),
					chunk    = chunk,
					manifest = manifest
				)
			);

			for ( var css in ( chunk.css ?: [] ) ) {
				var partialManifest = manifest.filter( ( key, value ) => value.file == css );

				if ( partialManifest.isEmpty() ) continue;

				var firstEntryKey = partialManifest.keyArray().first();

				preloads.append( {
					"src"      : firstEntryKey,
					"path"     : generateAssetPath( css ),
					"chunk"    : partialManifest[ firstEntryKey ],
					"manifest" : manifest
				} );

				tags.append(
					generateTagForChunk(
						src      = firstEntryKey,
						path     = generateAssetPath( css ),
						chunk    = partialManifest[ firstEntryKey ],
						manifest = manifest
					)
				);
			}
		}

		var assetsByType = partitionTagsByType( arrayUnique( tags ) );

		var preloadTags = arrayUnique( preloads )
			.sort( function( a, b ) {
				var isFirstCssAsset  = isCssAsset( a.src );
				var isSecondCssAsset = isCssAsset( a.src );
				if ( isFirstCssAsset == isSecondCssAsset ) {
					return 0;
				}
				if ( isFirstCssAsset && !isSecondCssAsset ) {
					return 1;
				}
				return -1;
			} )
			.map( ( preload ) => generatePreloadTagForChunk(
				src      = preload.src,
				path     = preload.path,
				chunk    = preload.chunk,
				manifest = preload.manifest
			) );

		write( preloadTags );
		write( assetsByType.stylesheets );
		write( assetsByType.scripts );
	}

	/**
	 * Partitions HTML tags into stylesheets and scripts based on tag type
	 *
	 * @tags Array of HTML tag strings to partition
	 *
	 * @return struct Structure with 'stylesheets' and 'scripts' arrays
	 */
	private struct function partitionTagsByType( required array tags ) {
		return arguments.tags.reduce( ( acc, tag ) => {
			if ( stringStartsWith( tag, "<link" ) ) {
				acc.stylesheets.append( tag );
			} else {
				acc.scripts.append( tag );
			}
			return acc;
		}, { "stylesheets" : [], "scripts" : [] } );
	}

	/**
	 * Gets the chunk information for a specific entrypoint from the manifest
	 *
	 * @entrypoint The entrypoint name to get chunk information for
	 *
	 * @return struct The chunk information from the manifest
	 */
	private struct function getEntrypointChunk( required string entrypoint ) {
		return readManifest()[ ensureNoLeadingSlash( arguments.entrypoint ) ];
	}

	/**
	 * Reads and parses the Vite manifest file
	 * Caches the manifest contents in variables scope for performance
	 *
	 * @return struct The parsed manifest data structure
	 *
	 * @throws Throws an error if the manifest file is not found
	 */
	private struct function readManifest() {
		if ( !fileExists( expandPath( getManifestPath() ) ) ) {
			throw( "Manifest file not found. Please run `vite` first." );
		}
		param variables.manifestContents = deserializeJSON( fileRead( expandPath( getManifestPath() ) ) );
		return variables.manifestContents;
	}

	/**
	 * Constructs the full path to the Vite manifest file
	 *
	 * @return string The complete path to the manifest file
	 */
	private string function getManifestPath() {
		return variables.buildDirectory & "/" & variables.manifestFileName;
	}

	/**
	 * Generates the appropriate HTML tag for a chunk (script or link tag)
	 *
	 * @src The source entrypoint name
	 * @path The resolved asset path
	 * @chunk The chunk information from the manifest
	 * @manifest The complete manifest data
	 *
	 * @return string The generated HTML tag
	 */
	private string function generateTagForChunk(
		required string src,
		required string path,
		required struct chunk,
		required struct manifest
	) {
		if ( isCssAsset( arguments.path ) ) {
			return generateStylesheetTagWithAttributes(
				arguments.path,
				resolveStylesheetTagAttributes(
					arguments.src,
					arguments.path,
					arguments.chunk,
					arguments.manifest
				)
			);
		}

		return generateScriptTagWithAttributes(
			arguments.path,
			resolveStylesheetTagAttributes(
				arguments.src,
				arguments.path,
				arguments.chunk,
				arguments.manifest
			)
		);
	}

	/**
	 * Generates a stylesheet link tag with the specified attributes
	 *
	 * @path The path to the stylesheet
	 * @attributes Additional attributes to include in the tag
	 *
	 * @return string The generated link tag HTML
	 */
	private string function generateStylesheetTagWithAttributes( required string path, struct attributes = [ : ] ) {
		var attrs = [
			"rel" : "stylesheet",
			"href": arguments.path
		];
		structAppend( attrs, arguments.attributes, true );
		return "<link #parseAttributes( attrs )# />";
	}

	/**
	 * Generates a script tag with the specified attributes
	 * Automatically sets type="module" for ES module support
	 *
	 * @path The path to the script
	 * @attributes Additional attributes to include in the tag
	 *
	 * @return string The generated script tag HTML
	 */
	private string function generateScriptTagWithAttributes( required string path, struct attributes = [ : ] ) {
		var attrs = [
			"type": "module",
			"src" : arguments.path
		];
		structAppend( attrs, arguments.attributes, true );
		return "<script #parseAttributes( attrs )#></script>";
	}

	/**
	 * Converts a structure of attributes into an HTML attribute string
	 *
	 * @attributes Structure containing attribute key-value pairs
	 *
	 * @return string Space-separated HTML attributes string
	 */
	private string function parseAttributes( required struct attributes ) {
		return arguments.attributes
			.keyArray()
			.map( ( key ) => '#key#="#attributes[ key ]#"' )
			.toList( " " )
	}

	/**
	 * Resolves additional attributes for stylesheet tags
	 * Currently returns empty structure but can be extended for custom attributes
	 *
	 * @src The source entrypoint name
	 * @path The resolved asset path
	 * @chunk The chunk information from the manifest
	 * @manifest The complete manifest data
	 *
	 * @return struct Additional attributes for the stylesheet tag
	 */
	private struct function resolveStylesheetTagAttributes(
		required string src,
		required string path,
		required struct chunk,
		required struct manifest
	) {
		return [ : ];
	}

	/**
	 * Generates a preload link tag for a chunk
	 * Preload tags help browsers discover and load resources early
	 *
	 * @src The source entrypoint name
	 * @path The resolved asset path
	 * @chunk The chunk information from the manifest
	 * @manifest The complete manifest data
	 *
	 * @return string The generated preload link tag HTML
	 */
	private string function generatePreloadTagForChunk(
		required string src,
		required string path,
		required struct chunk,
		required struct manifest
	) {
		var attributes = resolvePreloadTagAttributes(
			arguments.src,
			arguments.path,
			arguments.chunk,
			arguments.manifest
		);
		return "<link #parseAttributes( attributes )# />";
	}

	/**
	 * Resolves the appropriate attributes for preload tags
	 * CSS assets get rel="preload" as="style", JS assets get rel="modulepreload"
	 *
	 * @src The source entrypoint name
	 * @path The resolved asset path
	 * @chunk The chunk information from the manifest
	 * @manifest The complete manifest data
	 *
	 * @return struct Attributes structure for the preload tag
	 */
	private struct function resolvePreloadTagAttributes(
		required string src,
		required string path,
		required struct chunk,
		required struct manifest
	) {
		return isCssAsset( arguments.path ) ? [
			"rel" : "preload",
			"as"  : "style",
			"href": arguments.path
		] : [
			"rel" : "modulepreload",
			"href": arguments.path
		];
	}

	/**
	 * Generates a simple HTML tag for an asset path (used in development mode)
	 * Creates either a stylesheet link or module script tag based on file extension
	 *
	 * @path The asset path to generate a tag for
	 *
	 * @return string The generated HTML tag
	 */
	private string function generateTag( required string path ) {
		if ( isCssAsset( arguments.path ) ) {
			return '<link rel="stylesheet" href="#path#" />';
		} else {
			return '<script type="module" src="#path#"></script>';
		}
	}

	/**
	 * Determines if a file path represents a CSS asset based on file extension
	 * Supports css, less, sass, scss, styl, stylus, pcss, and postcss extensions
	 *
	 * @path The file path to check
	 *
	 * @return boolean True if the path represents a CSS asset, false otherwise
	 */
	private boolean function isCssAsset( required string path ) {
		return reFindNoCase( "\.(css|less|sass|scss|styl|stylus|pcss|postcss)$", arguments.path ) > 1;
	}

	/**
	 * Generates the full asset path for production mode using ColdBox's buildLink
	 * Combines build directory with asset path and creates proper URLs
	 *
	 * @path The relative asset path from the manifest
	 *
	 * @return string The complete asset URL for production
	 */
	private string function generateAssetPath( required string path ) {
		return getRequestContext().buildLink(
			to        = ensureNoLeadingSlash( getBuildDirectory() & ensureLeadingSlash( arguments.path ) ),
			translate = false
		);
	}

	/**
	 * Generates the full asset path for development mode using the hot server URL
	 * Combines the hot server URL with the asset path
	 *
	 * @path The asset path to append to the hot server URL
	 *
	 * @return string The complete asset URL for development
	 */
	private string function generateHotAssetPath( required string path ) {
		return readHotFile() & ensureLeadingSlash( arguments.path );
	}

	/**
	 * Ensures a path has a leading slash
	 * If the path doesn't start with "/", adds one
	 *
	 * @path The path to normalize
	 *
	 * @return string The path with a leading slash
	 */
	private string function ensureLeadingSlash( required string path ) {
		return left( arguments.path, 1 ) == "/" ? arguments.path : "/" & arguments.path;
	}

	/**
	 * Ensures a path does not have a leading slash
	 * If the path starts with "/", removes it. Returns empty string for paths <= 1 character
	 *
	 * @path The path to normalize
	 *
	 * @return string The path without a leading slash
	 */
	private string function ensureNoLeadingSlash( required string path ) {
		if ( len( arguments.path ) <= 1 ) {
			return "";
		}
		return left( arguments.path, 1 ) == "/" ? mid(
			arguments.path,
			2,
			len( arguments.path ) - 1
		) : arguments.path;
	}

	/**
	 * Reads the hot server URL from the hot file
	 * Caches the URL in variables scope and trims whitespace
	 *
	 * @return string The hot server URL (e.g., "http://127.0.0.1:5173")
	 */
	private string function readHotFile() {
		param variables._hotServerUrl = trim( fileRead( expandPath( variables.hotFilePath ) ) );
		return variables._hotServerUrl;
	}

	/**
	 * Outputs an array of HTML tag strings to the response stream
	 *
	 * @tags Array of HTML tag strings to output
	 */
	private void function write( required array tags ) output="true" {
		for ( var tag in arguments.tags ) {
			writeOutput( tag );
		}
	}

	/**
	 * Determines if the application is running in hot development mode
	 * Checks for the existence of the hot file
	 *
	 * @return boolean True if hot file exists (development mode), false otherwise
	 */
	private boolean function isRunningHot() {
		return fileExists( expandPath( variables.hotFilePath ) );
	}

	/**
	 * Wraps a value in an array if it's not already an array
	 * Utility function for normalizing entrypoint parameters
	 *
	 * @value The value to wrap (can be string or array)
	 *
	 * @return array The value as an array
	 */
	private array function arrayWrap( required any value ) {
		return isArray( arguments.value ) ? arguments.value : [ arguments.value ];
	}

	/**
	 * Removes duplicate elements from an array using Java HashSet
	 * More efficient than CFML's built-in array functions for large arrays
	 *
	 * @items The array to remove duplicates from
	 *
	 * @return array Array with unique elements only
	 */
	private array function arrayUnique( required array items ) {
		return arraySlice( createObject( "java", "java.util.HashSet" ).init( arguments.items ).toArray(), 1 );
	}

	/**
	 * Checks if a string starts with a specific substring
	 * Simple string utility function
	 *
	 * @word The string to check
	 * @substring The substring to look for at the beginning
	 *
	 * @return boolean True if word starts with substring, false otherwise
	 */
	private boolean function stringStartsWith( word, substring ) {
		return left( word, len( substring ) ) == substring;
	}

	/**
	 * Gets the ColdBox RequestContext via provider injection
	 * Used for building asset URLs with proper routing
	 *
	 * @return RequestContext The current ColdBox request context
	 */
	private RequestContext function getRequestContext() provider="coldbox:requestContext" {
	}

}
