#!/bin/sh
haxe haxelib.hxml
exec neko bin/haxelib "$@"
