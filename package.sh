#!/bin/bash

mkdir -p package/tools/haxelib/
cp src/tools/haxelib/Data.hx package/tools/haxelib/
cp src/tools/haxelib/Main.hx package/tools/haxelib/
cp src/tools/haxelib/Rebuild.hx package/tools/haxelib/
cp src/tools/haxelib/SemVer.hx package/tools/haxelib/
cp src/tools/haxelib/SiteApi.hx package/tools/haxelib/
cp src/tools/haxelib/ConvertXml.hx package/tools/haxelib/
cp haxelib.json package/haxelib.json

rm -Rf package/package.zip
cd package
zip -r package.zip haxelib.json tools
cd ..
