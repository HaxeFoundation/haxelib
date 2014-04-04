#!/bin/sh
HAXELIB_PATH=$(dirname $(readlink -f $0))
CLASSPATH=$HAXELIB_PATH/src
exec haxe -cp $CLASSPATH --run tools.haxelib.Main "$@"
