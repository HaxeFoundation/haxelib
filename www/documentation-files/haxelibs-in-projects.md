# Adding libraries to Haxe projects

When the haxelib is installed, it is ready to be used it code. This is a matter of adding `--library libraryname` (or `-L libraryname`) to the [compiler arguments](https://haxe.org/manual/compiler-usage.html).

```
haxe --main Main --library libraryname --js bin/main.js
```

The same parameters you pass to the compiler can be stored in a [hxml file](https://haxe.org/manual/compiler-usage-hxml.html):

```
--main Main
--library libraryname
--js bin/main.js
```
<hr/>

## Using Haxelib in OpenFL

When using OpenFL, add `<haxelib />` tags in the project.xml to include Haxe libraries:

```xml
<haxelib name="actuate" />
```

To specify a version:

```xml
<haxelib name="actuate" version="1.0.0" />
```
