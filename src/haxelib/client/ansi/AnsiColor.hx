/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */
 package haxelib.client.ansi;

#if (haxe_ver < 4.3) @:enum #else enum #end
abstract AnsiColor(Int) {
   final BLACK = 0;
   final RED = 1;
   final GREEN = 2;
   final YELLOW = 3;
   final BLUE = 4;
   final MAGENTA = 5;
   final CYAN = 6;
   final WHITE = 7;
   final DEFAULT = 9;
   final ORANGE = 216;
   final DARK_ORANGE = 215;
   final ORANGE_BRIGHT = 208;
}
