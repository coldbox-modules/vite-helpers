component {

    this.name = "vite-helpers-testing-suite" & hash(getCurrentTemplatePath());
    this.sessionManagement  = true;
    this.setClientCookies   = true;
    this.sessionTimeout     = createTimeSpan( 0, 0, 15, 0 );
    this.applicationTimeout = createTimeSpan( 0, 0, 15, 0 );

    testsPath = getDirectoryFromPath( getCurrentTemplatePath() );
    this.mappings[ "/tests" ] = testsPath;
    rootPath = REReplaceNoCase( this.mappings[ "/tests" ], "tests(\\|/)", "" );
    this.mappings[ "/root" ] = rootPath;
    this.mappings[ "/vite-helpers" ] = rootPath;
    this.mappings[ "/testingModuleRoot" ] = listDeleteAt( rootPath, listLen( rootPath, '\/' ), "\/" );
    this.mappings[ "/app" ] = testsPath & "resources/app";
    this.mappings[ "/" ] = testsPath & "resources/app";
    this.mappings[ "/testbox" ] = rootPath & "/testbox";
    this.mappings[ "/coldbox" ] = testsPath & "/resources/app/coldbox";

    function onRequestStart() {
        structDelete( application, "cbController" );
        structDelete( application, "wirebox" );
    }

}
