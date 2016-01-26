package;

import website.api.ProjectListApi;
import ufront.app.UfrontApplication;
import ufront.mailer.*;
import ufront.auth.EasyAuth;
import ufront.view.TemplatingEngines;
import twl.webapp.*;
import twl.*;
import buddy.*;

@:build(buddy.GenerateMain.withSuites([
	website.controller.DocumentationControllerTest,
	website.controller.HomeControllerTest,
	// website.controller.ProjectControllerTest,
	website.controller.RSSControllerTest,
	// website.controller.UserControllerTest,
]))
class WebsiteTests {
	static var ufApp:UfrontApplication;

	public static function getTestApp():UfrontApplication {
		if ( ufApp==null ) {
			// Create a UfrontApplication suitable for unit testing.
			ufApp = new UfrontApplication({
				indexController: website.controller.HomeController,
				errorHandlers: [],
				disableBrowserTrace: true,
				contentDirectory: "../uf-content/",
				templatingEngines: [TemplatingEngines.erazor],
				viewPath: "www/view/",
				defaultLayout: "layout.html",
			});

			// Different injections for our test suite.
			ufApp.injector.map( UFMailer ).toSingleton( TestMailer );
			ufApp.injector.map( EasyAuth ).toValue( new EasyAuthAdminMode() );
			ufApp.injector.map( String, "documentationPath" ).toValue( "www/documentation-files/" );

			haxelib.server.SiteDb.init();
		}
		return ufApp;
	}
}
