package haxelib.server;

import octokit.Octokit;
import octokit.AuthApp;

class GitRepo {
    static function main():Void {
        var octokit = new Octokit({
            authStrategy: AuthApp.createAppAuth,
            auth: {

            },
        });
    }
}