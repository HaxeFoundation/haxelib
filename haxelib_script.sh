#!/bin/sh
OLDCWD=`pwd`
cd src
exec haxe --run haxelib.client.Main -cwd $OLDCWD $@
