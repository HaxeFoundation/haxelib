#!/bin/bash

mkdir -p package/src/tools/haxelib
cp src/tools/haxelib/Data.hx package/src/tools/haxelib/
cp src/tools/haxelib/Main.hx package/src/tools/haxelib/
cp src/tools/haxelib/Rebuild.hx package/src/tools/haxelib/
cp src/tools/haxelib/SemVer.hx package/src/tools/haxelib/
cp src/tools/haxelib/SiteApi.hx package/src/tools/haxelib/
cp src/tools/haxelib/ConvertXml.hx package/src/tools/haxelib/
cp haxelib.json package/haxelib.json

rm -Rf package/package.zip
cd package
zip -r package.zip *
cd ..
