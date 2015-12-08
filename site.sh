#!/bin/bash

# See README.md for initial setup instructions.

# Make sure our output directories exist

mkdir -p www/legacy
mkdir -p www/api/3.0
mkdir -p www/files/3.0

# Compile the old site first, to get the legacy API etc, and then the new site.

haxe site.hxml
haxe newsite.hxml

# Copy various assets

cp src/tools/haxelib/.htaccess www/
cp -ar src/tools/haxelib/tmpl www/
cp src/tools/haxelib/haxelib.css www/
cp src/tools/haxelib/dbconfig.json.example www/

cp src/tools/legacyhaxelib/.htaccess www/legacy/
cp src/tools/legacyhaxelib/website.mtt www/legacy/
cp src/tools/legacyhaxelib/haxelib.css www/legacy/

# If the databases don't exist, run "setup"

if [ ! -f www/haxelib.db ];
then
    cd www
    neko old.n setup
    cd ..
fi

if [ ! -f www/legacy/haxelib.db ];
then
    cd www/legacy
    neko index.n setup
    cd ../..
fi

# Make sure the server folders are writeable.  

chmod a+w www
chmod a+w www/tmp
chmod a+w www/files
chmod a+w www/files/3.0
chmod a+w www/legacy
chmod a+w www/haxelib.db
chmod a+w www/legacy/haxelib.db


cd www

# starting server on port 2000, because binding port 80 requires root privileges,
# which might be a bad idea
nekotools server -rewrite
