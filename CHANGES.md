## 4.0.0 (2019-10-10)

 - Added `haxelib libpath` command (#407)
 - Allow forcing proxy configuration if proxy test failed (#411)
 - Use version specified by `-lib library:1.2.3` even if currently active one is `dev`
 - Strip comments from extraParams.hxml for `haxelib path` (#439)
 - Automatically retry failing downloads 3 times
 - Allow environment variables in dev paths using `%VAR_NAME%` syntax. E.g.: `/path/to/%MY_ENV_VAR%/lib`
 - Handle HAXELIB_NO_SSL environment variable to disable https on requests to haxelib server (#448)
 - Added `--skip-dependencies` option (#343)
 - Look for `.haxelib` local repo recursively up along the directories tree (#292)

## 3.4.0 (2017-01-31)

 - Fix password input issue in Windows (#421)
 - Only use 'dev' version when no explicit version ask or version not installed
 - Add ability to ignore proxy test failure (#413)
 - Improved file download to support 3 retries and http redirections
 - Default to use https to access lib.haxe.org
 - Add `haxelib libpath` (#410)
 - Remove progress output if `--quiet` (#373)
 - Include commit hash in `haxelib version` when build from git source
 - Support git dependencies (#344)

## 3.3.0 (2016-05-28)

 - New haxelib self-updating mechanism (#172, #293)
 - Haxelib new version notification (#282)
 - Partial download resume support (#133)
 - Respect `-notimeout` for uploading and downloading files (#235)
 - `haxelib run` now sets `HAXELIB_RUN_NAME` environment variable to the library name (#293)
 - Fixed order of library versions in `haxelib list` (#83)
 - Merged `upgrade` and `update` commands (#188)
 - Deprecated now redundant commands: `local`, `selfupdate` (#288)
 - Fixed suggested repository path on Linux (#242)
 - Suggested repository path on OSX is now `/usr/local/lib/haxe/lib` (#250)
 - `haxelib install <file>.hxml` now checks hxml files recursively (#200)
 - Git/Hg checkouts don't set dev mode unless subdir is specified now (#263)
 - Tons of smaller fixes, cleanups and optimizations
