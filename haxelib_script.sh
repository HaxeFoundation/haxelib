#!/bin/sh
OLDCWD=`pwd`
cd src
exec haxe --run tools.haxelib.Main -cwd $OLDCWD $@
