/*
 * SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com) and contributors
 * SPDX-FileContributor: Sebastian Thomschke, Vegard IT GmbH
 * SPDX-License-Identifier: Apache-2.0
 */
package haxelib.client.ansi;

/**
 * https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_codes
 */
#if (haxe_ver < 4.3) @:enum #else enum #end
abstract AnsiTextAttribute(Int) {

   /**
    * All colors/text-attributes off
    */
   final RESET = 0;

   final INTENSITY_BOLD = 1;

   /**
    * Not widely supported.
    */
   final INTENSITY_FAINT = 2;

   /**
    * Not widely supported.
    */
   final ITALIC = 3;

   final UNDERLINE_SINGLE = 4;

   final BLINK_SLOW = 5;

   /**
    * Not widely supported.
    */
   final BLINK_FAST = 6;

   final NEGATIVE = 7;

   /**
    * Not widely supported.
    */
   final HIDDEN = 8;

   /**
    * Not widely supported.
    */
   final STRIKETHROUGH = 9;

   /**
    * Not widely supported.
    */
   final UNDERLINE_DOUBLE = 21;

   final INTENSITY_OFF = 22;

   final ITALIC_OFF = 23;

   final UNDERLINE_OFF = 24;

   final BLINK_OFF = 25;

   final NEGATIVE_OFF = 27;

   final HIDDEN_OFF = 28;

   final STRIKTHROUGH_OFF = 29;
}
