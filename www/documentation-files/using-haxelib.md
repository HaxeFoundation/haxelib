# Using Haxelib

If the `haxelib` command is executed without any arguments, it prints an exhaustive list of all available arguments. Access the <http://lib.haxe.org> website to view all the libraries available.

The following commands are available:

<div class="row">
<div class="col-md-3">

#### Basic

* [install](#install)
* [upgrade](#upgrade)
* [remove](#remove)
* [list](#list)
* [set](#set)

</div>
<div class="col-md-3">

#### Information

* [search](#search)
* [info](#info)
* [user](#user)
* [config](#config)
* [path](#path)

</div>
<div class="col-md-3">

#### Development

* [submit](#submit)
* [register](#register)
* [local](#local)
* [dev](#dev)
* [git](#git)

</div>
<div class="col-md-3">

#### Miscellaneous

* [run](#run)
* [setup](#setup)
* [selfupdate](#selfupdate)
* [proxy](#proxy)

</div>
</div>



## Basic



<a name="install" class="anch"></a>

#### `haxelib install`


```
haxelib install [project-name] [version]
haxelib install actuate         # Install latest version
haxelib install actuate 1.8.2   # Install specific version
haxelib install actuate.zip     # Install from zip file
haxelib install build.hxml      # Install all dependencies listed in hxml file
haxelib install all             # Install all dependencies in all hxml files
```

> Install the given project. You can optionally specify a specific version to be installed. By default, latest released version will be installed.



<a name="update" class="anch"></a>

#### `haxelib update`

```
haxelib update [project-name]
haxelib update minject
```

> Update a single library to the latest version.



<a name="upgrade" class="anch"></a>

#### `haxelib upgrade`

```
haxelib upgrade
```

> Upgrade all the installed projects to their latest version. This command prompts a confirmation for each upgradeable project.



<a name="remove" class="anch"></a>

#### `haxelib remove`

```
haxelib remove [project-name] [version]
haxelib remove format            # Remove all versions
haxelib remove format 3.1.2      # Remove the specified version
```

> Remove a complete project or only a specified version if specified.



<a name="list" class="anch"></a>

#### `haxelib list`

```
haxelib list [search]
haxelib list                     # List all installed projects
haxelib list ufront              # List all projects with "ufront" in their name
```

> List all the installed projects and their versions. For each project, the version surrounded by brackets is the current one.



<a name="set" class="anch"></a>

#### `haxelib set`

```
haxelib set [project-name] [version]
haxelib set tink_core 1.0.0-rc.8
```

> Change the current version for a given project. The version must be already installed.



## Information



<a name="search" class="anch"></a>

#### `haxelib search`

```
haxelib search [word]
haxelib search tween
```

> Get a list of all haxelib projects with the specified word in the name or description.



<a name="info" class="anch"></a>

#### `haxelib info`

```
haxelib info [project-name]
haxelib info openfl
```

> Show information about this project, including the owner, license, description, website, tags, current version, and release notes for all versions.



<a name="user" class="anch"></a>

#### `haxelib user`

```
haxelib user [user-name]
haxelib user jason
```

> Show information on a given Haxelib user and their projects.



<a name="config" class="anch"></a>

#### `haxelib config`

```
haxelib config
```

> Print the Haxelib repository path. This is where each Haxelib will be installed to.  You can modify the path using `haxelib setup`.



<a name="path" class="anch"></a>

#### `haxelib path`

```
haxelib path [project-name]
haxelib path hscript
haxelib path hscript erazor buddy
```

> Prints the path to one or more libraries, as well as any dependencies and compiler definitions required by those libraries.



## Development



<a name="submit" class="anch"></a>

#### `haxelib submit`

```
haxelib submit [project.zip]
haxelib submit detox.zip
```

> Submits a zip package to Haxelib so other users can install it.
>
> If the user name is unknown, you'll be first asked to register an account.
> If more the project has more than one developer, it will ask you which user you wish to submit as.
> If the user already exists, you will be prompted for your password.
>
> If you want to modify the project url or description, simply modify your `haxelib.json` (keeping version information unchanged) and submit it again.



<a name="register" class="anch"></a>

#### `haxelib register`

```
haxelib register
```

> Register a new developer account.



<a name="local" class="anch"></a>

#### `haxelib local`

```
haxelib local [project.zip]
haxelib install box2d.zip
```

> Install a zip package locally.  This is the same as `haxelib install project.zip`.



<a name="dev" class="anch"></a>

#### `haxelib dev`

```
haxelib dev [project-name] [directory]
haxelib dev starling ../starling/        # Relative path to starling source.
haxelib dev starling /opt/starling/      # Absolute path to starling source.
haxelib dev starling                     # Cancel dev, use installed version.
```

> Set a development directory for the given project.
> This directory should either contain a `haxelib.json` or the source `*.hx` files.
> This command is useful when developing a library and testing changes on a project.



<a name="git" class="anch"></a>

#### `haxelib git`

```
haxelib git [project-name] [git-clone-path] [branch] [subdirectory]
haxelib git minject https://github.com/massiveinteractive/minject.git         # Use HTTP git path.
haxelib git minject git@github.com:massiveinteractive/minject.git             # Use SSH git path.
haxelib git minject git@github.com:massiveinteractive/minject.git v2          # Checkout branch or tag `v2`.
haxelib git minject git@github.com:massiveinteractive/minject.git master src/ # Path to the haxelib.json file.

```

> Use a git repository as library.
>
> This is useful for using a more up-to-date development version, a fork of the original project, or for having a private library that you do not wish to post to Haxelib.
>
> When you use `haxelib upgrade` any libraries that are installed using GIT will automatically pull the latest version.



## Miscellaneous



<a name="run" class="anch"></a>

#### `haxelib run`

```
haxelib run [project-name] [parameters]
haxelib run openfl
haxelib run openfl setup
haxelib run openfl create DisplayingABitmap
```

> If the library has a `run.n` helper, you can execute it using `haxelib run`.
>
> Requires  a pre-compiled Haxe/Neko `run.n` file in the library package.
> This is useful if you want users to be able to do some post-install script that will configure some additional things on the system.
> Be careful to trust the project you are running since the script can damage your system.




<a name="setup" class="anch"></a>

#### `haxelib setup`

```
haxelib setup
```

> Set the Haxelib repository path. To print current path use `haxelib config`.



<a name="selfupdate" class="anch"></a>

#### `haxelib selfupdate`

```
haxelib selfupdate
```

> Update Haxelib itself. On Windows, it will ask to run `haxe update.hxml` after this command has finished, which will complete the upgrade.



<a name="proxy" class="anch"></a>

#### `haxelib proxy`

```
haxelib proxy
```

> Configure Haxelib to use a HTTP proxy.
