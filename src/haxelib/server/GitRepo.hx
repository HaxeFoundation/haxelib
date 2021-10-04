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
import simple_git.SimpleGit;
import SimpleGit.default_ as git;

@:access(haxelib)
class GitRepo {
    static public final root:AbsPath = Path.directory(Sys.programPath());
    static public final privateKeyFile:AbsPath = FileSystem.absolutePath(Sys.getEnv("GITHUB_APP_PRIVATE_KEY_FILE"));

    // Auth as an "installation"
    // https://github.com/organizations/haxelib/settings/installations/19601456
    static public final githubApp = {
        appId: 139127,
        clientId: "Iv1.89d7675c50ba41de",
        privateKey: File.getContent(privateKeyFile),
        installationId: 19601456,
    }

    static public final githubOrg = "haxelib";
    static public final octokit = new octokit.core.Octokit({
        authStrategy: AuthApp.createAppAuth,
        auth: githubApp,
    });

    static public final localGitDir:AbsPath = Path.join([TMP_DIR, "git"]);
    static public final localHaxelibDir:AbsPath = Path.join([TMP_DIR, ".haxelib"]);

    static function createInstallationAccessToken():Promise<String> {
        return octokit.request.call({
            method: "POST",
            url: "/app/installations/{installation_id}/access_tokens",
            installation_id: githubApp.installationId
        })
            .then(r -> r.data.token);
    }

    static function getRemoteRepo(haxelib:String) {
        var repoName = haxelib; // TODO: validate
        return octokit.request.call({
            method: "GET",
            url: "/repos/{owner}/{repo}",
            owner: githubOrg,
            repo: repoName,
        })
            .then(r -> r.data.ssh_url)
            .catchError(err -> {
                trace(err);
                createRemoteRepo(haxelib)
                    .then(_ -> getRemoteRepo(haxelib));
            });
    }

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

    static function importToRemote(haxelib:String):Promise<SimpleGit> {
        return importToLocalGit(haxelib)
            .then(gitRepo ->
                getRemoteRepo(haxelib)
                    .then(_ -> createInstallationAccessToken())
                    .then(token -> 'https://x-access-token:$token@github.com/haxelib/$haxelib.git')
                    .then(remote -> 
                        getImportedVersions(Promise.resolve(gitRepo))
                            .then(versions -> versions[versions.length - 1])
                            .then(largest ->
                                gitRepo.log(["-1", "--format=format:%H", 'refs/tags/$largest'])
                                    .then(logs -> logs.latest.hash)
                            )
                            .then(sha -> {
                                gitRepo
                                    .checkout("master")
                                    .reset(HARD, [sha])
                                    .push([remote, "master", "--force"])
                                    .push([remote, "--tags", "--force"]);
                            })
                    )
                    .then(_ -> gitRepo)
            );
    }

    static function getImportedVersions(gitRepo:Promise<SimpleGit>):Promise<Array<SemVer>> {
        return gitRepo.then(g ->
            g.tags().then(r -> {
                var versions = r.all.map(SemVer.ofString);
                // from smaller to larger
                versions.sort(function (a, b) return SemVer.compare(a, b));
                versions;
            })
        );
    }

    static function importToLocalGit(haxelib:String):Promise<SimpleGit> {
        final gitRepoDir:AbsPath = Path.join([localGitDir, haxelib]);
        FileSystem.createDirectory(gitRepoDir);

        final gitRepo:Promise<SimpleGit> = Promise.resolve(git({
            baseDir: gitRepoDir,
            config: [
                'user.name=haxelib',
                'user.email=contact@haxe.org',
            ]
        }))
            .then(g -> g
                .init(false)
                .then(_ -> g)
            );

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

        function importVersions(versions:ReadOnlyArray<VersionInfos>) {
            if (versions.length <= 0)
                return gitRepo;

            final version = versions[0];
            final importedVersions:Promise<Array<SemVer>> = getImportedVersions(gitRepo);
            final parentVersion = importedVersions.then(verions -> {
                var parent = null;
                for (v in verions) {
                    if (v > version.name)
                        break;
                    parent = v;
                }
                parent;
            });
            final localVersionDir:AbsPath = Path.join([localHaxelibDir, Data.safe(haxelib), Data.safe(version.name)]);
            return parentVersion
                .then(parentVersion ->
                    if (parentVersion != null && parentVersion == version.name) {
                        console.log('You already have $haxelib version ${version.name} imported');
                        null;
                    } else {
                        (parentVersion != null ? gitRepo.then(g -> g.checkout(parentVersion)).then(_ -> null) : Promise.resolve(null))
                            .then(_ -> Sys.command("neko", [Path.join([root, "run.n"]), "install", haxelib, version.name, "--never"]))
                            .then(_ ->
                                // replace the files in git workspace with the haxelib archive contents
                                FsExtra.readdir(gitRepoDir)
                                    .then(files -> Promise.all([
                                        for (file in files)
                                        if (file != ".git")
                                        FsExtra.remove(Path.join([gitRepoDir, file]))
                                    ]))
                                    .then(_ -> console.log("cleared git workspace"))
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
                                    .then(_ -> console.log("copied files"))
                            )
                            .then(_ ->
                                gitRepo.then(g -> g
                                    .add([
                                        // make sure removed files are staged
                                        "--all",

                                        // include gitignored files
                                        "--force",
                                    ])
                                    .commit('import $haxelib ${version.name}', {
                                        "--date": version.date
                                    })
                                    .addAnnotatedTag(version.name, version.comments)
                                )
                            )
                            .then(_ -> console.log('imported $haxelib ${version.name}'));
                    }
                )
                .then(_ -> importVersions(versions.slice(1)));
        }

        return importVersions(versionsDateSorted);
    }

    static function main():Void {
        FileSystem.createDirectory(localGitDir);
        FileSystem.createDirectory(localHaxelibDir);
		SiteDb.init();
        // installAllVersions("jQueryExtern");
        switch (Sys.args()) {
            case [haxelib]:
                importToRemote(haxelib);
            case _:
                throw "haxelib name expected";
        }
		SiteDb.cleanup();
    }
}