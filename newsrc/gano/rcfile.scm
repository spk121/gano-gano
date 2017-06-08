;;; The rcfile will be processed on startup.

;;; First, it will read the SYSCONFDIR/ganorc
;;; Then the per-configuration file .nanorc

;;; The rc file should include this very file (gano rcfile)
;;; so that it has access to the following rc-file-specific
;;; functions


(define (autoindent bool)
  "When true, use auto-identation")
(define (backup bool)
  "When true, create backup files in filename~"
  )
(define (backupdir directory)
  "Set the directory where nano puts unique backup files if file
backups are enabled."  )
(define (backwards bool)
  "Do backwards searches by default.")
(define (boldtext bool)
  "Use bold text instead of reverse video text."
  )
(define (brackets str)
  "Set the characters treated as closing brackets when justifying
paragraphs. They cannot contain blank characters. Only closing
punctuation, optionally followed by closing brackets, can end
sentences. The default value is "".)>]}".
  )

(define (casesensitive bool)
  "Do case sensitive searchesby default"
  )

(define (const bool)
  "Constantly display the cursor position in the status bar."
  )

(define (cut bool)
  "Use cut to end of line by default."
  )

(define (fill n)
  " Wrap lines at column number n. If n is 0 or less, the maximum line
length will be the screen width less n columns. The default value is
-8."
  )

(define (historylog bool)
  ("Enable ~/.nano_history for saving and reading search/replace strings."
   ))

(define (matchbrackets str)
  " Set the opening and closing brackets that can be found by bracket
searches. They cannot contain blank characters. The former set must
come before the latter set, and both must be in the same order. The
default value is '(<[{)>]}'."
  )

(define (morespace str)
  "Use the blank line below the titlebar as extra editing space."
  )

(define (mouse bool)
  " Enable mouse support, if available for your system. When enabled,
mouse clicks can be used to place the cursor, set the mark (with a
double click), and execute shortcuts. The mouse will work in the X
Window System, and on the console when gpm is running."
  )

(define (multibuffer bool)
  "Allow inserting files into their own buffers."
  )

(define (noconvert bool)
  "Don.t convert files from DOS/Mac format."
  )

(define (nofollow bool)
  "Don.t follow symlinks when writing files."
  )

(define (nohelp bool)
  "Don.t display the help lists at the bottom of the screen."
  )

(define (nonewlines bool)
  "Don.t add newlines to the ends of files."
  )

(define (nowrap bool)
  "Don.t wrap text at all."
  )

(define (operatingdir directory)
  " nano will only read and write files inside directory and its
subdirectories. Also, the current directory is changed to here, so
files are inserted from this diractory. By default, the operating
directory feature is turned off."
  )

(define (preserve bool)
  "Preserve the XON and XOFF keys (^Q and ^S)."
  )

(define (punct string)
  " Set the characters treated as closing punctuation when justifying
paragraphs. They cannot contain blank characters. Only closing
punctuation, optionally followed by closing brackets, can end
sentences. The default value is '!.?'."
  )

(define (quiet bool)
  "nano will not report errors in the nanorc file and ask them to be
acknowledged by pressing enter at startup. If this is used it should
be placed at the top of the file to be fully effective."
  )

(define (quickblank bool)
  "Do quick statusbar blanking. Statusbar messages will disappear
after 1 keystroke instead of 25."
  )

(define (quotestr str)
  "The email-quote string, used to justify email-quoted
paragraphs. This is an extended regular expression if your system
supports them, otherwise a literal string. The default value is '^([
\t]*[#:>\|}])+' if you have extended regular expression support,
or '> ' otherwise. Note that .\t. stands for a literal Tab character."
  )

(define (rebinddelete bool)
  "Interpret the Delete key differently so that both Backspace and
Delete work properly. You should only need to use this option if
Backspace acts like Delete on your system."
  )

(define (rebindkeypad bool)
  "Interpret the numeric keypad keys so that they all work properly. You should only need to use this option if they don.t, as mouse support won.t work properly with this option enabled."
  )

(define (regexp bool)
  "Do extended regular expression searches by default."
  )

(define (smarthome bool)
  "Make the Home key smarter. When Home is pressed anywhere but at the
very beginning of non-whitespace characters on a line, the cursor will
jump to that beginning (either forwards or backwards). If the cursor
is already at that position, it will jump to the true beginning of the
line."
  )

(define (smooth bool)
  "Use smooth scrolling by default."
  )

(define (softwrap bool)
  "Enable soft line wrapping for easier viewing of very long lones."
  )

(define (speller prog)
  "Use spelling checker spellprog instead of the built-in one, which
calls spell."
  )

(define (suspend bool)
  "Allow nano to be suspended."
  )

(define (tabsize n)
  "Use a tab size of n columns. The value of n must be greater than
0. The default value is 8."
  )

(define (tabstospaces bool)
  "Convert typed tabs to spaces."
  )

(define (tempfile bool)
  "Save automatically on exit, don.t prompt."
  )

(define (undo bool)
  "Enable experimental generic-purpose undo code.
")

(define (view bool)
  "Disallow file modifcation")
)

(define (whitespace str)
  "Sets the two characters to be use to display the first characters of tabs
and spaces.  They must be single column characters.")

(define (wordbounds bool)
  "Detect word boundaries more accurately by treating punctuation characters as parts of words."
  )

(define (syntax name (list (regex regex2 flags fgcolor bright? bgcolor) ...))

"A syntax is a name and a list of mappings of regexes to colors.

For each regex entry, If regex is specified and regex2 is the empty
string, every string that matches the regex will be painted using the
fgcolor/ bcolor pair.

If regex and regex2 are both specified, then everything between a match
for regex and regex2 will be painted using the fgcolor /bcolor pair
"
)

;; KEY BINDINGS


;; Key bindings may be reassigned via the following commands:

(define (bind key function menu)
  "Rebinds the key key to a new function named function in the context of menu menu. The format of KEY is a string that contains one of
<caret> + <alphabetic>
<caret> + <Space>
'M-' + <printable>
'M-' + <space>
F + <number>


Valid function names to be bound include:
help: Invoke the help menu.
cancel: Cancel the current command.
exit :Exit from the program.
writeout :Write the current buffer to disk.
justify :ustify the current text.
insert: Insert a file into the current buffer (or into a new buffer when multibuffer is enabled).
whereis: search for text in the current buffer.
searchagain :Repeat the last search command.
up: Move up in the editor or browser.

down: Move down in the editor or browser.
left: Move left in the editor or browser.
right: Move right in the editor or browser.
cut: Cut the current line of text and store it.
uncut: Copy the currently stored text into the current buffer position.
curpos: Show the current line, column, word positions in the file.
firstline: Move to the first line of the file.
lastline: Move to the last line of the file.
gotoline: Move to a specific line (and column if specified).
replace: Interactively replace text within the current buffer.
mark: Begin selecting text for cutting or pasting at the current position.
copytext:Copy the currently marked text without deleting it.
indent: Indent the currently marked text (shift to the right).
unindent: Un-indent the currently marked text (shift to the left).
nextword: Move the cursor to the beginning of the next word.
prevword: Move the cursor to the beginning of the previous word.
home: Move the cursor to the beginning of the current line.
end: Move the cursor to the end of the current line.
beginpara: Move the cursor to the beginning of the current paragraph.
endpara: Move the cursor to the end of the current paragraph.
findbracket: Move the cursor to the matching bracket (brace,
parenthesis, etc.) of the one under the cursor.
scrollup: Scroll up one line of text from the current position.
scrolldown: Scroll down one line of text from the current position.
prevbuf: Switch to editing/viewing the previous buffer when using multibuffer mode.
nextbuf: Switch to editing/viewing the next buffer when using multibuffer mode.
verbatim: Insert the next character verbatim into the file.
tab: Insert a tab at the current cursor location.
enter: Insert a new line below the current one.
delete: Delete the character under the cursor.
fulljustify: Justify the entire current file.
wordcount: Count the number of words in the current buffer.
refresh: Refresh the screen.
undo: ndo the text action peformed (add text, delete text, etc).
redo: redo the last undone action (i.e. undo an undo)
suspend: Suspend the editor (if the suspend function is enabled, see
the 'suspendenable' entry below).
casesens: Toggle case sensitivity in searching (search/replace menus only).
regexp: Toggle whether searching/replacing is based on literal strings or regular expressions.
prevhistory: Show the previous history entry in the prompt menus (e.g. search).
nexthistory: Show the next history entry in the prompt menus (e.g. search).
dontreplace: Switch back to searching instead of replacing.
gototext: Search for files matching a string in the file browser (reading or writing files).
dosformat: When writing a file, switch to writing a DOS format (CR/LF).
macformat: When writing a file, switch to writing a Mac format.
append: When writing a file, append to the end instead of overwriting.
prepend: When writing a file, .prepend. (write at the beginning) instead of overwriting.
backup: When writing a file, create a backup of the current file.
firstfile: Move to the first file when using the file browser (reading or writing files).
lastfile: Move to the last file when using the file browser (reading or writing files).
nohelp: Toggle showing/hiding the two-line list of key bindings at the bottom of the screen.
constupdate: Constantly display the current line, column, word positions.
morespace: Toggle showing/hiding the blank line which .separates. the .title. from the file text.
smoothscroll: toggle smooth scrolling when moving via the arrow keys.
whitespacedisplay: Toggle whether whitespace is shown.
smarthome: Toggle whether the smart home key function is enabled.
autoindent: Toggle whether new lines will contain the same amount of whitespace as the line above.
cuttoend: Toggle whether cutting text will cut the whole line or just from the current cursor position to the end of the line.
nowrap: Toggle whether long lines will be wrapped to the next line.
suspendenable: Toggle whether the suspend sequence (normally ^Z) will suspend the editor window.


------
Valid menu sections are:


main: The main editor window where text is entered.
search: The search menu (AKA whereis).
replace: The .search to replace. menu.
replacewith: The .replace with. menu, which comes up after .search to replace..
gotoline: The .goto line (and column). menu.
writeout: The .write file. menu.
insert: The .insert file. menu.
extcmd: The menu for inserting output from an external comman, reached from the insert menu.
help: The help menu.
spell: The interactive spell checker Yes/no menu.
browser: The file browser for inserting or writing a file.
whereisfile: The .search for a file. menu in the file browser.
gotodir: The .go to directory. menu.
all: A special name meaning: apply to all menus where this function exists."
  )

(define (unbind key menu)
  "Unbind the key key from the menu named menu or from all menus by using all. Same key syntax as for binding."
  )

