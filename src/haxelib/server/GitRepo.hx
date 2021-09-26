package haxelib.server;

import js.lib.Promise;
import octokit.AuthApp;

class GitRepo {
    // Auth as an "installation"
    // https://github.com/organizations/haxelib/settings/installations/19601456
    static public final githubApp = {
        appId: 139127,
        clientId: "Iv1.89d7675c50ba41de",
        privateKey: Sys.getEnv("GITHUB_APP_PRIVATE_KEY"),
        installationId: 19601456,
    }

    static public final githubOrg = "haxelib";
    static public final octokit = new octokit.core.Octokit({
        authStrategy: AuthApp.createAppAuth,
        auth: githubApp,
    });

    static function createRepo(haxelib:String) {
        var repoName = haxelib; // TODO: validate
        return octokit.request.call({
            method: "POST",
            url: "/orgs/{org}/repos",
            org: githubOrg,
            name: repoName,
        });
    }

    static function main():Void {
		SiteDb.init();
        var repo = new Repo();
        var infos = repo.infos("lime");
        trace(infos);
		SiteDb.cleanup();
    }
}