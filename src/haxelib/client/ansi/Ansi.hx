package haxelib.client.ansi;


 /**
  * https://en.wikipedia.org/wiki/ANSI_escape_code
  * http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/c327.html
  * http://ascii-table.com/ansi-escape-sequences.php
  */
 class Ansi {
 
    /**
     * ANSI escape sequence header
     */
    public static inline final ESC = "\x1B[";

    inline
    public static function reset(str:String):String
       return str + ESC + "0m";
 
 
    /**
     * sets the given text attribute
     */
    inline
    public static function attr(str:String, attr:AnsiTextAttribute):String
       return ESC + (attr) + "m" + str;
 
 
    /**
     * set the text background color
     *
     * <pre><code>
     * >>> Ansi.bg(RED) == "\x1B[41m"
     * </code></pre>
     */
    inline
    public static function bg(str: String, color:AnsiColor):String
       return ESC + "4" + color + "m" + str;
 
 
    /**
     * Clears the screen and moves the cursor to the home position
     */
    inline
    public static function clearScreen():String
       return ESC + "2J";
 
 
    /**
     * Clear all characters from current position to the end of the line including the character at the current position
     */
    inline
    public static function clearLine():String
       return ESC + "K";
 
 
    /**
     * set the text foreground color
     *
     * <pre><code>
     * >>> Ansi.fg(RED) == "\x1B[31m"
     * </code></pre>
     */
    inline
    public static function fg(str: String, color:AnsiColor):String
       return ESC + "38;5;" + color + "m" + str;
 
 }
 