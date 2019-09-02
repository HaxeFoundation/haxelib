# Using Haxelib

If the `haxelib` command is executed without any arguments, it prints an exhaustive list of all available arguments.

The following commands are available:

<div class="row">
<div class="span3">
  <h4><a href="#basic">Basic</a></h4>
  <ul>
    <li><a href="#install">install</a></li>
    <li><a href="#update">update</a></li>
    <li><a href="#remove">remove</a></li>
    <li><a href="#list">list</a></li>
    <li><a href="#set">set</a></li>
  </ul>
</div>

<div class="span3">
  <h4><a href="#information">Information</a></h4>
  <ul>
    <li><a href="#search">search</a></li>
    <li><a href="#info">info</a></li>
    <li><a href="#user">user</a></li>
    <li><a href="#config">config</a></li>
    <li><a href="#path">path</a></li>
    <li><a href="#libpath">libpath</a></li>
    <li><a href="#version">version</a></li>
    <li><a href="#help">help</a></li>
  </ul>
</div>

<div class="span3">
  <h4><a href="#development">Development</a></h4>
  <ul>
    <li><a href="#submit">submit</a></li>
    <li><a href="#register">register</a></li>
    <li><a href="#dev">dev</a></li>
    <li><a href="#git">git</a></li>
    <li><a href="#hg">hg</a></li>
  </ul>
</div>
</div>

<div class="row">
<div class="span3">
  <h4><a href="#miscellaneous">Miscellaneous</a></h4>
  <ul>
    <li><a href="#setup">setup</a></li>
    <li><a href="#newrepo">newrepo</a></li>
    <li><a href="#deleterepo">deleterepo</a></li>
    <li><a href="#convertxml">convertxml</a></li>
    <li><a href="#run">run</a></li>
    <li><a href="#proxy">proxy</a></li>
  </ul>
</div>

<div class="span3">
  <h4><a href="#flags">Flags</a></h4>
  <ul>
    <li><a href="#flat">--flat</a></li>
    <li><a href="#always">--always</a></li>
    <li><a href="#system">--system</a></li>
    <li><a href="#debug">--debug</a></li>
    <li><a href="#quiet">--quiet</a></li>
    <li><a href="#never">--never</a></li>
    <li><a href="#global">--global</a></li>
  </ul>
</div>

<div class="span3">
  <h4><a href="#parameters">Parameters</a></h4>
  <ul>
    <li><a href="#cwd">-cwd</a></li>
    <li><a href="#notimeout">-no-timeout</a></li>
    <li><a href="#R">-R</a></li>
  </ul>
</div>
</div>

Also, following environment variables affect haxelib behavior if set:

<div class="row">
<div class="span3">
  <h4><a href="#environment_variables">Environment variables</a></h4>
  <ul>
    <li><a href="#HAXELIB_NO_SSL">HAXELIB_NO_SSL</a></li>
    <li><a href="#HAXELIB_REMOTE">HAXELIB_REMOTE</a></li>
  </ul>
</div>
</div>

<a name="basic" class="anch"></a>

# Basic

<a name="install" class="anch"></a>

## haxelib install

Installs the given project. You can optionally specify a specific version to be installed. By default, latest released version will be installed.

### haxelib install [project-name]
Installs latests released version of the library.
```
haxelib install actuate
```

### haxelib install [project-name] [version]
Installs a specific version of the library.
```
haxelib install actuate 1.8.2
```

### haxelib install all
Install all dependencies in all hxml files
```
haxelib install all
```

### haxelib install [hxml-file]
Install all dependencies listed in hxml file

```
haxelib install build.hxml
```

### haxelib install [library-file]

Install the project contained in the zip file.
```
haxelib install actuate.zip
```

<a name="update" class="anch"></a>

## haxelib update [project-name]

Update a single library to the latest version.
```
haxelib update minject
```

### haxelib update

Update all the installed projects to their latest version. This command prompts a confirmation for each updating project.
```
haxelib update
```


<a name="remove" class="anch"></a>

## haxelib remove

Remove a complete project or only a specified version if specified.
Note: this doesn't remove the library from the registry but from the machine it is installed on.


### haxelib remove [project-name]
Remove all versions of the project
```
haxelib remove format
```

### haxelib remove [project-name] [version]

Remove the specified version
```
haxelib remove format 3.1.2
```

<a name="list" class="anch"></a>

## haxelib list [search]

List all the installed projects and their versions. For each project, the version surrounded by brackets is the current one.

### haxelib list


List all installed projects
```
haxelib list
```

### haxelib list [search]

List all projects with "ufront" in their name
```
haxelib list ufront
```


<a name="set" class="anch"></a>

### haxelib set

```
haxelib set [project-name] [version]
haxelib set tink_core 1.0.0-rc.8
```

> Change the current version for a given project. The version must be already installed.



<a name="information" class="anch"></a>

# Information



<a name="search" class="anch"></a>

### haxelib search

```
haxelib search [word]
haxelib search tween
```

> Get a list of all haxelib projects with the specified word in the name or description.



<a name="info" class="anch"></a>

### haxelib info

```
haxelib info [project-name]
haxelib info openfl
```

> Show information about this project, including the owner, license, description, website, tags, current version, and release notes for all versions.



<a name="user" class="anch"></a>

### haxelib user

```
haxelib user [user-name]
haxelib user jason
```

> Show information on a given Haxelib user and their projects.



<a name="config" class="anch"></a>

### haxelib config

```
haxelib config
```

> Print the Haxelib repository path. This is where each library will be installed to. You can modify the path using <code>haxelib [setup](#setup)</code>.
>
> If you are in a local repository and want to print the global Haxelib repository path do <code>haxelib [--global](#global) config</code>.



<a name="path" class="anch"></a>

### haxelib path

```
haxelib path [project-name[:version]...]
haxelib path hscript
haxelib path hscript:2.0.0
haxelib path hscript erazor buddy
haxelib path hscript erazor buddy:1.0.0
```
Example output :
```
haxelib path openfl hxcpp format
--macro openfl._internal.utils.ExtraParams.include()
/usr/local/lib/haxe/lib/openfl/6.5.3/
-D openfl=6.5.3
/usr/local/lib/haxe/lib/hxcpp/git/
-D hxcpp=3.4.0
/usr/local/lib/haxe/lib/format/3,3,0/
-D format=3.3.0
```

> Prints the source paths to one or more libraries, as well as any dependencies and compiler definitions required by those libraries.
>
> You can specify a version by appending `:version` to the library name. If no version is specified the set version is used.
>
> If a [development](#dev) version is set it'll be used even if a version is specified.
>
> This command is used by Haxe compiler to get required paths and flags for libraries.



<a name="libpath" class="anch"></a>

### haxelib libpath

```
haxelib libpath [project-name[:version]...]
haxelib libpath hscript
haxelib libpath hscript:2.0.0
haxelib libpath hscript erazor buddy
haxelib libpath hscript erazor buddy:1.0.0
```
Example output :
```
haxelib libpath hxcpp format hscript
/usr/local/lib/haxe/lib/hxcpp/git/
/usr/local/lib/haxe/lib/format/3,3,0/
/usr/local/lib/haxe/lib/hxcpp/2,1,1/
```

> Prints the root path of one or more libraries. Will output 1 path per line.
>
> You can specify a version by appending `:version` to the library name. If no version is specified the set version is used.
>
> If a [development](#dev) version is set it'll be used even if a version is specified.



<a name="version" class="anch"></a>

### haxelib version

```
haxelib version
```

> Prints the version of Haxelib you are using.
>
> You can change the version of haxelib you are using with <code>haxelib --global [set](#set) haxelib version</code>



<a name="help" class="anch"></a>

### haxelib help

```
haxelib help
```

> Print the list of available arguments.



<a name="development" class="anch"></a>

# Development



<a name="submit" class="anch"></a>

## haxelib submit

```
haxelib submit [project.zip]
haxelib submit detox.zip
haxelib submit
```

> Submits a zip package to Haxelib so other users can install it.
>
> Alternatively you can run `haxelib submit` without argument to have Haxelib zip and submit the current directory (excluding names starting with a dot).
>
> If the user name is unknown, you'll be first asked to register an account.
> If more the project has more than one developer, it will ask you which user you wish to submit as.
> If the user already exists, you will be prompted for your password.
>
> If you want to modify the project url or description, simply modify your `haxelib.json` (keeping version information unchanged) and submit it again.



<a name="register" class="anch"></a>

### haxelib register

```
haxelib register [username] [email] [fullname] [password] [passwordconfirmation]
```

> Register a new developer account to be used when [submitting](#submit).
>
> Missing parameters will be asked interactively.



<a name="dev" class="anch"></a>

### haxelib dev

```
haxelib dev [project-name] [directory]
haxelib dev starling ../starling/        # Relative path to starling source.
haxelib dev starling /opt/starling/      # Absolute path to starling source.
haxelib dev starling                     # Cancel dev, use installed version.
```

> Set a development directory for the given project.
> This directory should either contain a `haxelib.json` or the source `*.hx` files.
> This command is useful when developing a library and testing changes on a project.
>
> If the directory is omitted the development version of the library will be deactivated.


<a name="git" class="anch"></a>

### haxelib git

```
haxelib git [project-name] [git-clone-path] [branch]
haxelib git minject https://github.com/massiveinteractive/minject.git         # Use HTTP git path.
haxelib git minject git@github.com:massiveinteractive/minject.git             # Use SSH git path.
haxelib git minject git@github.com:massiveinteractive/minject.git v2          # Checkout branch or tag `v2`.
```

> Use a git repository as library.
>
> This is useful for using a more up-to-date development version, a fork of the original project, or for having a private library that you do not wish to post to Haxelib.
>
> When you use `haxelib update` any libraries that are installed using GIT will automatically pull the latest version.



<a name="hg" class="anch"></a>

### haxelib hg

```
haxelib hg [project-name] [mercurial-clone-path] [branch]
```

> Use a mercurial repository as library.
>
> Usage is identical to <code>haxelib [git](#git)</code>.



<a name="miscellaneous" class="anch"></a>

# Miscellaneous



<a name="setup" class="anch"></a>

### haxelib setup

```
haxelib setup [path]
```

> Set the Haxelib repository path. To print current path use <code>haxelib [config](#config)</code>.
>
> Missing parameter will be asked interactively.



<a name="newrepo" class="anch"></a>

### haxelib newrepo

```
haxelib newrepo
```

> Create a local repository in the current directory, to remove it use <code>haxelib [deleterepo](#deleterepo)</code>.
>
> [Basic](#basic) commands will only use the libraries stored in the local repository when you are located in this directory.
>
> To access the global repository add the <code>[--global](#global)</code> flag.



<a name="deleterepo" class="anch"></a>

### haxelib deleterepo

```
haxelib deleterepo
```

> Remove a local repository created with <code>haxelib [newrepo](#newrepo)</code> from the current directory.
>
> This will remove all libraries contained in it.



<a name="convertxml" class="anch"></a>

### haxelib convertxml

```
haxelib convertxml
```

> Convert the file `haxelib.xml` from the current directory in the Haxelib 2 xml specification into a file named `haxelib.json` which can be used by the current Haxelib.


<a name="run" class="anch"></a>

### haxelib run

```
haxelib run [project-name[:version]] [parameters]
haxelib run openfl
haxelib run openfl:2.6.0
haxelib run openfl setup
haxelib run openfl create DisplayingABitmap
```

> Libraries with either a `run.n` helper or a main class defined in `haxelib.json`, can be executed using `haxelib run`.
>
> You can specify the version to run by appending `:version`, if the library has a [development](#dev) version set the version will be ignored.
>
> The library will receive the `HAXELIB_RUN` environment variable with value `"1"` and `HAXELIB_RUN_NAME` with the name of the library as value.


<a name="proxy" class="anch"></a>

### haxelib proxy

```
haxelib proxy [host port [username password]]
```

> Configure Haxelib to use a HTTP proxy.
>
> Missing parameters will be asked interactively.
>
> Rerun with an empty host to deactivate the current proxy.



<a name="flags" class="anch"></a>

## Flags



**Warning**: when using the [run](#run) command you need to specify the flags before `run`,
otherwise they'll be passed as arguments to the library.



<a name="flat" class="anch"></a>

### haxelib --flat

```
haxelib --flat
```

> Used by <code>haxelib [git](#git)</code>, do not add the `--recursive` flag when cloning a git repository.



<a name="always" class="anch"></a>

### haxelib --always

```
haxelib --always
```

> Answer all questions with yes, cannot be used at the same time as [--never](#never).



<a name="system" class="anch"></a>

### haxelib --system

```
haxelib --system
```

> Use the version of Haxelib installed with Haxe in the system instead of the one currently [set](#set).
>
> Useful if your Haxelib update was broken.



<a name="debug" class="anch"></a>

### haxelib --debug

```
haxelib --debug
```

> Display debug information during the execution, cannot be used at the same time as [--quiet](#quiet).



<a name="quiet" class="anch"></a>

### haxelib --quiet

```
haxelib --quiet
```

> Display less messages during the execution, cannot be used at the same time as [--debug](#debug).



<a name="never" class="anch"></a>

### haxelib --never

```
haxelib --never
```

> Answer all questions with no, cannot be used at the same time as [--always](#always).



<a name="global" class="anch"></a>

### haxelib --global

```
haxelib --global
```

> Force the usage of the global repository even if inside a local repository created with <code>haxelib [newrepo](#newrepo)</code>.



<a name="parameters" class="anch"></a>

# Parameters



**Warning**: when using the [run](#run) command you need to specify the parameters before `run`,
otherwise they'll be passed as arguments to the library.



<a name="cwd" class="anch"></a>

### haxelib -cwd

```
haxelib -cwd [dir]
```

> Act like the Haxelib command was run from another repository. Affect all commands that use the "current directory".



<a name="notimeout" class="anch"></a>

### haxelib -no-timeout

```
haxelib -no-timeout
```

> Remove timeout when connecting to the Haxelib server, downloading or [submitting](#submit) a library.



<a name="R" class="anch"></a>

### haxelib -R

```
haxelib -R [host:port[/dir]]
```

> Allow the usage of a custom Haxelib server instead of `lib.haxe.org`.

<a name="environment_variables" class="anch"></a>

# Environment Variables

<a name="HAXELIB_NO_SSL" class="anch"></a>

## HAXELIB_NO_SSL

If `HAXELIB_NO_SSL` is set to `1` or `true`, then haxelib client will use http instead of https.

## HAXELIB_REMOTE

`HAXELIB_REMOTE` may contain a url to a custom Haxelib server instead of `https://lib.haxe.org/`.
However, if <a href="#R">-R</a> command line argument is provided, then `HAXELIB_REMOTE` is ignored.