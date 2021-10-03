package haxelib.server;

import sys.io.File;
import haxelib.Data;
import haxelib.server.Paths;
import haxelib.server.Paths.*;
import haxe.io.Path;
import haxe.ds.*;
import sys.FileSystem;
import js.lib.Promise;
import octokit.AuthApp;
import js.Node.*;
import SimpleGit.default_ as git;

@:access(haxelib)
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

    static public final localGitDir:AbsPath = Path.join([TMP_DIR, "git"]);
    static public final localHaxelibDir:AbsPath = Path.join([TMP_DIR, ".haxelib"]);

    static function createRemoteRepo(haxelib:String) {
        var repoName = haxelib; // TODO: validate
        return octokit.request.call({
            method: "POST",
            url: "/orgs/{org}/repos",
            org: githubOrg,
            name: repoName,
        });
    }

    static function createLocalRepo(haxelib:String) {
        var dir = Path.join([localGitDir, haxelib]);
        FileSystem.createDirectory(dir);
    }

    static function installAllVersions(haxelib:String) {
        var repo = new Repo();
        var infos = repo.infos(haxelib);
        for (v in infos.versions) {
            if (!v.name.valid) {
                console.warn('$v is not a valid semver');
            }
        }

        // from smaller to larger
        // infos.versions.sort(function (a, b) return SemVer.compare(a.name, b.name));
        //trace(infos.versions.map(v -> v.name));

        Sys.setCwd(TMP_DIR);
        var client = new haxelib.client.Main();
        client.settings = {
            debug: false,
            quiet: true,
            flat: false,
            always: true,
            never: false,
            global: false,
            system: false,
            skipDependencies: false,
        };
        if (Path.normalize(client.getRepository()) != Path.normalize(localHaxelibDir)) {
            throw "haxelib is not setup properly";
        }

        for (version in infos.versions) {
            client.doInstall(client.getRepository(), haxelib, version.name, false);
        }
    }

    static function importToRemote(haxelib:String) {
        var gitRepoDir:AbsPath = Path.join([localGitDir, haxelib]);
        FileSystem.createDirectory(gitRepoDir);
        var gitRepo = git({
            baseDir: gitRepoDir,
            config: [
                'user.name=haxelib',
                'user.email=contact@haxe.org',
            ]
        }).init(false);

        var haxelibRepo = new Repo();
        var infos = haxelibRepo.infos(haxelib);
        for (v in infos.versions) {
            if (!v.name.valid) {
                console.warn('$v is not a valid semver');
            }
        }

        // from earlier to later
        var versionsDateSorted:ReadOnlyArray<VersionInfos> = {
            var vs = infos.versions.copy();
            vs.sort(function (a, b) return Reflect.compare(a.date, b.date));
            vs;
        }

        Sys.setCwd(TMP_DIR);
        var client = new haxelib.client.Main();
        client.settings = {
            debug: false,
            quiet: true,
            flat: false,
            always: true,
            never: false,
            global: false,
            system: false,
            skipDependencies: false,
        };
        if (Path.normalize(client.getRepository()) != Path.normalize(localHaxelibDir)) {
            throw "haxelib is not setup properly";
        }

        function importVersions(versions:ReadOnlyArray<SemVer>) {
            if (versions.length <= 0)
                return Promise.resolve();

            final version = versions[0];
            final importedVersions:Promise<Array<SemVer>> = gitRepo.tags().then(r -> {
                var versions = r.all.map(SemVer.ofString);
                // from smaller to larger
                versions.sort(function (a, b) return SemVer.compare(a, b));
                versions;
            });
            final parentVersion = importedVersions.then(verions -> {
                var parent = null;
                for (v in verions) {
                    if (v >= version)
                        break;
                    parent = v;
                }
                parent;
            });
            final localVersionDir:AbsPath = Path.join([localHaxelibDir, Data.safe(haxelib), Data.safe(version)]);
            if (!FileSystem.exists(localVersionDir)) {
                client.doInstall(client.getRepository(), haxelib, version, true);
            }
            return parentVersion
                .then(parentVersion -> parentVersion == null ? null : gitRepo.checkout(parentVersion))
                .then(_ ->
                    // replace the files in git workspace with the haxelib archive contents
                    FsExtra.readdir(gitRepoDir)
                        .then(files -> Promise.all([
                            for (file in files)
                            if (file != ".git")
                            FsExtra.remove(Path.join([gitRepoDir, file]))
                        ]))
                        .then(_ -> trace("cleared git workspace"))
                        .then(_ ->
                            FsExtra.readdir(localVersionDir)
                                .then(files -> Promise.all([
                                    for (file in files)
                                        FsExtra.copy(
                                            Path.join([localVersionDir, file]),
                                            Path.join([gitRepoDir, file]),
                                            {
                                                recursive: true,
                                            }
                                        )
                                ]))
                        )
                        .then(_ -> trace("copied files"))
                )
                .then(_ -> gitRepo.add("--all"))
                .then(_ -> gitRepo.commit('import $haxelib $version'))
                .then(_ -> gitRepo.addTag(version))
                .then(_ -> trace('imported $haxelib $version'))
                .then(_ -> importVersions(versions.slice(1)));
        }

        importVersions(versionsDateSorted.map(v -> v.name));
    }

    static function main():Void {
        FileSystem.createDirectory(localGitDir);
        FileSystem.createDirectory(localHaxelibDir);
		SiteDb.init();
        // installAllVersions("jQueryExtern");
        importToRemote("jQueryExtern");
		SiteDb.cleanup();
    }
}