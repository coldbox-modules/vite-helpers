component {

	function configure() {
		// Set Full Rewrites
		setFullRewrites( true );

		// Conventions based routing
		route( ":handler/:action?" ).end();
	}

}
