#!/bin/bash

# Build the site, copy components over
haxe site.hxml

mkdir -p server/legacy
mkdir -p server/api/2.0

cp src/tools/haxelib/.htaccess server/
cp src/tools/haxelib/website.mtt server/
cp src/tools/haxelib/haxelib.css server/

cp src/tools/legacyhaxelib/.htaccess server/legacy/
cp src/tools/legacyhaxelib/website.mtt server/legacy/
cp src/tools/legacyhaxelib/haxelib.css server/legacy/

cd server
# starting server on port 2000, because binding port 80 requires root privileges,
# which might be a bad idea
nekotools server -rewrite