[![TravisCI Build Status](https://travis-ci.org/HaxeFoundation/haxelib.svg?branch=development)](https://travis-ci.org/HaxeFoundation/haxelib)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/HaxeFoundation/haxelib?branch=development&svg=true)](https://ci.appveyor.com/project/HaxeFoundation/haxelib)

# Haxelib: library manager for Haxe

Haxelib is a library management tool shipped with the [Haxe Toolkit](http://haxe.org/).

It allows searching, installing, upgrading and removing libraries from the [haxelib repository](http://lib.haxe.org/) as well as submitting libraries to it.

For more documentation, please refer to http://lib.haxe.org/documentation/

## Development info

### Running the haxelib server for development

The server has to be compiled with Haxe 3.2.1+. It can be run in Apache using mod_neko / mod_tora.

Currently using [Docker](https://www.docker.com/) is the simpliest way to build and run the server. It doesn't require setting up Apache or MySQL since everything is included in the container.

To start, run:

```
docker-compose -f test/docker-compose.yml up
```

The command above will copy the server source code and website resources into a container, compile it, and then start Apache to serve it.  To view the website, visit `http://$(docker-machine ip):2000/` (Windows and Mac) or `http://localhost:2000/` (Linux).

To stop the server, run:
```
docker-compose -f test/docker-compose.yml down
```

If we modify any of the server source code or website resources, we need to stop the server and then rebuild the image by running the command as follows:
```
docker-compose -f test/docker-compose.yml build
```

To run haxelib client with this local server, prepend the arguments, `-R $SERVER_URL`, to each of the haxelib commands, e.g.:
```
neko bin/haxelib.n -R http://$(docker-machine ip):2000/ search foo
```

To run integration tests with the local development server:
```
# prepare the test files
haxe prepare_tests.hxml

# set `HAXELIB_SERVER` and `HAXELIB_SERVER_PORT`
# note that `HAXELIB_SERVER` is also used for the tests to connect to the MySQL server for resetting database
export HAXELIB_SERVER=$(docker-machine ip)
export HAXELIB_SERVER_PORT=2000

# run the tests
haxe integration_tests.hxml
```
Note that the integration tests will reset the server database before and after each test.

### About this repo

Build files:

* client.hxml: Build the current haxelib client.
* client_tests.hxml: Build and run the client tests.
* client_legacy.hxml: Build the haxelib client that works with Haxe 2.x.
* server.hxml: Build the new website, and the Haxe remoting API.
* server_tests.hxml: Build and run the new website tests.
* server_each.hxml: Libraries and configs used by server.hxml and server_tests.hxml.
* server_legacy.hxml: Build the legacy website.
* integration_tests.hxml: Build and run tests that test haxelib client and server together.
* package.hxml: Package the client as package.zip for submitting to the lib.haxe.org as [haxelib](http://lib.haxe.org/p/haxelib/).
* prepare_tests.hxml: Package the test libs.
* ci.hxml: Used by our CIs, TravisCI and AppVeyor.

Folders:

* /src/: Source code for the haxelib tool and the website, including legacy versions.
* /bin/: The compile target for building the haxelib client, legacy client, and others.
* /www/: The compile target (and supporting files) for the haxelib website (including legacy server)
* /test/: Source code and files for testings.

Other files:

* schema.json: JSON schema of haxelib.json.
* deploy.json: Deploy configuration used by `haxelib run ufront deploy` for pushing the haxelib website to lib.haxe.org.
* deploy_key.enc: Encrypted ssh private key for logging in to lib.haxe.org. Used by TravisCI.
* Dockerfile: Docker build file for building an image that runs the haxelib server.
