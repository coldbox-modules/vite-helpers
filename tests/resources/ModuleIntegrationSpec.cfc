component extends="coldbox.system.testing.BaseTestCase" {

    this.unloadColdBox = true;

    function beforeAll() {
        super.beforeAll();

        getController().getModuleService()
            .registerAndActivateModule( "vite-helpers", "testingModuleRoot" );
    }

    /**
    * @beforeEach
    */
    function setupIntegrationTest() {
        setup();
    }

}
