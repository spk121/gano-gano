
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "curs_func.h"
#include "type.h"
#include "term.h"
#define _GNU_SOURCE
#define cstring_t cchar_t

/* Assign the colors to color pair zero */
SCM
gucu_assume_default_colors (SCM fg, SCM bg)
{
  int c_fg, c_bg, ret;

  SCM_ASSERT (scm_is_integer(fg), fg, SCM_ARG1, "assume-default-colors");
  SCM_ASSERT (scm_is_integer(bg), bg, SCM_ARG2, "assume-default-colors");

  c_fg = scm_to_int (fg);
  c_bg = scm_to_int (bg);

  ret = assume_default_colors (c_fg, c_bg);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Return the output speed of the terminal as an integer */
SCM
gucu_baudrate ()
{
  return scm_from_int (baudrate ());
}

/* Beep! */
SCM
gucu_beep ()
{
  int ret;
  ret = beep ();
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Check if the colors can be changed. */
SCM
gucu_can_change_color_p ()
{
  bool ret;
  SCM s_ret;
  
  ret = can_change_color ();
  s_ret = scm_from_bool (ret);

  return s_ret;
}

/* Disable line buffering and erase/kill character processing */
SCM
gucu_cbreak ()
{
  if (cbreak () == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

/* Enable or disable if the next call to wrefresh will completely
   clear and redraw the screen from scratch */
SCM
gucu_clearok (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_f;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "clearok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "clearok");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = clearok (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Returns the attribute that corresponds to a given color pair */
SCM
gucu_COLOR_PAIR (SCM pair1)
{
  int c_pair1, ret;

  SCM_ASSERT (scm_is_integer (pair1), pair1, SCM_ARG1, "color-pair");

  c_pair1 = scm_to_int (pair1);

  ret = COLOR_PAIR (c_pair1);

  return scm_from_int (ret);
}

/* Copy part of srcwin onto part of destwin */
SCM
gucu_copywin (SCM srcwin, SCM dstwin, SCM sminrow, SCM smincol, SCM dminrow, 
	      SCM dmincol, SCM dmaxrow, SCM dmaxcol, SCM overlay)
{
  WINDOW *c_srcwin, *c_dstwin;
  int c_sminrow, c_smincol, c_dminrow, c_dmincol, c_dmaxrow, c_dmaxcol;
  int c_overlay, ret;

  SCM_ASSERT (_scm_is_window (srcwin), srcwin, SCM_ARG1, "copywin");
  SCM_ASSERT (_scm_is_window (dstwin), dstwin, SCM_ARG2, "copywin");
  SCM_ASSERT (scm_is_integer (sminrow), sminrow, SCM_ARG3, "copywin");
  SCM_ASSERT (scm_is_integer (smincol), smincol, SCM_ARG4, "copywin");
  SCM_ASSERT (scm_is_integer (dminrow), dminrow, SCM_ARG5, "copywin");
  SCM_ASSERT (scm_is_integer (dmincol), dmincol, SCM_ARG6, "copywin");
  SCM_ASSERT (scm_is_integer (dmaxrow), dmaxrow, SCM_ARG7, "copywin");
  SCM_ASSERT (scm_is_integer (dmaxcol), dmaxcol, 8, "copywin");
  SCM_ASSERT (scm_is_integer (overlay), overlay, 9, "copywin");

  c_srcwin = _scm_to_window (srcwin);
  c_dstwin = _scm_to_window (dstwin);
  c_sminrow = scm_to_int (sminrow);
  c_smincol = scm_to_int (smincol);
  c_dminrow = scm_to_int (dminrow);
  c_dmincol = scm_to_int (dmincol);
  c_dmaxrow = scm_to_int (dmaxrow);
  c_dmaxcol = scm_to_int (dmaxcol);
  c_overlay = scm_to_int (overlay);
  
  ret = copywin (c_srcwin, c_dstwin, c_sminrow, c_smincol, c_dminrow, 
		 c_dmincol, c_dmaxrow, c_dmaxcol, c_overlay);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Curses is visible or invisible */
SCM
gucu_curs_set (SCM visibility)
{
  int c_visibility, ret;

  SCM_ASSERT (scm_is_integer (visibility), visibility, SCM_ARG1, "curs-set");

  c_visibility = scm_to_int (visibility);

  ret = curs_set (c_visibility);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Return a string giving the version number of the underlying ncurses
   library */
SCM
gucu_curses_version ()
{
  return scm_from_locale_string (curses_version ());
}

/* Save the current terminal mode, so that it can be returned later by
   reset_prog_mode */
SCM
gucu_def_prog_mode ()
{
  if (def_prog_mode () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Save the current terminal mode, so that it can be returned later by
   reset_shell_mode */
SCM
gucu_def_shell_mode ()
{
  if (def_shell_mode () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Inserts a pause in between outputs, possibly with padding
   characters */
SCM
gucu_delay_output (SCM ms)
{
  int c_ms, ret;
  
  SCM_ASSERT (scm_is_integer (ms), ms, SCM_ARG1, "delay-output");

  c_ms = scm_to_int (ms);

  ret = delay_output (c_ms);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_deleteln ()
{
	int ret = deleteln ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_delscreen (SCM arg1)
{
	SCM_ASSERT (_scm_is_screen (arg1), arg1, SCM_ARG1, "delscreen");

	SCREEN *c_arg1 = _scm_to_screen (arg1);

	 delscreen (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

SCM
gucu_derwin (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "derwin");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "derwin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "derwin");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "derwin");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "derwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);

	WINDOW * ret = derwin (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_doupdate ()
{
	int ret = doupdate ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_dupwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "dupwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	WINDOW * ret = dupwin (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

/* Enable the echoing of user-typed characters */
SCM
gucu_echo ()
{
  if (echo () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_endwin ()
{
	int ret = endwin ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Return the current character used to erase */
SCM
gucu_erasechar ()
{
  return scm_from_char (erasechar ());
}

SCM
gucu_filter ()
{
	 filter ();
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

/* Flash the screen */
SCM
gucu_flash ()
{
  int ret;
  
  ret = flash ();
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_flushinp ()
{
	int ret = flushinp ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Return the background rendered character of the given window */
SCM
gucu_getbkgd (SCM win)
{
  WINDOW *c_win;
  chtype ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%getbkgd");

  c_win = _scm_to_window (win);

  ret = getbkgd (c_win);

  return _scm_from_chtype (ret);
}

SCM
gucu_getch ()
{
	int ret = getch ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_getwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_file (arg1), arg1, SCM_ARG1, "getwin");

	FILE *c_arg1 = _scm_to_file (arg1);

	WINDOW * ret = getwin (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

/* Set halfdelay. */
SCM
gucu_halfdelay (SCM tenths)
{
  int c_tenths;

  SCM_ASSERT (scm_is_integer (tenths), tenths, SCM_ARG1, "halfdelay");

  c_tenths = scm_to_int (tenths);
  
  if (halfdelay (c_tenths) == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Check if this screen has colors */
SCM
gucu_has_colors_p ()
{
  bool ret;
  SCM s_ret;

  ret = has_colors ();
  s_ret = scm_from_bool (ret);

  return s_ret;
}

/* True if the terminal has insert and delete character capabilities */
SCM
gucu_has_ic ()
{
  return (scm_from_bool (has_ic()));
}

/* True if the terminal and insert- and delete-line capabilities */
SCM
gucu_has_il ()
{
  bool ret;
  
  ret = has_il ();
  return (scm_from_bool (ret));
}

/* When true, try to use a terminal's hardware to clear characters */
SCM
gucu_idcok (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "idcok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "idcok");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  idcok (c_win, c_bf);

  return SCM_UNSPECIFIED;
}

/* When true, try to use a terminal's hardware to clear lines */
SCM
gucu_idlok (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "idlok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "idlok");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = idlok (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* When true, any change to the window will cause an immediate refresh */
SCM
gucu_immedok (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "immedok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "immedok");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  immedok (c_win, c_bf);

  return SCM_UNSPECIFIED;
}

SCM
gucu_inch ()
{
	chtype ret = inch ();
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_initscr ()
{
	WINDOW * ret = initscr ();
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

/* Initialize COLOR as an RGB triple. */
SCM
gucu_init_color (SCM color, SCM r, SCM g, SCM b)
{
  short c_color, c_r, c_g, c_b;
  int ret;
  
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG1, "init-color");
  SCM_ASSERT (scm_is_integer (r), r, SCM_ARG2, "init-color");
  SCM_ASSERT (scm_is_integer (g), g, SCM_ARG3, "init-color");
  SCM_ASSERT (scm_is_integer (b), b, SCM_ARG4, "init-color");
  
  c_color = scm_to_short (color);
  c_r = scm_to_short (r);
  c_g = scm_to_short (g);
  c_b = scm_to_short (b);

  ret = init_color (c_color, c_r, c_g, c_b);
  if (ret == ERR)
    scm_misc_error 
      ("init-color", 
       "Cannot set color: out of range or this screen lacks capability",
       SCM_BOOL_F);
  
  return SCM_UNSPECIFIED;
}

/* Initalize a color pair */
SCM
gucu_init_pair (SCM pair, SCM fore, SCM back)
{
  int ret;
  short c_pair, c_fore, c_back;

  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG1, "init-pair");
  SCM_ASSERT (scm_is_integer (fore), fore, SCM_ARG2, "init-pair");
  SCM_ASSERT (scm_is_integer (back), back, SCM_ARG3, "init-pair");
  
  c_pair = scm_to_short (pair);
  c_fore = scm_to_short (fore);
  c_back = scm_to_short (back);
  
  ret = init_pair (c_pair, c_fore, c_back);
  if (ret == ERR)
    scm_misc_error ("init-pair", 
		    "Out of range error or not initialized", 
		    SCM_BOOL_F);
  return SCM_UNSPECIFIED;
}

SCM
gucu_insch (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "insch");

	chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = insch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_insdelln (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "insdelln");

	int c_arg1 = scm_to_int (arg1);

	int ret = insdelln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_insertln ()
{
	int ret = insertln ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_insnstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "insnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "insnstr");

	 char *c_arg1 = scm_to_locale_string (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = insnstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_insstr (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "insstr");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = insstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_intrflush (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%intrflush");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "%intrflush");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = intrflush (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_isendwin ()
{
	bool ret = isendwin ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

SCM
gucu_is_linetouched (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "is-linetouched");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "is-linetouched");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	bool ret = is_linetouched (c_arg1, c_arg2);
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

SCM
gucu_is_wintouched (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "is-wintouched");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	bool ret = is_wintouched (c_arg1);
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

SCM
gucu_KEY_F (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "key-f");

	int c_arg1 = scm_to_int (arg1);

	int ret = KEY_F (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_keyname (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "keyname");

	int c_arg1 = scm_to_int (arg1);

	char * ret = keyname (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

/* Enable function key processing */
SCM
gucu_keypad (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%keypad");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "%keypad");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = keypad (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

/* Return the current line kill character */
SCM
gucu_killchar ()
{
  return scm_from_char (killchar ());
}

/* If false, curses will try to put the hardware cursor where the
   curses cursor is located.  If true, it will be sloppy, perhaps
   saving time */
SCM
gucu_leaveok (SCM win, SCM bf)
{
  WINDOW *c_win;
  book c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "leaveok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "leaveok");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = leaveok (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Return a verbose description of the current terminal */
SCM
gucu_longname ()
{
  char *ret;
  SCM s_ret;
	
  ret = longname ();
  s_ret = scm_from_locale_string (ret);

  /* No need to free static string returned by longname */

  return s_ret;
}

/* Set the terminal to 7 or 8 bit mode */
SCM
gucu_meta (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%meta");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "%meta");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = meta (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_mouseinterval (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mouseinterval");

	int c_arg1 = scm_to_int (arg1);

	int ret = mouseinterval (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_move (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "move");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "move");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = move (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvcur (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvcur");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvcur");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvcur");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvcur");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvcur (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvderwin (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvderwin");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvderwin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvderwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = mvderwin (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvgetch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvgetch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvgetch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = mvgetch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvinch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvinch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvinch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	chtype ret = mvinch (c_arg1, c_arg2);
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_mvinsch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvinsch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvinsch");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "mvinsch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);

	int ret = mvinsch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvinsnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvinsnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvinsnstr");
	SCM_ASSERT (scm_is_string (arg3), arg3, SCM_ARG3, "mvinsnstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvinsnstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 char *c_arg3 = scm_to_locale_string (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvinsnstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvinsstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvinsstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvinsstr");
	SCM_ASSERT (scm_is_string (arg3), arg3, SCM_ARG3, "mvinsstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 char *c_arg3 = scm_to_locale_string (arg3);

	int ret = mvinsstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvwgetch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwgetch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwgetch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwgetch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = mvwgetch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvwin (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwin");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = mvwin (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvwinch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwinch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwinch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwinch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	chtype ret = mvwinch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_mvwinsch (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwinsch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwinsch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwinsch");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "mvwinsch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	chtype c_arg4 = _scm_to_chtype (arg4);

	int ret = mvwinsch (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_mvwinsnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwinsnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwinsnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwinsnstr");
	SCM_ASSERT (scm_is_string (arg4), arg4, SCM_ARG4, "mvwinsnstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwinsnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 char *c_arg4 = scm_to_locale_string (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwinsnstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwinsstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwinsstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwinsstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwinsstr");
	SCM_ASSERT (scm_is_string (arg4), arg4, SCM_ARG4, "mvwinsstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 char *c_arg4 = scm_to_locale_string (arg4);

	int ret = mvwinsstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}


SCM
gucu_napms (SCM ms)
{
  int c_ms, ret;

  SCM_ASSERT (scm_is_integer (ms), ms, SCM_ARG1, "napms");

  c_ms = scm_to_int (ms);

  ret = napms (c_ms);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_newpad (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "newpad");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "newpad");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	WINDOW * ret = newpad (c_arg1, c_arg2);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_newwin (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "newwin");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "newwin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "newwin");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "newwin");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);

	WINDOW * ret = newwin (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

/* Translate return to newline on input */
SCM
gucu_nl ()
{
  if (nl () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Enable line buffering and erase/kill character processing */
SCM
gucu_nocbreak ()
{
  if (nocbreak () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Causes getch() to be non-blocking, so that it returns ERR if no
   character is ready */
SCM
gucu_nodelay (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%nodelay");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "%nodelay");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = nodelay (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Disable echoing of user-type characters */
SCM
gucu_noecho ()
{
  if (noecho () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Do not translate the return key to newline on input */
SCM
gucu_nonl ()
{
  if (nonl () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Do no flush i/o queues on interrupts */
SCM
gucu_noqiflush ()
{
  noqiflush ();
  return SCM_UNSPECIFIED;
}

/* Allow control characters to generate signals. */
SCM
gucu_noraw ()
{
  if (noraw () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Do not set an timer for escape sequence processing */
SCM
gucu_notimeout (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), arg1, SCM_ARG1, "%notimeout");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "%notimeout");

  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = notimeout (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Overlay srcwin on top of destwin, ignoring blanks */
SCM
gucu_overlay (SCM srcwin, SCM destwin)
{
  WINDOW *c_srcwin, *c_destwin;
  int ret;

  SCM_ASSERT (_scm_is_window (srcwin), srcwin, SCM_ARG1, "overlay");
  SCM_ASSERT (_scm_is_window (destwin), destwin, SCM_ARG2, "overlay");

  c_srcwin = _scm_to_window (srcwin);
  c_destwin = _scm_to_window (destwin);

  ret = overlay (c_srcwin, c_destwin);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

/* Overlay srcwin on top of destwin, including blanks */
SCM
gucu_overwrite (SCM srcwin, SCM destwin)
{
  WINDOW *c_srcwin, *c_destwin;
  int ret;

  SCM_ASSERT (_scm_is_window (srcwin), srcwin, SCM_ARG1, "overwrite");
  SCM_ASSERT (_scm_is_window (destwin), destwin, SCM_ARG2, "overwrite");

  c_srcwin = _scm_to_window (srcwin);
  c_destwin = _scm_to_window (destwin);

  ret = overwrite (c_srcwin, c_destwin);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_PAIR_NUMBER (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "pair-number");

	int c_arg1 = scm_to_int (arg1);

	int ret = PAIR_NUMBER (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_pechochar (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "pechochar");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "pechochar");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = pechochar (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_pnoutrefresh (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg6), arg6, SCM_ARG6, "pnoutrefresh");
	SCM_ASSERT (scm_is_integer (arg7), arg7, SCM_ARG7, "pnoutrefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);
	int c_arg6 = scm_to_int (arg6);
	int c_arg7 = scm_to_int (arg7);

	int ret = pnoutrefresh (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_prefresh (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "prefresh");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "prefresh");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "prefresh");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "prefresh");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "prefresh");
	SCM_ASSERT (scm_is_integer (arg6), arg6, SCM_ARG6, "prefresh");
	SCM_ASSERT (scm_is_integer (arg7), arg7, SCM_ARG7, "prefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);
	int c_arg6 = scm_to_int (arg6);
	int c_arg7 = scm_to_int (arg7);

	int ret = prefresh (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_putp (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "putp");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = putp (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_putwin (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "putwin");
	SCM_ASSERT (_scm_is_file (arg2), arg2, SCM_ARG2, "putwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	FILE *c_arg2 = _scm_to_file (arg2);

	int ret = putwin (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Flush queues on interupts */
SCM
gucu_qiflush ()
{
  qiflush ();
  return SCM_UNSPECIFIED:
}

/* Pass control characters instead of generating a signal */
SCM
gucu_raw ()
{
  if (raw () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_redrawwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "redrawwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = redrawwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_refresh ()
{
	int ret = refresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}


SCM
gucu_reset_prog_mode ()
{
  if (reset_prog_mode () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_reset_shell_mode ()
{
  if (reset_shell_mode () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Restore the state of the terminal modes */
SCM
gucu_resetty ()
{
  if (resetty () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Save the state of the terminal modes */
SCM
gucu_savetty ()
{
  if (savetty () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_scr_dump (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "scr-dump");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = scr_dump (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_scr_init (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "scr-init");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = scr_init (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_scrl (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "scrl");

	int c_arg1 = scm_to_int (arg1);

	int ret = scrl (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_scroll (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "scroll");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = scroll (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* If true, the window will scroll when the cursor touches the end of
   the screen */
SCM
gucu_scrollok (SCM win, SCM bf)
{
  WINDOW *c_win;
  bool c_bf;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "scrollok");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "scrollok");
  
  c_win = _scm_to_window (win);
  c_bf = scm_to_bool (bf);

  ret = scrollok (c_win, c_bf);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_scr_restore (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "scr-restore");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = scr_restore (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_scr_set (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "scr-set");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = scr_set (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_setsyx (SCM y, SCM x)
{
  int c_y, c_x;
  
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "setsyx");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "setsyx");

  c_y = scm_to_int (y);
  c_x = scm_to_int (x);

  setsyx (c_y, c_x);
  
  return SCM_UNSPECIFIED;
}

SCM
gucu_set_term (SCM arg1)
{
	SCM_ASSERT (_scm_is_screen (arg1), arg1, SCM_ARG1, "set-term");

	SCREEN *c_arg1 = _scm_to_screen (arg1);

	SCREEN * ret = set_term (c_arg1);
	SCM s_ret = _scm_from_screen (ret);

	return s_ret;
}

SCM
gucu_slk_attr_off (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_attr (arg1), arg1, SCM_ARG1, "slk-attr-off");
	SCM_ASSERT (_scm_is_voidstring (arg2), arg2, SCM_ARG2, "slk-attr-off");

	const attr_t c_arg1 = _scm_to_attr (arg1);
	void *c_arg2 = _scm_to_voidstring (arg2);

	int ret = slk_attr_off (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_attroff (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attroff");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attroff (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_attr_on (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_attr (arg1), arg1, SCM_ARG1, "slk-attr-on");
	SCM_ASSERT (_scm_is_voidstring (arg2), arg2, SCM_ARG2, "slk-attr-on");

	const attr_t c_arg1 = _scm_to_attr (arg1);
	void *c_arg2 = _scm_to_voidstring (arg2);

	int ret = slk_attr_on (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_attron (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attron");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attron (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_attr_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_attr (arg1), arg1, SCM_ARG1, "slk-attr-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "slk-attr-set");
	SCM_ASSERT (_scm_is_voidstring (arg3), arg3, SCM_ARG3, "slk-attr-set");

	const attr_t c_arg1 = _scm_to_attr (arg1);
	short c_arg2 = scm_to_short (arg2);
	void *c_arg3 = _scm_to_voidstring (arg3);

	int ret = slk_attr_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_attrset (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attrset");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attrset (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_clear ()
{
	int ret = slk_clear ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_color (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-color");

	short c_arg1 = scm_to_short (arg1);

	int ret = slk_color (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_init (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-init");

	int c_arg1 = scm_to_int (arg1);

	int ret = slk_init (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_label (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-label");

	int c_arg1 = scm_to_int (arg1);

	char * ret = slk_label (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

SCM
gucu_slk_noutrefresh ()
{
	int ret = slk_noutrefresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_refresh ()
{
	int ret = slk_refresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_restore ()
{
	int ret = slk_restore ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_slk_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-set");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "slk-set");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "slk-set");

	int c_arg1 = scm_to_int (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = slk_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_slk_touch ()
{
	int ret = slk_touch ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Initialize the color subsystem. */
SCM
gucu_start_color ()
{
  int ret = start_color ();

  if (ret == ERR)
    scm_misc_error ("start-color", "The current screen is not initialized", 
		    SCM_BOOL_F);
  
  return SCM_UNSPECIFIED;
}

SCM
gucu_subpad (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "subpad");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "subpad");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "subpad");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "subpad");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "subpad");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);

	WINDOW * ret = subpad (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_subwin (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "subwin");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "subwin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "subwin");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "subwin");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "subwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);

	WINDOW * ret = subwin (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_syncok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "syncok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "syncok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = syncok (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Return all the video attributes supported by the terminal */
SCM
gucu_termattrs ()
{
  chtype ret;
  SCM s_ret;

  ret = termattrs ();
  s_ret = _scm_from_chtype (ret);

  return s_ret;
}

/* Return the short name of the terminal */
SCM
gucu_termname ()
{
  char *ret;
  SCM s_ret;

  ret = termname ();
  s_ret = scm_from_locale_string (ret);

  /* No need to free static string returned by termname() */

  return s_ret;
}

SCM
gucu_tgetent (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_voidstring (arg1), arg1, SCM_ARG1, "tgetent");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "tgetent");

	void *c_arg1 = _scm_to_voidstring (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);

	int ret = tgetent (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_tigetflag (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetflag");

	char *c_arg1 = scm_to_locale_string (arg1);

	int ret = tigetflag (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_tigetnum (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetnum");

	char *c_arg1 = scm_to_locale_string (arg1);

	int ret = tigetnum (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_tigetstr (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetstr");

	char *c_arg1 = scm_to_locale_string (arg1);

	char * ret = tigetstr (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

SCM
gucu_touchline (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "touchline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "touchline");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "touchline");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = touchline (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_touchwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "touchwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = touchwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Given a file descriptor, se special optimizations looking for line breaks */
SCM
gucu_typeahead (SCM fd)
{
  int c_fd, ret;

  SCM_ASSERT (scm_is_integer (fd), fd, SCM_ARG1, "%typeahead");

  c_fd = scm_to_int (fd);

  ret = typeahead (c_fd);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_ungetch (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "ungetch");

	int c_arg1 = scm_to_int (arg1);

	int ret = ungetch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_untouchwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "untouchwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = untouchwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Assign the terminal default colors to the special color number -1 */
SCM
gucu_use_default_colors ()
{
  if (use_default_colors () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_use_env (SCM arg1)
{
	SCM_ASSERT (scm_is_bool (arg1), arg1, SCM_ARG1, "use-env");

	bool c_arg1 = scm_to_bool (arg1);

	 use_env (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

/* When false, disable extended names in the terminfo description */
SCM
gucu_use_extended_names (SCM bf)
{
  bool c_bf;

  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG1, "use-extended-names");
  
  c_bf = scm_to_bool (bf);

  if (use_extended_names () == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_vidattr (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "vidattr");

	chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = vidattr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}


/* Put the character ch into the window at its current position, which
   is then advanced. */
SCM
gucu_waddch (SCM win, SCM ch)
{
  WINDOW *c_win;
  chtype c_ch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%waddch");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%waddch");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);

  ret = waddch (c_win, c_ch);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Copy a rendered string in to a window at the current cursor
   positions.  If n is -1, copy until the end of the buffer.
   Otherwise copy N characters. */
SCM
gucu_waddchnstr (SCM win, SCM chstr, SCM n)
{
  WINDOW *c_win;
  chtype *c_chstr;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%waddchnstr");
  SCM_ASSERT (_scm_is_chstring (chstr), chstr, SCM_ARG2, "%waddchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%waddchnstr");

  c_win = _scm_to_window (win);
  c_chstr = _scm_to_chstring (chstr);
  c_n = scm_to_int (n);

  ret = waddchnstr (c_win, c_chstr, c_n);
  
  free (c_chstr);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Write the characters of STR to the window. */
SCM
gucu_waddnstr (SCM win, SCM str, SCM n)
{
  WINDOW *c_win;
  char *c_str;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%waddnstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG2, "%waddnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%waddnstr");

  c_win = _scm_to_window (win);
  c_str = scm_to_locale_string (str);
  c_n = scm_to_int (n);

  ret = waddnstr (c_win, c_str, c_n);
  
  free (c_str);
  
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;

}

/* Turn attributes off on a given window */
SCM
gucu_wattr_off (SCM win, SCM attrs)
{
  WINDOW *c_win;
  attr_t c_attrs;
  int ret;
  
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "wattr-off");
  SCM_ASSERT (_scm_is_attr (attrs), attrs, SCM_ARG2, "wattr-off");

  c_win = _scm_to_window (win);
  c_attrs = _scm_to_attr (attrs);

  ret = wattr_off (c_win, c_attrs, (void *)0);
  if (ret == ERR)
    {
      scm_misc_error ("%wattr-off", "Bad window: ~S", win);
    }

  return SCM_UNSPECIFIED;
}

/* Turn on window attributes */
SCM
gucu_wattr_on (SCM win, SCM attrs)
{
  WINDOW *c_win;
  attr_t c_attrs;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wattr-on");
  SCM_ASSERT (_scm_is_attr (attrs), attrs, SCM_ARG2, "%wattr-on");

  c_win = _scm_to_window (win);
  c_attrs = _scm_to_attr (attrs);

  ret = wattr_on (c_win, c_attrs, (void *)0);
  if (ret == ERR)
    {
      scm_misc_error ("%wattr-on", "Bad window: ~S", win);
    }

  return SCM_UNSPECIFIED;
}

/* Set the background property and apply it to every possible location */
SCM
gucu_wbkgd (SCM win, SCM ch)
{
  WINDOW *c_win;
  chtype c_ch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wbkgd");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%wbkgd");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);

  /* Always returns OK */
  ret = wbkgd (c_win, c_ch);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Change the new background character to the given rendered char */
SCM
gucu_wbkgdset (SCM win, SCM ch)
{
  WINDOW *c_win;
  chtype c_ch;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wbkgdset");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%wbkgdset");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);

  wbkgdset (c_win, c_ch);

  return SCM_UNSPECIFIED;
}

SCM
gucu_wborder (SCM win, SCM left, SCM right, SCM top, SCM bottom, SCM topleft, 
	      SCM topright, SCM bottomleft, SCM bottomright)
{
  WINDOW *c_win;
  chtype c_left, c_right, c_top, c_bottom;
  chtype c_topleft, c_topright, c_bottomleft, c_bottomright;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wborder");
  SCM_ASSERT (_scm_is_chtype (left), left, SCM_ARG2, "%wborder");
  SCM_ASSERT (_scm_is_chtype (right), right, SCM_ARG3, "%wborder");
  SCM_ASSERT (_scm_is_chtype (top), top, SCM_ARG4, "%wborder");
  SCM_ASSERT (_scm_is_chtype (bottom), bottom, SCM_ARG5, "%wborder");
  SCM_ASSERT (_scm_is_chtype (topleft), topleft, SCM_ARG6, "%wborder");
  SCM_ASSERT (_scm_is_chtype (topright), topright, SCM_ARG7, "%wborder");
  SCM_ASSERT (_scm_is_chtype (bottomleft), bottomleft, 8, "%wborder");
  SCM_ASSERT (_scm_is_chtype (bottomright), bottomright, 9, "%wborder");

  c_win = _scm_to_window (win);
  c_left = _scm_to_chtype (left);
  c_right = _scm_to_chtype (right);
  c_top = _scm_to_chtype (top);
  c_bottom = _scm_to_chtype (bottom);
  c_topleft = _scm_to_chtype (topleft);
  c_topright = _scm_to_chtype (topright);
  c_bottomleft = _scm_to_chtype (bottomleft);
  c_bottomright = _scm_to_chtype (bottomright);

  ret = wborder (c_win, c_left, c_right, c_top, c_bottom, 
		 c_topleft, c_topright, c_bottomleft, c_bottomright);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Change the attributes for N characters at the current position */
SCM
gucu_wchgat (SCM win, SCM n, SCM attr, SCM color)
{
  WINDOW *c_win;
  int c_n;
  attr_t c_attr;
  short c_color;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wchgat");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "%wchgat");
  SCM_ASSERT (_scm_is_attr (attr), attr, SCM_ARG3, "%wchgat");
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG4, "%wchgat");

  c_win = _scm_to_window (win);
  c_n = scm_to_int (n);
  c_attr = _scm_to_attr (attr);
  c_color = scm_to_short (color);

  ret = wchgat (c_win, c_n, c_attr, c_color, 0);
  if (ret != OK)
    scm_misc_error ("%wchgat", "Out of range error or not initialized",
		    SCM_BOOL_F);

  return SCM_UNSPECIFIED;
}

/* Copy blanks to entire window */
SCM
gucu_wclear (SCM win)
{
  WINDOW *c_win;
  int ret;
  
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wclear");

  c_win = _scm_to_window (win);

  ret = wclear (c_win);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_wclrtobot (SCM win)
{
  WINDOW *c_win;
  int ret;
  
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wclrtobot");

  c_win = _scm_to_window (win);

  ret = wclrtobot (c_win);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_wclrtoeol (SCM win)
{
  WINDOW *c_win;
  int ret;
  
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wclrtoeol");

  c_win = _scm_to_window (win);

  ret = wclrtoeol (c_win);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_wcursyncup (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wcursyncup");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wcursyncup (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

/* Set the color pair of a window */
SCM
gucu_wcolor_set (SCM win, SCM pair)
{
  WINDOW *c_win;
  short c_pair;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wcolor-set");
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG2, "%wcolor-set");

  c_win = _scm_to_window (win);
  c_pair = scm_to_short (pair);

  ret = wcolor_set (c_win, c_pair, 0);
  if (ret == ERR)
    scm_misc_error ("%wcolor-set", "Out of range error or not initialized",
		    SCM_BOOL_F);

  return SCM_UNSPECIFIED;
}

/* Delete the character under the cursor */
SCM
gucu_wdelch (SCM win)
{
  WINDOW *c_win;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wdelch");
  
  c_win = _scm_to_window (win);

  ret = wdelch (c_win);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_wdeleteln (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wdeleteln");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wdeleteln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Write ch to the given window without advancing the curses.  Refresh
   that character immediately */
SCM
gucu_wechochar (SCM win, SCM ch)
{
  WINDOW *c_win;
  chtype c_ch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wechochar");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%wechochar");
  
  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);

  ret = wechochar (c_win, c_ch);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

SCM
gucu_wenclose (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wenclose");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wenclose");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wenclose");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	bool ret = wenclose (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

/* Copy blanks into every position in the window */
SCM
gucu_werase (SCM win)
{
  WINDOW *c_win;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%werase");
  
  c_win = _scm_to_window (win);

  ret = werase (c_win);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

SCM
gucu_wgetch (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wgetch");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wgetch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Draw a horizontal line using the given character that is N
   characters long. */
SCM
gucu_whline (SCM win, SCM ch, SCM n)
{
  WINDOW *c_win;
  chtype c_ch;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%whline");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%whline");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%whline");
  
  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);
  c_n = scm_to_int (n);

  ret = whline (c_win, c_arg2, c_n);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

SCM
gucu_winch (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winch");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	chtype ret = winch (c_arg1);
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_winsch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsch");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "winsch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = winsch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_winsdelln (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsdelln");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "winsdelln");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = winsdelln (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_winsertln (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsertln");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = winsertln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_winsnstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsnstr");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "winsnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "winsnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = winsnstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_winsstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsstr");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "winsstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);

	int ret = winsstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wmove (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wmove");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wmove");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wmove");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wmove (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_wnoutrefresh (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wnoutrefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wnoutrefresh (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_wredrawln (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wredrawln");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wredrawln");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wredrawln");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wredrawln (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_wrefresh (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wrefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wrefresh (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_wscrl (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wscrl");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wscrl");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = wscrl (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* set the scroll region for the window to be between TOP and BOT */
SCM
gucu_wsetscrreg (SCM win, SCM top, SCM bot)
{
  WINDOW *c_win;
  int c_top, c_bot, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wsetscrreg");
  SCM_ASSERT (scm_is_integer (top), top, SCM_ARG2, "%wsetscrreg");
  SCM_ASSERT (scm_is_integer (bot), bot, SCM_ARG3, "%wsetscrreg");

  c_win = _scm_to_window (win);
  c_top = scm_to_int (top);
  c_bot = scm_to_int (bot);

  ret = wsetscrreg (c_win, c_top, c_bot);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Turns off all attributes */
SCM
gucu_wstandend (SCM win)
{
  WINDOW *c_win;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wstandend");
  
  c_win = _scm_to_window (win);

  /* wstandend() seems to be a macro that doesn't return anything
     meaningful. */

  wstandend (c_win);
  
  return SCM_UNSPECIFIED;
}

/* Turns on the A_STANDOUT attribute */
SCM
gucu_wstandout (SCM win)
{
  WINDOW *c_win;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wstandout");

  c_win = _scm_to_window (win);

  /* There doesn't seem to be any meaning in the return value of wstandout */
  wstandout (c_win);

  return SCM_UNSPECIFIED;
}

SCM
gucu_wsyncup (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wsyncup");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wsyncup (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

SCM
gucu_wsyncdown (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wsyncdown");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wsyncdown (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

/* Set the blocking read timer */
SCM
gucu_wtimeout (SCM win, SCM delay)
{
  WINDOW *c_win;
  int c_delay;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wtimeout");
  SCM_ASSERT (scm_is_integer (delay), delay, SCM_ARG2, "%wtimeout");

  c_win = _scm_to_window (win);
  c_delay = scm_to_int (delay);

  wtimeout (c_win, c_delay);
  
  return SCM_UNSPECIFIED;
}

SCM
gucu_wtouchln (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wtouchln");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wtouchln");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wtouchln");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "wtouchln");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = wtouchln (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

/* Draw a vertical line with the given character that is N characters
   long */
SCM
gucu_wvline (SCM win, SCM ch, SCM n)
{
  WINDOW *c_win;
  chtype c_ch;
  int c_n, ret;
    
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wvline");
  SCM_ASSERT (_scm_is_chtype (ch), ch, SCM_ARG2, "%wvline");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%wvline");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_chtype (ch);
  c_n = scm_to_int (n);

  ret = wvline (c_win, c_ch, c_n);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
  
}


void 
gucu_init_function ()
{
  scm_c_define_gsubr ("assume-default-colors", 2, 0, 0, 
		      gucu_assume_default_colors);
	scm_c_define_gsubr ("baudrate", 0, 0, 0, gucu_baudrate);
	scm_c_define_gsubr ("beep", 0, 0, 0, gucu_beep);
	scm_c_define_gsubr ("can-change-color?", 0, 0, 0, 
			    gucu_can_change_color_p);
	scm_c_define_gsubr ("cbreak", 0, 0, 0, gucu_cbreak);
	scm_c_define_gsubr ("clearok", 2, 0, 0, gucu_clearok);
	scm_c_define_gsubr ("color-pair", 1, 0, 0, gucu_COLOR_PAIR);
	scm_c_define_gsubr ("copywin", 9, 0, 0, gucu_copywin);
	scm_c_define_gsubr ("curs-set", 1, 0, 0, gucu_curs_set);
	scm_c_define_gsubr ("curses-version", 0, 0, 0, gucu_curses_version);
	scm_c_define_gsubr ("def-prog-mode", 0, 0, 0, gucu_def_prog_mode);
	scm_c_define_gsubr ("def-shell-mode", 0, 0, 0, gucu_def_shell_mode);
	scm_c_define_gsubr ("delay-output", 1, 0, 0, gucu_delay_output);
	scm_c_define_gsubr ("deleteln", 0, 0, 0, gucu_deleteln);
	scm_c_define_gsubr ("delscreen", 1, 0, 0, gucu_delscreen);
	scm_c_define_gsubr ("derwin", 5, 0, 0, gucu_derwin);
	scm_c_define_gsubr ("doupdate", 0, 0, 0, gucu_doupdate);
	scm_c_define_gsubr ("dupwin", 1, 0, 0, gucu_dupwin);
	scm_c_define_gsubr ("echo", 0, 0, 0, gucu_echo);
	scm_c_define_gsubr ("endwin", 0, 0, 0, gucu_endwin);
	scm_c_define_gsubr ("erasechar", 0, 0, 0, gucu_erasechar);
	scm_c_define_gsubr ("filter", 0, 0, 0, gucu_filter);
	scm_c_define_gsubr ("flash", 0, 0, 0, gucu_flash);
	scm_c_define_gsubr ("flushinp", 0, 0, 0, gucu_flushinp);
	scm_c_define_gsubr ("%getbkgd", 1, 0, 0, gucu_getbkgd);
	scm_c_define_gsubr ("getch", 0, 0, 0, gucu_getch);
	scm_c_define_gsubr ("getwin", 1, 0, 0, gucu_getwin);
	scm_c_define_gsubr ("halfdelay", 1, 0, 0, gucu_halfdelay);
	scm_c_define_gsubr ("has-colors?", 0, 0, 0, gucu_has_colors_p);
	scm_c_define_gsubr ("has-ic", 0, 0, 0, gucu_has_ic);
	scm_c_define_gsubr ("has-il", 0, 0, 0, gucu_has_il);
	scm_c_define_gsubr ("idcok", 2, 0, 0, gucu_idcok);
	scm_c_define_gsubr ("idlok", 2, 0, 0, gucu_idlok);
	scm_c_define_gsubr ("immedok", 2, 0, 0, gucu_immedok);
	scm_c_define_gsubr ("inch", 0, 0, 0, gucu_inch);
	scm_c_define_gsubr ("initscr", 0, 0, 0, gucu_initscr);
	scm_c_define_gsubr ("init-color", 4, 0, 0, gucu_init_color);
	scm_c_define_gsubr ("init-pair", 3, 0, 0, gucu_init_pair);
	scm_c_define_gsubr ("insch", 1, 0, 0, gucu_insch);
	scm_c_define_gsubr ("insdelln", 1, 0, 0, gucu_insdelln);
	scm_c_define_gsubr ("insertln", 0, 0, 0, gucu_insertln);
	scm_c_define_gsubr ("insnstr", 2, 0, 0, gucu_insnstr);
	scm_c_define_gsubr ("insstr", 1, 0, 0, gucu_insstr);
	scm_c_define_gsubr ("%intrflush", 2, 0, 0, gucu_intrflush);
	scm_c_define_gsubr ("isendwin", 0, 0, 0, gucu_isendwin);
	scm_c_define_gsubr ("is-linetouched", 2, 0, 0, gucu_is_linetouched);
	scm_c_define_gsubr ("is-wintouched", 1, 0, 0, gucu_is_wintouched);
	scm_c_define_gsubr ("key-f", 1, 0, 0, gucu_KEY_F);
	scm_c_define_gsubr ("keyname", 1, 0, 0, gucu_keyname);
	scm_c_define_gsubr ("%keypad", 2, 0, 0, gucu_keypad);
	scm_c_define_gsubr ("killchar", 0, 0, 0, gucu_killchar);
	scm_c_define_gsubr ("leaveok", 2, 0, 0, gucu_leaveok);
	scm_c_define_gsubr ("longname", 0, 0, 0, gucu_longname);
	scm_c_define_gsubr ("%meta", 2, 0, 0, gucu_meta);
	scm_c_define_gsubr ("mouseinterval", 1, 0, 0, gucu_mouseinterval);
	scm_c_define_gsubr ("move", 2, 0, 0, gucu_move);
	scm_c_define_gsubr ("mvcur", 4, 0, 0, gucu_mvcur);
	scm_c_define_gsubr ("mvderwin", 3, 0, 0, gucu_mvderwin);
	scm_c_define_gsubr ("mvgetch", 2, 0, 0, gucu_mvgetch);
	scm_c_define_gsubr ("mvinch", 2, 0, 0, gucu_mvinch);
	scm_c_define_gsubr ("mvinsch", 3, 0, 0, gucu_mvinsch);
	scm_c_define_gsubr ("mvinsnstr", 4, 0, 0, gucu_mvinsnstr);
	scm_c_define_gsubr ("mvinsstr", 3, 0, 0, gucu_mvinsstr);
	scm_c_define_gsubr ("mvwgetch", 3, 0, 0, gucu_mvwgetch);
	scm_c_define_gsubr ("mvwin", 3, 0, 0, gucu_mvwin);
	scm_c_define_gsubr ("mvwinch", 3, 0, 0, gucu_mvwinch);
	scm_c_define_gsubr ("mvwinsch", 4, 0, 0, gucu_mvwinsch);
	scm_c_define_gsubr ("mvwinsnstr", 5, 0, 0, gucu_mvwinsnstr);
	scm_c_define_gsubr ("mvwinsstr", 4, 0, 0, gucu_mvwinsstr);
	scm_c_define_gsubr ("napms", 1, 0, 0, gucu_napms);
	scm_c_define_gsubr ("newpad", 2, 0, 0, gucu_newpad);
	scm_c_define_gsubr ("newwin", 4, 0, 0, gucu_newwin);
	scm_c_define_gsubr ("nl", 0, 0, 0, gucu_nl);
	scm_c_define_gsubr ("nocbreak", 0, 0, 0, gucu_nocbreak);
	scm_c_define_gsubr ("%nodelay", 2, 0, 0, gucu_nodelay);
	scm_c_define_gsubr ("noecho", 0, 0, 0, gucu_noecho);
	scm_c_define_gsubr ("nonl", 0, 0, 0, gucu_nonl);
	scm_c_define_gsubr ("noqiflush", 0, 0, 0, gucu_noqiflush);
	scm_c_define_gsubr ("noraw", 0, 0, 0, gucu_noraw);
	scm_c_define_gsubr ("%notimeout", 2, 0, 0, gucu_notimeout);
	scm_c_define_gsubr ("overlay", 2, 0, 0, gucu_overlay);
	scm_c_define_gsubr ("overwrite", 2, 0, 0, gucu_overwrite);
	scm_c_define_gsubr ("pair-number", 1, 0, 0, gucu_PAIR_NUMBER);
	scm_c_define_gsubr ("pechochar", 2, 0, 0, gucu_pechochar);
	scm_c_define_gsubr ("pnoutrefresh", 7, 0, 0, gucu_pnoutrefresh);
	scm_c_define_gsubr ("prefresh", 7, 0, 0, gucu_prefresh);
	scm_c_define_gsubr ("putp", 1, 0, 0, gucu_putp);
	scm_c_define_gsubr ("putwin", 2, 0, 0, gucu_putwin);
	scm_c_define_gsubr ("qiflush", 0, 0, 0, gucu_qiflush);
	scm_c_define_gsubr ("raw", 0, 0, 0, gucu_raw);
	scm_c_define_gsubr ("redrawwin", 1, 0, 0, gucu_redrawwin);
	scm_c_define_gsubr ("refresh", 0, 0, 0, gucu_refresh);
	scm_c_define_gsubr ("reset-prog-mode", 0, 0, 0, gucu_reset_prog_mode);
	scm_c_define_gsubr ("reset-shell-mode", 0, 0, 0, gucu_reset_shell_mode);
	scm_c_define_gsubr ("resetty", 0, 0, 0, gucu_resetty);
	scm_c_define_gsubr ("savetty", 0, 0, 0, gucu_savetty);
	scm_c_define_gsubr ("scr-dump", 1, 0, 0, gucu_scr_dump);
	scm_c_define_gsubr ("scr-init", 1, 0, 0, gucu_scr_init);
	scm_c_define_gsubr ("scrl", 1, 0, 0, gucu_scrl);
	scm_c_define_gsubr ("scroll", 1, 0, 0, gucu_scroll);
	scm_c_define_gsubr ("scrollok", 2, 0, 0, gucu_scrollok);
	scm_c_define_gsubr ("scr-restore", 1, 0, 0, gucu_scr_restore);
	scm_c_define_gsubr ("scr-set", 1, 0, 0, gucu_scr_set);
	scm_c_define_gsubr ("set-term", 1, 0, 0, gucu_set_term);
	scm_c_define_gsubr ("setsyx", 2, 0, 0, gucu_setsyx);
	scm_c_define_gsubr ("slk-attr-off", 2, 0, 0, gucu_slk_attr_off);
	scm_c_define_gsubr ("slk-attroff", 1, 0, 0, gucu_slk_attroff);
	scm_c_define_gsubr ("slk-attr-on", 2, 0, 0, gucu_slk_attr_on);
	scm_c_define_gsubr ("slk-attron", 1, 0, 0, gucu_slk_attron);
	scm_c_define_gsubr ("slk-attr-set", 3, 0, 0, gucu_slk_attr_set);
	scm_c_define_gsubr ("slk-attrset", 1, 0, 0, gucu_slk_attrset);
	scm_c_define_gsubr ("slk-clear", 0, 0, 0, gucu_slk_clear);
	scm_c_define_gsubr ("slk-color", 1, 0, 0, gucu_slk_color);
	scm_c_define_gsubr ("slk-init", 1, 0, 0, gucu_slk_init);
	scm_c_define_gsubr ("slk-label", 1, 0, 0, gucu_slk_label);
	scm_c_define_gsubr ("slk-noutrefresh", 0, 0, 0, gucu_slk_noutrefresh);
	scm_c_define_gsubr ("slk-refresh", 0, 0, 0, gucu_slk_refresh);
	scm_c_define_gsubr ("slk-restore", 0, 0, 0, gucu_slk_restore);
	scm_c_define_gsubr ("slk-set", 3, 0, 0, gucu_slk_set);
	scm_c_define_gsubr ("slk-touch", 0, 0, 0, gucu_slk_touch);
	scm_c_define_gsubr ("start-color", 0, 0, 0, gucu_start_color);
	scm_c_define_gsubr ("subpad", 5, 0, 0, gucu_subpad);
	scm_c_define_gsubr ("subwin", 5, 0, 0, gucu_subwin);
	scm_c_define_gsubr ("syncok", 2, 0, 0, gucu_syncok);
	scm_c_define_gsubr ("termattrs", 0, 0, 0, gucu_termattrs);
	scm_c_define_gsubr ("termname", 0, 0, 0, gucu_termname);
	scm_c_define_gsubr ("tgetent", 2, 0, 0, gucu_tgetent);
	scm_c_define_gsubr ("tigetflag", 1, 0, 0, gucu_tigetflag);
	scm_c_define_gsubr ("tigetnum", 1, 0, 0, gucu_tigetnum);
	scm_c_define_gsubr ("tigetstr", 1, 0, 0, gucu_tigetstr);
	scm_c_define_gsubr ("touchline", 3, 0, 0, gucu_touchline);
	scm_c_define_gsubr ("touchwin", 1, 0, 0, gucu_touchwin);
	scm_c_define_gsubr ("typeahead", 1, 0, 0, gucu_typeahead);
	scm_c_define_gsubr ("ungetch", 1, 0, 0, gucu_ungetch);
	scm_c_define_gsubr ("untouchwin", 1, 0, 0, gucu_untouchwin);
	scm_c_define_gsubr ("use-default-colors", 0, 0, 0, 
			    gucu_use_default_colors);
	scm_c_define_gsubr ("use-env", 1, 0, 0, gucu_use_env);
	scm_c_define_gsubr ("use-extended-names", 1, 0, 0, 
			    gucu_use_extended_names);
	scm_c_define_gsubr ("vidattr", 1, 0, 0, gucu_vidattr);
	scm_c_define_gsubr ("%waddch", 2, 0, 0, gucu_waddch);
	scm_c_define_gsubr ("%waddchnstr", 3, 0, 0, gucu_waddchnstr);
	scm_c_define_gsubr ("%waddnstr", 3, 0, 0, gucu_waddnstr);
	scm_c_define_gsubr ("%wattr-off", 2, 0, 0, gucu_wattr_off);
	scm_c_define_gsubr ("%wattr-on", 2, 0, 0, gucu_wattr_on);
	scm_c_define_gsubr ("%wbkgd", 2, 0, 0, gucu_wbkgd);
	scm_c_define_gsubr ("%wbkgdset", 2, 0, 0, gucu_wbkgdset);
	scm_c_define_gsubr ("%wborder", 9, 0, 0, gucu_wborder);
	scm_c_define_gsubr ("%wchgat", 4, 0, 0, gucu_wchgat);
	scm_c_define_gsubr ("%wclear", 1, 0, 0, gucu_wclear);
	scm_c_define_gsubr ("%wclrtobot", 1, 0, 0, gucu_wclrtobot);
	scm_c_define_gsubr ("%wclrtoeol", 1, 0, 0, gucu_wclrtoeol);
	scm_c_define_gsubr ("wcursyncup", 1, 0, 0, gucu_wcursyncup);
	scm_c_define_gsubr ("%wcolor-set", 2, 0, 0, gucu_wcolor_set);
	scm_c_define_gsubr ("%wdelch", 1, 0, 0, gucu_wdelch);
	scm_c_define_gsubr ("wdeleteln", 1, 0, 0, gucu_wdeleteln);
	scm_c_define_gsubr ("%wechochar", 2, 0, 0, gucu_wechochar);
	scm_c_define_gsubr ("wenclose", 3, 0, 0, gucu_wenclose);
	scm_c_define_gsubr ("werase", 1, 0, 0, gucu_werase);
	scm_c_define_gsubr ("wgetch", 1, 0, 0, gucu_wgetch);
	scm_c_define_gsubr ("%whline", 3, 0, 0, gucu_whline);
	scm_c_define_gsubr ("winch", 1, 0, 0, gucu_winch);
	scm_c_define_gsubr ("winsch", 2, 0, 0, gucu_winsch);
	scm_c_define_gsubr ("winsdelln", 2, 0, 0, gucu_winsdelln);
	scm_c_define_gsubr ("winsertln", 1, 0, 0, gucu_winsertln);
	scm_c_define_gsubr ("winsnstr", 3, 0, 0, gucu_winsnstr);
	scm_c_define_gsubr ("winsstr", 2, 0, 0, gucu_winsstr);
	scm_c_define_gsubr ("wmove", 3, 0, 0, gucu_wmove);
	scm_c_define_gsubr ("wnoutrefresh", 1, 0, 0, gucu_wnoutrefresh);
	scm_c_define_gsubr ("wredrawln", 3, 0, 0, gucu_wredrawln);
	scm_c_define_gsubr ("wrefresh", 1, 0, 0, gucu_wrefresh);
	scm_c_define_gsubr ("wscrl", 2, 0, 0, gucu_wscrl);
	scm_c_define_gsubr ("%wsetscrreg", 3, 0, 0, gucu_wsetscrreg);
	scm_c_define_gsubr ("%wstandend", 1, 0, 0, gucu_wstandend);
	scm_c_define_gsubr ("%wstandout", 1, 0, 0, gucu_wstandout);
	scm_c_define_gsubr ("wsyncup", 1, 0, 0, gucu_wsyncup);
	scm_c_define_gsubr ("wsyncdown", 1, 0, 0, gucu_wsyncdown);
	scm_c_define_gsubr ("wtimeout", 2, 0, 0, gucu_wtimeout);
	scm_c_define_gsubr ("wtouchln", 4, 0, 0, gucu_wtouchln);
	scm_c_define_gsubr ("%wvline", 3, 0, 0, gucu_wvline);
}
