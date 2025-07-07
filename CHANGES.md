## 4.2.0 (2025-07-04)

### Features

- Document haxelib.client and haxelib packages ([#548](https://github.com/HaxeFoundation/haxelib/pull/548))
- Add `fixrepo` command to deal with capitalisation bugs ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Added --no-timeout alias to --notimeout and --remote alias to -R ([#553](https://github.com/HaxeFoundation/haxelib/pull/553))
- Print which haxelib is used when in debug mode ([#555](https://github.com/HaxeFoundation/haxelib/pull/555))
- Add support for hg dependencies ([#557](https://github.com/HaxeFoundation/haxelib/pull/557))
- List allowed licenses when license is invalid ([#559](https://github.com/HaxeFoundation/haxelib/pull/559))
- Add `state save` and `state load` commands ([#610](https://github.com/HaxeFoundation/haxelib/issues/610))
- Allow compiling client with hxcpp target ([#643](https://github.com/HaxeFoundation/haxelib/issues/643))
- Add check for library submissions containing .git folders ([#664](https://github.com/HaxeFoundation/haxelib/issues/664))
- Add support for -preview version tags ([20199d4](https://github.com/HaxeFoundation/haxelib/commit/20199d4e6c1eec17286efdc52067ad6ff94bb3d7))

### Bug fixes

GENERAL

- Fix minor typos in error/help messages ([#550](https://github.com/HaxeFoundation/haxelib/pull/550))
- Fix missing git/hg error output in `--debug` mode ([#550](https://github.com/HaxeFoundation/haxelib/pull/550))
- Show error for invalid switches ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Fix downloads when using HAXELIB_NO_SSL ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- `--quiet` and `--debug` are considered mutually exclusive ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Give errors when a command is given too many arguments ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Fix `--cwd` option when system haxelib passes onto updated haxelib ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Library names are case insensitive everywhere ([#529](https://github.com/HaxeFoundation/haxelib/issues/529), [#465](https://github.com/HaxeFoundation/haxelib/issues/465) and [#503](https://github.com/HaxeFoundation/haxelib/issues/503))
- Fix flags that only worked with one dash ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Don't assume MIT if haxelib.json fails to parse ([#554](https://github.com/HaxeFoundation/haxelib/pull/554))
- Don't allow libraries to be published with git dependencies ([#554](https://github.com/HaxeFoundation/haxelib/pull/554))

API

- Add `haxelib.api` package with haxelib client functionality ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

PATH and LIBPATH and RUN

- Show an error if a non-existent version is specified ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

RUN

- Fix specifying a version not working if a development directory is set ([#510](https://github.com/HaxeFoundation/haxelib/pull/510), see also [#249](https://github.com/HaxeFoundation/haxelib/pull/249))
- Fix version check breaking on old versions of haxe ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Get compiler version for run scripts lazily ([#646](https://github.com/HaxeFoundation/haxelib/issues/646))

PATH

- Maintain input order for conflicting library version error ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

LIST

- Libraries are now correctly ordered alphabetically ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Do not list invalid versions ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

INSTALL

- Don't auto-install a target backend lib if it's specified manually ([#511](https://github.com/HaxeFoundation/haxelib/issues/511))
- Fix auto-install target backend lib with double dash ([9f7f851](https://github.com/HaxeFoundation/haxelib/commit/9f7f8518e2472c0e7bf2a4e1cde0cbe74b1bfb90))
- Check for hashlink target when installing from hxml ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Fix incorrect `--skip-dependencies` behaviour with haxelib.json ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Prevent installing repeated library versions from hxml ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- List libraries in order they appear when installing from hxmls ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
- Exit with error when hxml install fails ([#625](https://github.com/HaxeFoundation/haxelib/issues/625))

SET

- Fix proxy not loading for installs via `haxelib set` ([#550](https://github.com/HaxeFoundation/haxelib/pull/550))
- Prevent setting invalid library versions ([#526](https://github.com/HaxeFoundation/haxelib/issues/526))

UPDATE

- Prevent updating git/hg version if it is not set as current ([#364](https://github.com/HaxeFoundation/haxelib/issues/364))
- Don't show update message if vcs lib was already up to date ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

REMOVE

- Prevent removal of git/hg version if there is a dev version set within it ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))

DEV, GIT and HG

- Fix error during mercurial update ([#550](https://github.com/HaxeFoundation/haxelib/pull/550))
- Prevent giving invalid name when using these commands ([#357](https://github.com/HaxeFoundation/haxelib/issues/357))
- -D library name is always taken from `haxelib.json` rather than install name ([#510](https://github.com/HaxeFoundation/haxelib/pull/510))
 - Change the order of haxelib git submodule installation ([#638](https://github.com/HaxeFoundation/haxelib/issues/638))
 - Fix crashes with git commands on Windows ([#642](https://github.com/HaxeFoundation/haxelib/issues/642))

## 4.1.1 (2025-04-15)

 - Fixed large git installations hanging on non-Windows systems

## 4.1.0 (2023-04-06)

 - Added support for documenting custom defines and metadata ([#573](https://github.com/HaxeFoundation/haxelib/pull/573))
 - Fixed a segmentation fault on Linux systems

## 4.0.3 (2023-02-27)
 - Fixed large git installations hanging on windows ([#585](https://github.com/HaxeFoundation/haxelib/pull/585))
 - Corrected license in haxelib.json ([#535](https://github.com/HaxeFoundation/haxelib/pull/535))

## 4.0.2 (2019-11-11)
 - Fixed too strict requirements to haxelib.json data for private libs ([#484](https://github.com/HaxeFoundation/haxelib/issues/484))

## 4.0.1 (2019-11-02)
 - Fixed git dependencies support in haxelib.json ([#476](https://github.com/HaxeFoundation/haxelib/issues/476))

## 4.0.0 (2019-10-10)

 - Added `haxelib libpath` command ([#407](https://github.com/HaxeFoundation/haxelib/issues/407))
 - Allow forcing proxy configuration if proxy test failed ([#411](https://github.com/HaxeFoundation/haxelib/issues/411))
 - Use version specified by `-lib library:1.2.3` even if currently active one is `dev`
 - Strip comments from extraParams.hxml for `haxelib path` ([#439](https://github.com/HaxeFoundation/haxelib/issues/439))
 - Automatically retry failing downloads 3 times
 - Allow environment variables in dev paths using `%VAR_NAME%` syntax. E.g.: `/path/to/%MY_ENV_VAR%/lib`
 - Handle HAXELIB_NO_SSL environment variable to disable https on requests to haxelib server ([#448](https://github.com/HaxeFoundation/haxelib/issues/448))
 - Added `--skip-dependencies` option ([#343](https://github.com/HaxeFoundation/haxelib/issues/343))
 - Look for `.haxelib` local repo recursively up along the directories tree ([#292](https://github.com/HaxeFoundation/haxelib/issues/292))

## 3.4.0 (2017-01-31)

 - Fix password input issue in Windows ([#421](https://github.com/HaxeFoundation/haxelib/issues/421))
 - Only use 'dev' version when no explicit version ask or version not installed
 - Add ability to ignore proxy test failure ([#413](https://github.com/HaxeFoundation/haxelib/issues/413))
 - Improved file download to support 3 retries and http redirections
 - Default to use https to access lib.haxe.org
 - Add `haxelib libpath` ([#410](https://github.com/HaxeFoundation/haxelib/issues/410))
 - Remove progress output if `--quiet` ([#373](https://github.com/HaxeFoundation/haxelib/issues/373))
 - Include commit hash in `haxelib version` when build from git source
 - Support git dependencies ([#344](https://github.com/HaxeFoundation/haxelib/issues/344))

## 3.3.0 (2016-05-28)

 - New haxelib self-updating mechanism ([#172](https://github.com/HaxeFoundation/haxelib/issues/172), [#293](https://github.com/HaxeFoundation/haxelib/issues/293))
 - Haxelib new version notification ([#282](https://github.com/HaxeFoundation/haxelib/issues/282))
 - Partial download resume support ([#133](https://github.com/HaxeFoundation/haxelib/issues/133))
 - Respect `-notimeout` for uploading and downloading files ([#235](https://github.com/HaxeFoundation/haxelib/issues/235))
 - `haxelib run` now sets `HAXELIB_RUN_NAME` environment variable to the library name ([#293](https://github.com/HaxeFoundation/haxelib/issues/293))
 - Fixed order of library versions in `haxelib list` ([#83](https://github.com/HaxeFoundation/haxelib/issues/83))
 - Merged `upgrade` and `update` commands ([#188](https://github.com/HaxeFoundation/haxelib/issues/188))
 - Deprecated now redundant commands: `local`, `selfupdate` ([#288](https://github.com/HaxeFoundation/haxelib/issues/288))
 - Fixed suggested repository path on Linux ([#242](https://github.com/HaxeFoundation/haxelib/issues/242))
 - Suggested repository path on OSX is now `/usr/local/lib/haxe/lib` ([#250](https://github.com/HaxeFoundation/haxelib/issues/250))
 - `haxelib install <file>.hxml` now checks hxml files recursively ([#200](https://github.com/HaxeFoundation/haxelib/issues/200))
 - Git/Hg checkouts don't set dev mode unless subdir is specified now ([#263](https://github.com/HaxeFoundation/haxelib/issues/263))
 - Tons of smaller fixes, cleanups and optimizations
