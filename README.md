# Haxelib

For more documentation, please refer to [haxe.org](http://haxe.org/haxelib)

[![TravisCI Build Status](https://travis-ci.org/HaxeFoundation/haxelib.svg?branch=master)](https://travis-ci.org/HaxeFoundation/haxelib)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/HaxeFoundation/haxelib?branch=master&svg=true)](https://ci.appveyor.com/project/HaxeFoundation/haxelib)

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

-----

### Running the website for development

(Work in progress instructions, 2015-02-27)

```
# Initial checkout
git clone https://github.com/jasononeil/haxelib.git
git checkout feature/newsite

# Install all the libs
haxelib install newsite.hxml
haxelib git ufront-mvc https://github.com/ufront/ufront-mvc.git

# Create directories
mkdir www
mkdir www/legacy
mkdir www/api/
mkdir www/api/3.0
mkdir www/files/
mkdir www/files/3.0

# TODO: copy assets

# Compile the site
haxe site.hxml
haxe newsite.hxml

# Set up the test database
cd www
neko old.n setup

# TODO: check the permissions, writeable directories etc.

# Start the server
nekotools server -rewrite
```

### About this repo

Build files:

* __haxelib.hxml__: Build the current haxelib tool from src/tools/haxelib/Main
* __legacyhaxelib.hxml__: Build the haxelib tool that works with Haxe 2.x
* __prepare.hxml__: Build a tool to prepare the server (I think)
* __site.hxml__: Build the old website, the legacy website, and the Haxe remoting API.
* __newsite.hxml__: Build the new website, the new site unit tests, and the Haxe remoting API. (Also runs the unit tests).
* __test.hxml__: Build the automated tests.

Folders:

* __/src/__: Source code for the haxelib tool and the website, including legacy versions.
* __/bin/__: The compile target for building the haxelib tool, legacy tool, and site preparation tool.
* __/www/__: The compile target (and supporting files) for the haxelib website (including legacy site and API)
* __/test/__: Unit test source code for running on Travis.
* __/testing/__: A setup for manually testing a complete setup.
* __/package/__: Files that are used for bundling the haxelib_client zip file.
