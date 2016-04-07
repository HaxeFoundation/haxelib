# Creating a haxelib package

Each haxelib package is essentially a zip folder containing source code, supporting files, and a `haxelib.json` file.

### haxelib.json

Each Haxe library requires a `haxelib.json` file in which the following attributes are defined:

* name: The name of the library. It must contain at least 3 characters among the following: `[A-Za-z0-9_-.]`. In particular, no spaces are allowed.
* url: The URL of the library, i.e. where more information can be found.
* license: The license under which the library is released. Can be `GPL`, `LGPL`, `BSD`, `Public` (for Public Domain) or `MIT`.
* tags: An array of tag-strings which are used on the repository website to sort libraries.
* description: The description of what the library is doing.
* version: The version string of the library. This is detailed in [Versioning](#versioning).
* classPath: The path string to the source files.
* releasenote: The release notes of the current version.
* contributors: An array of user names which identify contributors to the library.
* dependencies: An object describing the dependencies of the library. This is detailed in [Dependencies](haxelib-json-dependencies.md).

The following JSON is a simple example of a haxelib.json:

```haxe
{
  "name": "useless_lib",
  "url" : "https://github.com/jasononeil/useless/",
  "license": "MIT",
  "tags": ["cross", "useless"],
  "description": "This library is useless in the same way on every platform.",
  "version": "1.0.0",
  "classPath": "src/",
  "releasenote": "Initial release, everything is working correctly.",
  "contributors": ["Juraj","Jason","Nicolas"],
  "dependencies": {
    "tink_macro": "",
    "nme": "3.5.5"
  }
}
```

<a name="versioning"></a>

### Versioning

Haxelib uses a simplified version of [SemVer](http://semver.org/). The basic format is this:

```
major.minor.patch
```

These are the basic rules:

* Major versions are incremented when you break backwards compatibility - so old code will not work with the new version of the library.
* Minor versions are incremented when new features are added.
* Patch versions are for small fixes that do not change the public API, so no existing code should break.
* When a minor version increments, the patch number is reset to 0. When a major version increments, both the minor and patch are reset to 0.

Examples:

* "0.0.1": A first release.  Anything with a "0" for the major version is subject to change in the next release - no promises about API stability!
* "0.1.0": Added a new feature!   Increment the minor version, reset the patch version
* "0.1.1": Realised the new feature was broken.  Fixed it now, so increment the patch version
* "1.0.0": New major version, so increment the major version, reset the minor and patch versions.   You promise your users not to break this API until you bump to 2.0.0
* "1.0.1": A minor fix
* "1.1.0": A new feature
* "1.2.0": Another new feature
* "2.0.0": A new version, which might break compatibility with 1.0.  Users are to upgrade cautiously.

If this release is a preview (Alpha, Beta or Release Candidate), you can also include that, with an optional release number:

```
major.minor.patch-(alpha/beta/rc).release
```

Examples:

* "1.0.0-alpha": The alpha of 1.0.0 - use with care, things are changing!
* "1.0.0-alpha.2": The 2nd alpha
* "1.0.0-beta": Beta - things are settling down, but still subject to change.
* "1.0.0-rc.1": The 1st release candidate for 1.0.0 - you shouldn't be adding any more features now
* "1.0.0-rc.2": The 2nd release candidate for 1.0.0
* "1.0.0": The final release!

### extraParams.hxml

If you add a file named `extraParams.hxml` to your library root (at the same level as `haxelib.json`), these parameters will be automatically added to the compilation parameters when someone use your library with `-lib`.

### Submission process

* During development: Use `haxelib dev my_test_haxelib /path/to/my_test_haxelib/` to test the library.
* Ready to test: Zip the current directory, and use `haxelib install my_test_haxelib.zip` to try the final version.
- Submit: You can run `haxelib submit my_test_haxelib.zip` to submit the zip file to haxelib. Alternatively you can run `haxelib submit` without a zip file to have haxelib zip and submit the current directory.
