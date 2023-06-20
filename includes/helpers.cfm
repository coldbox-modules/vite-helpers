<cfscript>
function vite() {
    var viteClient = application.wirebox.getInstance( "Vite@vite-helpers" );
    if ( structCount( arguments ) < 1 ) {
        return viteClient;
    }
    return viteClient.render( arguments[ 1 ] );
}
</cfscript>