# Haxelib: library manager for Haxe

Haxelib is a library management tool shipped with the [Haxe Toolkit](https://haxe.org/).

It allows searching, installing, upgrading and removing libraries from the [haxelib repository](https://lib.haxe.org/) as well as submitting libraries to it.

For more documentation, please refer to https://lib.haxe.org/documentation/

## Development info

### Running the haxelib server for development

The server has to be compiled with Haxe 3.2.1+. It can be run in Apache using mod_neko / mod_tora.

Currently using [Earthly](https://earthly.dev/) and [Docker](https://www.docker.com/) is the simpliest way to build and run the server. It doesn't require setting up Apache or MySQL since everything is included in the containers. We would recommend to use the [Docker Platform](https://www.docker.com/products/docker) instead of the Docker Toolbox.

To build the server, run:

```
earthly +haxelib-server
```

To start, run:

```
docker-compose -f test/docker-compose.yml up -d
```

The command above will copy the server source code and website resources into a container, compile it, and then start Apache to serve it.  To view the website, visit `http://localhost/` (or `http://$(docker-machine ip)/` if the Docker Toolbox is used).

Since the containers will expose port 80 (web) and 3306 (MySQL), make sure there is no other local application listening to those ports. In case there is another MySQL instance listening to 3306, we will get an error similar to `Uncaught exception - mysql.c(509) : Failed to connect to mysql server`.

To stop the server, run:
```
docker-compose -f test/docker-compose.yml down
```

If we modify any of the server source code or website resources, we need to rebuild the image and replace the running container by issuing the commands as follows:
```
earthly +haxelib-server
docker-compose -f test/docker-compose.yml up -d
```

To run haxelib client with this local server, prepend the arguments, `-R $SERVER_URL`, to each of the haxelib commands, e.g.:
```
neko bin/haxelib.n -R http://localhost/ search foo
```

To run tests:
```
earthly +ci-run
```
Note that the earthly +ci-run target will create and destroy its own database.

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
* package.hxml: Package the client as package.zip for submitting to the lib.haxe.org as [haxelib](https://lib.haxe.org/p/haxelib/).
* prepare_tests.hxml: Package the test libs.
* ci.hxml: Used by our CIs, TravisCI and AppVeyor.

Folders:

* /src/: Source code for the haxelib tool and the website, including legacy versions.
* /bin/: The compile target for building the haxelib client, legacy client, and others.
* /www/: The compile target (and supporting files) for the haxelib website (including legacy server)
* /test/: Source code and files for testings.
* /terraform/: Terraform module that defines the haxelib server (lib.haxe.org) infrastructure.

Other files:

* schema.json: JSON schema of haxelib.json.
* deploy.json: Deploy configuration used by `haxelib run ufront deploy` for pushing the haxelib website to lib.haxe.org.
* deploy_key.enc: Encrypted ssh private key for logging in to lib.haxe.org. Used by TravisCI.
* Earthfile: [Earthly](https://earthly.dev/) build file for building an image for [Visual Studio Code Remote - Containers](https://code.visualstudio.com/docs/remote/containers) and an image for deploying to our infrastructure.
