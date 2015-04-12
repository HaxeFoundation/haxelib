#!/bin/sh
echo "haxelib remove symlinks (issue #202) with nme-dev 1.3.2"
haxelib install nme-dev 1.3.2 --always

if [ "$(haxelib remove nme-dev)" == "Library nme-dev removed" ]; then
 echo "     test passed"
 exit 0
else
 echo "     test FAILED"
 exit 1
fi

