package haxelib.server;

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

    static function main():Void {
        var octokit = new octokit.core.Octokit({
            authStrategy: AuthApp.createAppAuth,
            auth: githubApp,
        });
        octokit.request.call({
            method: "POST",
            url: "/orgs/{org}/repos",
            org: "haxelib",
            name: "test_createdWithOctokit",
            "private": true,
        })
            .then(r -> {
                trace(r);
            })
            .catchError(err -> trace(err));
    }
}