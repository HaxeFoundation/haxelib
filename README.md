# Haxelib

For more documentation, please refer to [haxe.org](http://haxe.org/haxelib)

[![TravisCI Build Status](https://travis-ci.org/HaxeFoundation/haxelib.svg?branch=development)](https://travis-ci.org/HaxeFoundation/haxelib)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/HaxeFoundation/haxelib?branch=development&svg=true)](https://ci.appveyor.com/project/HaxeFoundation/haxelib)

## Per-project setup

Currently haxelib has two ways to have project local setups.

1. Using `haxelib newrepo`
2. Using `haxelib install all`

### Using haxelib newrepo

When using `haxelib newrepo` you can have a project-local haxelib repository. This feature is quite new and a little rough around the edges.

Caveats:

- if you mistakenly run a haxelib command in a subdirectory of your project, it will be executed on the global repo (to be fixed)
- there may be some issues with `haxelib run` and `haxelib selfupdate` (to be fixed)
- libraries get downloaded for each project
- it requires a recent Haxe version (after 3.1.3) to work properly with ndlls.

### Using haxelib install all

Haxe allows you to define specific versions of the libraries you want to use with `-lib <libname>:<version>`. If you make sure to use this in all your hxmls, then `haxelib install all --always` (the `--always` avoiding you being prompted for confirmation) will be able to ensure the libraries your project needs are available in the necessary versions. If in fact you run this in a checkout hook, your get to track your dependencies in your git repo (some other VCSs should allow for a similar setup), allowing you to have a well defined and replicable setup for any state (commit/branch/etc.).

Disadvantages:

- the approach requires you to define all dependencies with specific versions and then running `haxelib install all` to grab them
- with this approach, any other project that does not have specific versions defined may be affected, as under some circumstances `haxelib install all` may set the global "current" version of the libraries (to be fixed)

Advantages:

- as pointed out above, this approach allows defining a *versionable* and *replicable* state.
- you don't have to download libraries for each project, which does make a difference for heavy weights like openfl and hxcpp

#### Sidestepping haxelib git issues

Because you cannot specify git versions with `-lib` paremeters, we suggest using git submodules instead, as again they provide an adequate way of definining a *versionable* and *replicable* state.

### Combining both approaches

You can of course combine both approaches, giving you the isolation provided by the first one, and the replicability provided by the second one.

### Future solutions

A solution that combines the strengths of both approaches is in the making. Stay tuned.

## Development info

### Running the website for development

Initial compilation and setup:

```
# Initial checkout
git clone https://github.com/HaxeFoundation/haxelib

# Change to the checkout directory
cd haxelib

# Install all the libs
haxelib install newsite.hxml

# Compile the site
haxe legacysite.hxml
haxe newsite.hxml

# copy assets, remember to modify dbconfig.json
cp src/haxelib/server/.htaccess www/
cp src/haxelib/server/dbconfig.json.example www/dbconfig.json
cp src/legacyhaxelib/.htaccess www/legacy/
cp src/legacyhaxelib/website.mtt www/legacy/
cp src/legacyhaxelib/haxelib.css www/legacy/

# If the database (www/legacy/haxelib.db) doesn't exist, run "setup"
pushd www/legacy
neko index.n setup
popd

# Make sure the server folders and databases are writeable.

chmod a+w www
chmod a+w www/tmp
chmod a+w www/files
chmod a+w www/files/3.0
chmod a+w www/legacy
chmod a+w www/haxelib.db
chmod a+w www/legacy/haxelib.db
```

Start a local development server using [Docker](https://www.docker.com/):
```
docker-compose -f test/docker-compose.yml up
```
Make sure "www/dbconfig.json" matches with the config in "test/docker-compose.yml".
The server should now be available at `http://$(docker-machine ip)/`.
To run haxelib client with this local server, prepend the arguments, `-R $SERVER_URL`, to each of the haxelib commands, e.g.:
```
neko bin/haxelib.n -R http://$(docker-machine ip)/ search foo
```

We can keep the server running and try modify the contents in the "www" directory, or even recompile the server code (`haxe server.hxml`). Changes will be picked up immediately.

To run integration tests with the local development server, set `HAXELIB_SERVER` and `HAXELIB_SERVER_PORT` and then compile "integration_tests.hxml":
```
export HAXELIB_SERVER=$(docker-machine ip)
export HAXELIB_SERVER_PORT=80
haxe integration_tests.hxml
```
Note that the integration tests will reset the server database before and after each test.

### About this repo

Build files:

* client.hxml: Build the current haxelib client.
* client_tests.hxml: Build the client tests.
* client_legacy.hxml: Build the haxelib client that works with Haxe 2.x.
* prepare.hxml: Prepare and test the server.
* server.hxml: Build the new website, and the Haxe remoting API.
* server_tests.hxml: Build the new website tests.
* server_each.hxml: Libraries and configs used by server.hxml and server_tests.hxml.
* server_legacy.hxml: Build the legacy website.
* integration_tests.hxml: Build and run tests that test haxelib client and server together.
* haxelib.hxml: Alias of client.hxml.
* package.hxml: Package the client as package.zip for submitting to the lib.haxe.org as [haxelib_client](http://lib.haxe.org/p/haxelib_client/).
* prepare_tests.hxml: Package the test libs.
* ci.hxml: Used by our CIs, TravisCI and AppVeyor.

Folders:

* /src/: Source code for the haxelib tool and the website, including legacy versions.
* /bin/: The compile target for building the haxelib client, legacy client, and others.
* /www/: The compile target (and supporting files) for the haxelib website (including legacy server)
* /test/: Source code and files for testings.
* /package/: Files that are used for bundling the haxelib_client zip file.

Other files:

* schema.json: JSON schema of haxelib.json.
* deploy.json: Deploy configuration used by `haxelib run ufront deploy` for pushing the haxelib website to lib.haxe.org.
* deploy_key.enc: Encrypted ssh private key for logging in to lib.haxe.org. Used by TravisCI.
