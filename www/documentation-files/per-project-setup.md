## Per-project setup

Currently haxelib has two ways to have project local setups.

1. Using `haxelib newrepo`
2. Using `haxelib install all`

### Using haxelib newrepo

When using `haxelib newrepo` you can have a project-local haxelib repository.

Caveats:

- libraries get downloaded for each project

### Using haxelib install all

Haxe allows you to define specific versions of the libraries you want to use with `--library <libname>:<version>`. If you make sure to use this in all your hxmls, then `haxelib install all --always` (the `--always` avoiding you being prompted for confirmation) will be able to ensure the libraries your project needs are available in the necessary versions. If in fact you run this in a checkout hook, your get to track your dependencies in your git repo (some other VCSs should allow for a similar setup), allowing you to have a well defined and replicable setup for any state (commit/branch/etc.).

Disadvantages:

- the approach requires you to define all dependencies with specific versions and then running `haxelib install all` to grab them
- with this approach, any other project that does not have specific versions defined may be affected, as under some circumstances `haxelib install all` may set the global "current" version of the libraries (to be fixed)

Advantages:

- as pointed out above, this approach allows defining a *versionable* and *replicable* state.
- you don't have to download libraries for each project, which does make a difference for heavy weights like openfl and hxcpp

#### Using haxelib with git versions

You can specify git versions with `--library libname:git:https://github.com/user/repo#branch` branch can be a branch or a specific commit SHA.
As alternative, you might use git submodules instead, they also provide an adequate way of definining a *versionable* and *replicable* state.

### Combining both approaches

You can of course combine both approaches, giving you the isolation provided by the first one, and the replicability provided by the second one.

### Future solutions

A solution that combines the strengths of both approaches is in the making. Stay tuned.
