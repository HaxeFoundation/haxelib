#!/bin/sh
haxe legacyhaxelib.hxml
exec neko bin/legacyhaxelib "$@"
