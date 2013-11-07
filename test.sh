#!/bin/sh
haxe test.hxml
exec neko bin/test.n "$@"
