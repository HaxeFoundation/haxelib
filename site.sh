#!/bin/bash

# Build the site, copy components over

mkdir -p server/legacy
mkdir -p server/api/3.0

haxe site.hxml

cp src/tools/haxelib/.htaccess server/
cp -ar src/tools/haxelib/tmpl server/
cp src/tools/haxelib/haxelib.css server/
cp src/tools/haxelib/dbconfig.json.example server/

cp src/tools/legacyhaxelib/.htaccess server/legacy/
cp src/tools/legacyhaxelib/website.mtt server/legacy/
cp src/tools/legacyhaxelib/haxelib.css server/legacy/

# If the databases don't exist, run "setup"

if [ ! -f server/haxelib.db ];
then
    cd server
    neko index.n setup
    cd ..
fi

if [ ! -f server/legacy/haxelib.db ];
then
    cd server/legacy
    neko index.n setup
    cd ../..
fi

# Make sure the server folders are writeable.  

chmod a+w server
chmod a+w server/tmp
chmod a+w server/files
chmod a+w server/files/3.0
chmod a+w server/legacy
chmod a+w server/haxelib.db
chmod a+w server/legacy/haxelib.db


cd server
# starting server on port 2000, because binding port 80 requires root privileges,
# which might be a bad idea
nekotools server -rewrite
