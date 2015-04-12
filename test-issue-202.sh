#!/bin/sh
echo "haxelib remove symlinks (issue #202) with nme-dev 1.3.2"
haxelib install nme-dev 1.3.2 --always

HAXELIB_REMOVE_SYM_RESULT="$(haxelib remove nme-dev)"
echo $HAXELIB_REMOVE_SYM_RESULT

if [ "$HAXELIB_REMOVE_SYM_RESULT" = "Library nme-dev removed" ]; then
 echo "     test passed"
 exit 0
else
 echo "     test FAILED"
 exit 1
fi

