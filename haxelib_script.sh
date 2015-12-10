#!/bin/sh
OLDCWD=`pwd`
cd src
exec haxe --run haxelib.Main -cwd $OLDCWD $@
