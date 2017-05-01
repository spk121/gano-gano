# CBuffer - a scheme text buffer

One of the more difficult parts of doing text editing is the creation of a
text editing model.  On the face, it seems simple enough: a text buffer that
you can modify, but, once you start considering how to implement undo and
redo functionality, it can get complicated fairly quickly.

This library tries to implement a text editor model, with all the minimum
features.
- A virtual cursor location and a mark location
- A complete set of editing operations
- Undo and redo
- Bookmarks
- Graphical character renditions

To figure out how to make a basic set of editing operations and renditions,
we'll first investigate the functionality necessary to implement a backend
to various editors and terminal widgets.

# A Brief History of Terminals and Editors

Here we look at the functionality provided by some standard editors and
terminal widgets.  The editors will inform the minimum set of editing
operations that need to be created.  The terminal widgets will inform
which types of rendering can be used in practice.

## POSIX ```ed```

If we're going to begin at the beginning, the ancient line-oriented text
editors are a good place to start.  Let's look at the capabilities of
```ed```.

### Rendition

```ed``` had no concept of rendition.  It operated
on pure text.  While newer versions of ```ed`` may understand 
different character encodings, in its heyday, it used 7-bit character
storage.  Modern versions appear to use any encoding.

Also, line-oriented editors had no screen model, and lines could be very long.

### Operations

Remember that all of the operations for ```ed``` operate on complete lines
only.  There is no character motion, insertion, or deletion.

To implement```ed```, the buffer model needs to support the following
- Append: insert lines after addressed line
- Change: delete a range of addressed lines and then insert lines in that location
- Delete: delete a range of addressed lines
- Edit: delete all contents and replace it with the contents of a file
- Global: which is a forward line-oriented regular expression search
- Insert: insert lines before addressed line
- Join: combine a range of addressed lines into a single line
- Mark: add a bookmark at the beginning of the addressed line
- Move: move a range of addressed lines after an addressed line
- Read: insert file after addressed line
- Substitute: which is a regular expression search and replace on the
  contents of a range of addressed lines

To express this in terms of CBuffer primitive operations, one would need
- copy-lines-after
- delete-lines
- insert-lines-after
- insert-lines-before
- join-lines
- move-lines
- replace-forward-regex-in-region
- search-forward-regex-line

## VT52

The VT52 was one of the first useful terminals.  Looking at VT52 will give
us a starting place on how text can be displayed.

### Screen Model

The VT52 had 24x80 character cells.  Its characters were 7x7 pixels.  Its character set was
ASCII plus a 7-bit graphics character set.  There were no double-width
character.

### Rendition

The VT52 used 7-bit character storage, which was ASCII.

Its only rendition was to use either the standard character set or an
alternate character set of symbols.

But to encode its 7-bit ASCII plus its graphical character set,
a minimum of UCS-2 is required.

So you could imagine it as 7-bit ASCII plus a 1-bit rendition which
is an alternate font flag, or it could be a subset of UCS-2 with no rendition.

All of its characters occupied a single cell.

### Operations

To support an editor that had a screen model that matches the capability
of a VT52, the buffer model needs to support the following.
- cursor-up
- cursor-down
- cursor-left
- cursor-right
- cursor-home - which is to move the cursor to the top-left corner of the current screen
- insert-horizontal-tab
- set-graphics-mode
- insert-line-before
- insert-line-after
- erase-char: replace a character with space
- delete-to-eol
- delete-to-end-of-screen
- delete-line
