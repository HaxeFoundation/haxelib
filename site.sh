#!/bin/bash

# Build the site, copy components over

mkdir -p server/legacy
mkdir -p server/api/2.0

haxe site.hxml

cp src/tools/haxelib/.htaccess server/
cp src/tools/haxelib/website.mtt server/
cp src/tools/haxelib/haxelib.css server/

cp src/tools/legacyhaxelib/.htaccess server/legacy/
cp src/tools/legacyhaxelib/website.mtt server/legacy/
cp src/tools/legacyhaxelib/haxelib.css server/legacy/

# Make sure the server folders are writeable.  

chmod o+w server/
chmod o+w server/legacy/

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

cd server
# starting server on port 2000, because binding port 80 requires root privileges,
# which might be a bad idea
nekotools server -rewrite