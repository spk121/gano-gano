
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "curs_func.h"
#include "type.h"
#include "term.h"
#define _GNU_SOURCE
#define cstring_t cchar_t
// 1: int addch
// 2: const chtype
// 3: 
// 4: 
SCM
gucu_addch (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "addch");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = addch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int addchnstr
// 2: const chtype *
// 3:  int
// 4: 
// 5: 
SCM
gucu_addchnstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_chstring (arg1), arg1, SCM_ARG1, "addchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "addchnstr");

	 chtype *c_arg1 = _scm_to_chstring (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = addchnstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int addchstr
// 2: const chtype *
// 3: 
// 4: 
SCM
gucu_addchstr (SCM arg1)
{
	SCM_ASSERT (_scm_is_chstring (arg1), arg1, SCM_ARG1, "addchstr");

	 chtype *c_arg1 = _scm_to_chstring (arg1);

	int ret = addchstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int addnstr
// 2: const char *
// 3:  int
// 4: 
// 5: 
SCM
gucu_addnstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "addnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "addnstr");

	 char *c_arg1 = scm_to_locale_string (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = addnstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int addstr
// 2: const char *
// 3: 
// 4: 
SCM
gucu_addstr (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "addstr");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = addstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int attroff
// 2: int
// 3: 
// 4: 
SCM
gucu_attroff (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "attroff");

	int c_arg1 = scm_to_int (arg1);

	int ret = attroff (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int attron
// 2: int
// 3: 
// 4: 
SCM
gucu_attron (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "attron");

	int c_arg1 = scm_to_int (arg1);

	int ret = attron (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int attrset
// 2: int
// 3: 
// 4: 
SCM
gucu_attrset (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "attrset");

	int c_arg1 = scm_to_int (arg1);

	int ret = attrset (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int attr_off
// 2: attr_t
// 3:  void *
// 4: 
// 5: 
SCM
gucu_attr_off (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_attr (arg1), arg1, SCM_ARG1, "attr-off");
	SCM_ASSERT (_scm_is_voidstring (arg2), arg2, SCM_ARG2, "attr-off");

	attr_t c_arg1 = _scm_to_attr (arg1);
	void *c_arg2 = _scm_to_voidstring (arg2);

	int ret = attr_off (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int attr_on
// 2: attr_t
// 3:  void *
// 4: 
// 5: 
SCM
gucu_attr_on (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_attr (arg1), arg1, SCM_ARG1, "attr-on");
	SCM_ASSERT (_scm_is_voidstring (arg2), arg2, SCM_ARG2, "attr-on");

	attr_t c_arg1 = _scm_to_attr (arg1);
	void *c_arg2 = _scm_to_voidstring (arg2);

	int ret = attr_on (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int baudrate
// 2: void
// 3: 
// 4: 
SCM
gucu_baudrate ()
{
	int ret = baudrate ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int beep
// 2: void
// 3: 
// 4: 
SCM
gucu_beep ()
{
	int ret = beep ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int bkgd
// 2: chtype
// 3: 
// 4: 
SCM
gucu_bkgd (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "bkgd");

	chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = bkgd (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void bkgdset
// 2: chtype
// 3: 
// 4: 
SCM
gucu_bkgdset (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "bkgdset");

	chtype c_arg1 = _scm_to_chtype (arg1);

	 bkgdset (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int border
// 2: chtype
// 3:  chtype
// 4:  chtype
// 5:  chtype
// 6:  chtype
// 7:  chtype
// 8:  chtype
// 9:  chtype
// 10: 
// 11: 
SCM
gucu_border (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "border");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "border");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "border");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "border");
	SCM_ASSERT (_scm_is_chtype (arg5), arg5, SCM_ARG5, "border");
	SCM_ASSERT (_scm_is_chtype (arg6), arg6, SCM_ARG6, "border");
	SCM_ASSERT (_scm_is_chtype (arg7), arg7, SCM_ARG7, "border");
	SCM_ASSERT (_scm_is_chtype (arg8), arg8, 8, "border");

	chtype c_arg1 = _scm_to_chtype (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);
	chtype c_arg4 = _scm_to_chtype (arg4);
	chtype c_arg5 = _scm_to_chtype (arg5);
	chtype c_arg6 = _scm_to_chtype (arg6);
	chtype c_arg7 = _scm_to_chtype (arg7);
	chtype c_arg8 = _scm_to_chtype (arg8);

	int ret = border (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7, c_arg8);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int box
// 2: WINDOW *
// 3:  chtype
// 4:  chtype
// 5: 
// 6: 
SCM
gucu_box (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "box");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "box");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "box");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);

	int ret = box (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: bool can_change_color
// 2: void
// 3: 
// 4: 
SCM
gucu_can_change_color ()
{
	bool ret = can_change_color ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: int cbreak
// 2: void
// 3: 
// 4: 
SCM
gucu_cbreak ()
{
	int ret = cbreak ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int chgat
// 2: int
// 3:  attr_t
// 4:  short
// 5:  const void *
// 6: 
// 7: 
SCM
gucu_chgat (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "chgat");
	SCM_ASSERT (_scm_is_attr (arg2), arg2, SCM_ARG2, "chgat");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "chgat");
	SCM_ASSERT (_scm_is_voidstring (arg4), arg4, SCM_ARG4, "chgat");

	int c_arg1 = scm_to_int (arg1);
	attr_t c_arg2 = _scm_to_attr (arg2);
	short c_arg3 = scm_to_short (arg3);
	 void *c_arg4 = _scm_to_voidstring (arg4);

	int ret = chgat (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int clearok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_clearok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "clearok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "clearok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = clearok (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int clear
// 2: void
// 3: 
// 4: 
SCM
gucu_clear ()
{
	int ret = clear ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int clrtobot
// 2: void
// 3: 
// 4: 
SCM
gucu_clrtobot ()
{
	int ret = clrtobot ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int clrtoeol
// 2: void
// 3: 
// 4: 
SCM
gucu_clrtoeol ()
{
	int ret = clrtoeol ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int COLOR_PAIR
// 2: int
// 3: 
// 4: 
SCM
gucu_COLOR_PAIR (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "color-pair");

	int c_arg1 = scm_to_int (arg1);

	int ret = COLOR_PAIR (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int color_set
// 2: short
// 3: void *
// 4: 
// 5: 
SCM
gucu_color_set (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "color-set");
	SCM_ASSERT (_scm_is_voidstring (arg2), arg2, SCM_ARG2, "color-set");

	short c_arg1 = scm_to_short (arg1);
	void *c_arg2 = _scm_to_voidstring (arg2);

	int ret = color_set (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int copywin
// 2: const WINDOW *
// 3:  WINDOW *
// 4:  int
// 5:  int
// 6:  int
// 7:  int
// 8:  int
// 9:  int
// 10:  int
// 11: 
// 12: 
SCM
gucu_copywin (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8, SCM arg9)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "copywin");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "copywin");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "copywin");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "copywin");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "copywin");
	SCM_ASSERT (scm_is_integer (arg6), arg6, SCM_ARG6, "copywin");
	SCM_ASSERT (scm_is_integer (arg7), arg7, SCM_ARG7, "copywin");
	SCM_ASSERT (scm_is_integer (arg8), arg8, 8, "copywin");
	SCM_ASSERT (scm_is_integer (arg9), arg9, 9, "copywin");

	 WINDOW *c_arg1 = _scm_to_window (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	int c_arg5 = scm_to_int (arg5);
	int c_arg6 = scm_to_int (arg6);
	int c_arg7 = scm_to_int (arg7);
	int c_arg8 = scm_to_int (arg8);
	int c_arg9 = scm_to_int (arg9);

	int ret = copywin (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7, c_arg8, c_arg9);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int curs_set
// 2: int
// 3: 
// 4: 
SCM
gucu_curs_set (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "curs-set");

	int c_arg1 = scm_to_int (arg1);

	int ret = curs_set (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int def_prog_mode
// 2: void
// 3: 
// 4: 
SCM
gucu_def_prog_mode ()
{
	int ret = def_prog_mode ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int def_shell_mode
// 2: void
// 3: 
// 4: 
SCM
gucu_def_shell_mode ()
{
	int ret = def_shell_mode ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int delay_output
// 2: int
// 3: 
// 4: 
SCM
gucu_delay_output (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "delay-output");

	int c_arg1 = scm_to_int (arg1);

	int ret = delay_output (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int delch
// 2: void
// 3: 
// 4: 
SCM
gucu_delch ()
{
	int ret = delch ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int deleteln
// 2: void
// 3: 
// 4: 
SCM
gucu_deleteln ()
{
	int ret = deleteln ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void delscreen
// 2: SCREEN *
// 3: 
// 4: 
SCM
gucu_delscreen (SCM arg1)
{
	SCM_ASSERT (_scm_is_screen (arg1), arg1, SCM_ARG1, "delscreen");

	SCREEN *c_arg1 = _scm_to_screen (arg1);

	 delscreen (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: WINDOW *derwin
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  int
// 7: 
// 8: 
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

// 1: int doupdate
// 2: void
// 3: 
// 4: 
SCM
gucu_doupdate ()
{
	int ret = doupdate ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: WINDOW *dupwin
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_dupwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "dupwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	WINDOW * ret = dupwin (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

// 1: int echo
// 2: void
// 3: 
// 4: 
SCM
gucu_echo ()
{
	int ret = echo ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int echochar
// 2: const chtype
// 3: 
// 4: 
SCM
gucu_echochar (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "echochar");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = echochar (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int endwin
// 2: void
// 3: 
// 4: 
SCM
gucu_endwin ()
{
	int ret = endwin ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char erasechar
// 2: void
// 3: 
// 4: 
SCM
gucu_erasechar ()
{
	char ret = erasechar ();
	SCM s_ret = scm_from_char (ret);

	return s_ret;
}

// 1: int erase
// 2: void
// 3: 
// 4: 
SCM
gucu_erase ()
{
	int ret = erase ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void filter
// 2: void
// 3: 
// 4: 
SCM
gucu_filter ()
{
	 filter ();
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int flash
// 2: void
// 3: 
// 4: 
SCM
gucu_flash ()
{
	int ret = flash ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int flushinp
// 2: void
// 3: 
// 4: 
SCM
gucu_flushinp ()
{
	int ret = flushinp ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: chtype getbkgd
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_getbkgd (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "getbkgd");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	chtype ret = getbkgd (c_arg1);
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

// 1: int getch
// 2: void
// 3: 
// 4: 
SCM
gucu_getch ()
{
	int ret = getch ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: WINDOW *getwin
// 2: FILE *
// 3: 
// 4: 
SCM
gucu_getwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_file (arg1), arg1, SCM_ARG1, "getwin");

	FILE *c_arg1 = _scm_to_file (arg1);

	WINDOW * ret = getwin (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

// 1: int halfdelay
// 2: int
// 3: 
// 4: 
SCM
gucu_halfdelay (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "halfdelay");

	int c_arg1 = scm_to_int (arg1);

	int ret = halfdelay (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: bool has_colors
// 2: void
// 3: 
// 4: 
SCM
gucu_has_colors ()
{
	bool ret = has_colors ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: bool has_ic
// 2: void
// 3: 
// 4: 
SCM
gucu_has_ic ()
{
	bool ret = has_ic ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: bool has_il
// 2: void
// 3: 
// 4: 
SCM
gucu_has_il ()
{
	bool ret = has_il ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: int hline
// 2: chtype
// 3:  int
// 4: 
// 5: 
SCM
gucu_hline (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "hline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "hline");

	chtype c_arg1 = _scm_to_chtype (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = hline (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void idcok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_idcok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "idcok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "idcok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	 idcok (c_arg1, c_arg2);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int idlok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_idlok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "idlok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "idlok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = idlok (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void immedok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_immedok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "immedok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "immedok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	 immedok (c_arg1, c_arg2);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: chtype inch
// 2: void
// 3: 
// 4: 
SCM
gucu_inch ()
{
	chtype ret = inch ();
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

// 1: WINDOW *initscr
// 2: void
// 3: 
// 4: 
SCM
gucu_initscr ()
{
	WINDOW * ret = initscr ();
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

// 1: int init_color
// 2: short
// 3:  short
// 4:  short
// 5:  short
// 6: 
// 7: 
SCM
gucu_init_color (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "init-color");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "init-color");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "init-color");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "init-color");

	short c_arg1 = scm_to_short (arg1);
	short c_arg2 = scm_to_short (arg2);
	short c_arg3 = scm_to_short (arg3);
	short c_arg4 = scm_to_short (arg4);

	int ret = init_color (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int init_pair
// 2: short
// 3:  short
// 4:  short
// 5: 
// 6: 
SCM
gucu_init_pair (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "init-pair");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "init-pair");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "init-pair");

	short c_arg1 = scm_to_short (arg1);
	short c_arg2 = scm_to_short (arg2);
	short c_arg3 = scm_to_short (arg3);

	int ret = init_pair (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int insch
// 2: chtype
// 3: 
// 4: 
SCM
gucu_insch (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "insch");

	chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = insch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int insdelln
// 2: int
// 3: 
// 4: 
SCM
gucu_insdelln (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "insdelln");

	int c_arg1 = scm_to_int (arg1);

	int ret = insdelln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int insertln
// 2: void
// 3: 
// 4: 
SCM
gucu_insertln ()
{
	int ret = insertln ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int insnstr
// 2: const char *
// 3:  int
// 4: 
// 5: 
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

// 1: int insstr
// 2: const char *
// 3: 
// 4: 
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

// 1: int intrflush
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_intrflush (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "intrflush");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "intrflush");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = intrflush (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: bool isendwin
// 2: void
// 3: 
// 4: 
SCM
gucu_isendwin ()
{
	bool ret = isendwin ();
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: bool is_linetouched
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
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

// 1: bool is_wintouched
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_is_wintouched (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "is-wintouched");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	bool ret = is_wintouched (c_arg1);
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: int KEY_F
// 2: int
// 3: 
// 4: 
SCM
gucu_KEY_F (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "key-f");

	int c_arg1 = scm_to_int (arg1);

	int ret = KEY_F (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char *keyname
// 2: int
// 3: 
// 4: 
SCM
gucu_keyname (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "keyname");

	int c_arg1 = scm_to_int (arg1);

	char * ret = keyname (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

// 1: int keypad
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_keypad (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "keypad");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "keypad");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = keypad (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char killchar
// 2: void
// 3: 
// 4: 
SCM
gucu_killchar ()
{
	char ret = killchar ();
	SCM s_ret = scm_from_char (ret);

	return s_ret;
}

// 1: int leaveok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_leaveok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "leaveok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "leaveok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = leaveok (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char *longname
// 2: void
// 3: 
// 4: 
SCM
gucu_longname ()
{
	char * ret = longname ();
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

// 1: int meta
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_meta (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "meta");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "meta");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = meta (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mouseinterval
// 2: int
// 3: 
// 4: 
SCM
gucu_mouseinterval (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mouseinterval");

	int c_arg1 = scm_to_int (arg1);

	int ret = mouseinterval (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int move
// 2: int
// 3:  int
// 4: 
// 5: 
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

// 1: int mvaddch
// 2: int
// 3:  int
// 4:  const chtype
// 5: 
// 6: 
SCM
gucu_mvaddch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddch");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "mvaddch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	const chtype c_arg3 = _scm_to_chtype (arg3);

	int ret = mvaddch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvaddchnstr
// 2: int
// 3:  int
// 4:  const chtype *
// 5:  int
// 6: 
// 7: 
SCM
gucu_mvaddchnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddchnstr");
	SCM_ASSERT (_scm_is_chstring (arg3), arg3, SCM_ARG3, "mvaddchnstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvaddchnstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 chtype *c_arg3 = _scm_to_chstring (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvaddchnstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvaddchstr
// 2: int
// 3:  int
// 4:  const chtype *
// 5: 
// 6: 
SCM
gucu_mvaddchstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddchstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddchstr");
	SCM_ASSERT (_scm_is_chstring (arg3), arg3, SCM_ARG3, "mvaddchstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 chtype *c_arg3 = _scm_to_chstring (arg3);

	int ret = mvaddchstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvaddnstr
// 2: int
// 3:  int
// 4:  const char *
// 5:  int
// 6: 
// 7: 
SCM
gucu_mvaddnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddnstr");
	SCM_ASSERT (scm_is_string (arg3), arg3, SCM_ARG3, "mvaddnstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvaddnstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 char *c_arg3 = scm_to_locale_string (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvaddnstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvaddstr
// 2: int
// 3:  int
// 4:  const char *
// 5: 
// 6: 
SCM
gucu_mvaddstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddstr");
	SCM_ASSERT (scm_is_string (arg3), arg3, SCM_ARG3, "mvaddstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 char *c_arg3 = scm_to_locale_string (arg3);

	int ret = mvaddstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvchgat
// 2: int
// 3:  int
// 4:  int
// 5:  attr_t
// 6:  short
// 7:  const void *
// 8: 
// 9: 
SCM
gucu_mvchgat (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvchgat");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvchgat");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvchgat");
	SCM_ASSERT (_scm_is_attr (arg4), arg4, SCM_ARG4, "mvchgat");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvchgat");
	SCM_ASSERT (_scm_is_voidstring (arg6), arg6, SCM_ARG6, "mvchgat");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	attr_t c_arg4 = _scm_to_attr (arg4);
	short c_arg5 = scm_to_short (arg5);
	 void *c_arg6 = _scm_to_voidstring (arg6);

	int ret = mvchgat (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvcur
// 2: int
// 3:  int
// 4:  int
// 5:  int
// 6: 
// 7: 
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

// 1: int mvdelch
// 2: int
// 3:  int
// 4: 
// 5: 
SCM
gucu_mvdelch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvdelch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvdelch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = mvdelch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvderwin
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int mvgetch
// 2: int
// 3:  int
// 4: 
// 5: 
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

// 1: int mvhline
// 2: int
// 3:  int
// 4:  chtype
// 5:  int
// 6: 
// 7: 
SCM
gucu_mvhline (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvhline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvhline");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "mvhline");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvhline");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvhline (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: chtype mvinch
// 2: int
// 3:  int
// 4: 
// 5: 
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

// 1: int mvinsch
// 2: int
// 3:  int
// 4:  chtype
// 5: 
// 6: 
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

// 1: int mvinsnstr
// 2: int
// 3:  int
// 4:  const char *
// 5:  int
// 6: 
// 7: 
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

// 1: int mvinsstr
// 2: int
// 3:  int
// 4:  const char *
// 5: 
// 6: 
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

// 1: int mvvline
// 2: int
// 3:  int
// 4:  chtype
// 5:  int
// 6: 
// 7: 
SCM
gucu_mvvline (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvvline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvvline");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "mvvline");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvvline");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvvline (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvwaddch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const chtype
// 6: 
// 7: 
SCM
gucu_mvwaddch (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddch");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "mvwaddch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	const chtype c_arg4 = _scm_to_chtype (arg4);

	int ret = mvwaddch (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvwaddchnstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const chtype *
// 6:  int
// 7: 
// 8: 
SCM
gucu_mvwaddchnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddchnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddchnstr");
	SCM_ASSERT (_scm_is_chstring (arg4), arg4, SCM_ARG4, "mvwaddchnstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwaddchnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 chtype *c_arg4 = _scm_to_chstring (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwaddchnstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwaddchstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const chtype *
// 6: 
// 7: 
SCM
gucu_mvwaddchstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddchstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddchstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddchstr");
	SCM_ASSERT (_scm_is_chstring (arg4), arg4, SCM_ARG4, "mvwaddchstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 chtype *c_arg4 = _scm_to_chstring (arg4);

	int ret = mvwaddchstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwaddnstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const char *
// 6:  int
// 7: 
// 8: 
SCM
gucu_mvwaddnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddnstr");
	SCM_ASSERT (scm_is_string (arg4), arg4, SCM_ARG4, "mvwaddnstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwaddnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 char *c_arg4 = scm_to_locale_string (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwaddnstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwaddstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const char *
// 6: 
// 7: 
SCM
gucu_mvwaddstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddstr");
	SCM_ASSERT (scm_is_string (arg4), arg4, SCM_ARG4, "mvwaddstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 char *c_arg4 = scm_to_locale_string (arg4);

	int ret = mvwaddstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwchgat
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  attr_t
// 7:  short
// 8:  const void *
// 9: 
// 10: 
SCM
gucu_mvwchgat (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwchgat");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwchgat");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwchgat");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvwchgat");
	SCM_ASSERT (_scm_is_attr (arg5), arg5, SCM_ARG5, "mvwchgat");
	SCM_ASSERT (scm_is_integer (arg6), arg6, SCM_ARG6, "mvwchgat");
	SCM_ASSERT (_scm_is_voidstring (arg7), arg7, SCM_ARG7, "mvwchgat");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	int c_arg4 = scm_to_int (arg4);
	attr_t c_arg5 = _scm_to_attr (arg5);
	short c_arg6 = scm_to_short (arg6);
	 void *c_arg7 = _scm_to_voidstring (arg7);

	int ret = mvwchgat (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvwdelch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
SCM
gucu_mvwdelch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwdelch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwdelch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwdelch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = mvwdelch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvwgetch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int mvwhline
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  chtype
// 6:  int
// 7: 
// 8: 
SCM
gucu_mvwhline (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwhline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwhline");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwhline");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "mvwhline");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwhline");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	chtype c_arg4 = _scm_to_chtype (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwhline (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int mvwin
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: chtype mvwinch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int mvwinsch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  chtype
// 6: 
// 7: 
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

// 1: int mvwinsnstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const char *
// 6:  int
// 7: 
// 8: 
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

// 1: int mvwinsstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const char *
// 6: 
// 7: 
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

// 1: int mvwvline
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  chtype
// 6:  int
// 7: 
// 8: 
SCM
gucu_mvwvline (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwvline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwvline");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwvline");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "mvwvline");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwvline");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	chtype c_arg4 = _scm_to_chtype (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwvline (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int napms
// 2: int
// 3: 
// 4: 
SCM
gucu_napms (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "napms");

	int c_arg1 = scm_to_int (arg1);

	int ret = napms (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: WINDOW *newpad
// 2: int
// 3:  int
// 4: 
// 5: 
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

// 1: WINDOW *newwin
// 2: int
// 3:  int
// 4:  int
// 5:  int
// 6: 
// 7: 
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

// 1: int nl
// 2: void
// 3: 
// 4: 
SCM
gucu_nl ()
{
	int ret = nl ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int nocbreak
// 2: void
// 3: 
// 4: 
SCM
gucu_nocbreak ()
{
	int ret = nocbreak ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int nodelay
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_nodelay (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "nodelay");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "nodelay");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = nodelay (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int noecho
// 2: void
// 3: 
// 4: 
SCM
gucu_noecho ()
{
	int ret = noecho ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int nonl
// 2: void
// 3: 
// 4: 
SCM
gucu_nonl ()
{
	int ret = nonl ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void noqiflush
// 2: void
// 3: 
// 4: 
SCM
gucu_noqiflush ()
{
	 noqiflush ();
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int noraw
// 2: void
// 3: 
// 4: 
SCM
gucu_noraw ()
{
	int ret = noraw ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int notimeout
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_notimeout (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "notimeout");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "notimeout");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = notimeout (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int overlay
// 2: const WINDOW *
// 3:  WINDOW *
// 4: 
// 5: 
SCM
gucu_overlay (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "overlay");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "overlay");

	 WINDOW *c_arg1 = _scm_to_window (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = overlay (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int overwrite
// 2: const WINDOW *
// 3:  WINDOW *
// 4: 
// 5: 
SCM
gucu_overwrite (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "overwrite");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "overwrite");

	 WINDOW *c_arg1 = _scm_to_window (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = overwrite (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int PAIR_NUMBER
// 2: int
// 3: 
// 4: 
SCM
gucu_PAIR_NUMBER (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "pair-number");

	int c_arg1 = scm_to_int (arg1);

	int ret = PAIR_NUMBER (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int pechochar
// 2: WINDOW *
// 3:  chtype
// 4: 
// 5: 
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

// 1: int pnoutrefresh
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  int
// 7:  int
// 8:  int
// 9: 
// 10: 
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

// 1: int prefresh
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  int
// 7:  int
// 8:  int
// 9: 
// 10: 
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

// 1: int putp
// 2: const char *
// 3: 
// 4: 
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

// 1: int putwin
// 2: WINDOW *
// 3:  FILE *
// 4: 
// 5: 
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

// 1: void qiflush
// 2: void
// 3: 
// 4: 
SCM
gucu_qiflush ()
{
	 qiflush ();
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int raw
// 2: void
// 3: 
// 4: 
SCM
gucu_raw ()
{
	int ret = raw ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int redrawwin
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_redrawwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "redrawwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = redrawwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int refresh
// 2: void
// 3: 
// 4: 
SCM
gucu_refresh ()
{
	int ret = refresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int reset_prog_mode
// 2: void
// 3: 
// 4: 
SCM
gucu_reset_prog_mode ()
{
	int ret = reset_prog_mode ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int reset_shell_mode
// 2: void
// 3: 
// 4: 
SCM
gucu_reset_shell_mode ()
{
	int ret = reset_shell_mode ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int resetty
// 2: void
// 3: 
// 4: 
SCM
gucu_resetty ()
{
	int ret = resetty ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int savetty
// 2: void
// 3: 
// 4: 
SCM
gucu_savetty ()
{
	int ret = savetty ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int scr_dump
// 2: const char *
// 3: 
// 4: 
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

// 1: int scr_init
// 2: const char *
// 3: 
// 4: 
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

// 1: int scrl
// 2: int
// 3: 
// 4: 
SCM
gucu_scrl (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "scrl");

	int c_arg1 = scm_to_int (arg1);

	int ret = scrl (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int scroll
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_scroll (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "scroll");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = scroll (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int scrollok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_scrollok (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "scrollok");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "scrollok");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = scrollok (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int scr_restore
// 2: const char *
// 3: 
// 4: 
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

// 1: int scr_set
// 2: const char *
// 3: 
// 4: 
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

// 1: int setscrreg
// 2: int
// 3:  int
// 4: 
// 5: 
SCM
gucu_setscrreg (SCM arg1, SCM arg2)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "setscrreg");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "setscrreg");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = setscrreg (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: SCREEN *set_term
// 2: SCREEN *
// 3: 
// 4: 
SCM
gucu_set_term (SCM arg1)
{
	SCM_ASSERT (_scm_is_screen (arg1), arg1, SCM_ARG1, "set-term");

	SCREEN *c_arg1 = _scm_to_screen (arg1);

	SCREEN * ret = set_term (c_arg1);
	SCM s_ret = _scm_from_screen (ret);

	return s_ret;
}

// 1: int slk_attr_off
// 2: const attr_t
// 3:  void *
// 4: 
// 5: 
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

// 1: int slk_attroff
// 2: const chtype
// 3: 
// 4: 
SCM
gucu_slk_attroff (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attroff");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attroff (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_attr_on
// 2: const attr_t
// 3:  void *
// 4: 
// 5: 
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

// 1: int slk_attron
// 2: const chtype
// 3: 
// 4: 
SCM
gucu_slk_attron (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attron");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attron (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_attr_set
// 2: const attr_t
// 3:  short
// 4:  void *
// 5: 
// 6: 
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

// 1: int slk_attrset
// 2: const chtype
// 3: 
// 4: 
SCM
gucu_slk_attrset (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "slk-attrset");

	const chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = slk_attrset (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_clear
// 2: void
// 3: 
// 4: 
SCM
gucu_slk_clear ()
{
	int ret = slk_clear ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_color
// 2: short
// 3: 
// 4: 
SCM
gucu_slk_color (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-color");

	short c_arg1 = scm_to_short (arg1);

	int ret = slk_color (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_init
// 2: int
// 3: 
// 4: 
SCM
gucu_slk_init (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-init");

	int c_arg1 = scm_to_int (arg1);

	int ret = slk_init (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char *slk_label
// 2: int
// 3: 
// 4: 
SCM
gucu_slk_label (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "slk-label");

	int c_arg1 = scm_to_int (arg1);

	char * ret = slk_label (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

// 1: int slk_noutrefresh
// 2: void
// 3: 
// 4: 
SCM
gucu_slk_noutrefresh ()
{
	int ret = slk_noutrefresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_refresh
// 2: void
// 3: 
// 4: 
SCM
gucu_slk_refresh ()
{
	int ret = slk_refresh ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_restore
// 2: void
// 3: 
// 4: 
SCM
gucu_slk_restore ()
{
	int ret = slk_restore ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int slk_set
// 2: int
// 3:  const char *
// 4:  int
// 5: 
// 6: 
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

// 1: int slk_touch
// 2: void
// 3: 
// 4: 
SCM
gucu_slk_touch ()
{
	int ret = slk_touch ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int standend
// 2: void
// 3: 
// 4: 
SCM
gucu_standend ()
{
	int ret = standend ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int standout
// 2: void
// 3: 
// 4: 
SCM
gucu_standout ()
{
	int ret = standout ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int start_color
// 2: void
// 3: 
// 4: 
SCM
gucu_start_color ()
{
	int ret = start_color ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: WINDOW *subpad
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  int
// 7: 
// 8: 
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

// 1: WINDOW *subwin
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6:  int
// 7: 
// 8: 
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

// 1: int syncok
// 2: WINDOW *
// 3:  bool
// 4: 
// 5: 
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

// 1: chtype termattrs
// 2: void
// 3: 
// 4: 
SCM
gucu_termattrs ()
{
	chtype ret = termattrs ();
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

// 1: char *termname
// 2: void
// 3: 
// 4: 
SCM
gucu_termname ()
{
	char * ret = termname ();
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

// 1: int tgetent
// 2: void *
// 3:  const char *
// 4: 
// 5: 
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

// 1: int tigetflag
// 2: char *
// 3: 
// 4: 
SCM
gucu_tigetflag (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetflag");

	char *c_arg1 = scm_to_locale_string (arg1);

	int ret = tigetflag (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int tigetnum
// 2: char *
// 3: 
// 4: 
SCM
gucu_tigetnum (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetnum");

	char *c_arg1 = scm_to_locale_string (arg1);

	int ret = tigetnum (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: char *tigetstr
// 2: char *
// 3: 
// 4: 
SCM
gucu_tigetstr (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "tigetstr");

	char *c_arg1 = scm_to_locale_string (arg1);

	char * ret = tigetstr (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

// 1: void timeout
// 2: int
// 3: 
// 4: 
SCM
gucu_timeout (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "timeout");

	int c_arg1 = scm_to_int (arg1);

	 timeout (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int touchline
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int touchwin
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_touchwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "touchwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = touchwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int typeahead
// 2: int
// 3: 
// 4: 
SCM
gucu_typeahead (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "typeahead");

	int c_arg1 = scm_to_int (arg1);

	int ret = typeahead (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int ungetch
// 2: int
// 3: 
// 4: 
SCM
gucu_ungetch (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "ungetch");

	int c_arg1 = scm_to_int (arg1);

	int ret = ungetch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int untouchwin
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_untouchwin (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "untouchwin");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = untouchwin (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int use_default_colors
// 2: void
// 3: 
// 4: 
SCM
gucu_use_default_colors ()
{
	int ret = use_default_colors ();
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void use_env
// 2: bool
// 3: 
// 4: 
SCM
gucu_use_env (SCM arg1)
{
	SCM_ASSERT (scm_is_bool (arg1), arg1, SCM_ARG1, "use-env");

	bool c_arg1 = scm_to_bool (arg1);

	 use_env (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int vidattr
// 2: chtype
// 3: 
// 4: 
SCM
gucu_vidattr (SCM arg1)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "vidattr");

	chtype c_arg1 = _scm_to_chtype (arg1);

	int ret = vidattr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int vline
// 2: chtype
// 3:  int
// 4: 
// 5: 
SCM
gucu_vline (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_chtype (arg1), arg1, SCM_ARG1, "vline");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "vline");

	chtype c_arg1 = _scm_to_chtype (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = vline (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int waddch
// 2: WINDOW *
// 3:  const chtype
// 4: 
// 5: 
SCM
gucu_waddch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddch");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "waddch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	const chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = waddch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int waddchnstr
// 2: WINDOW *
// 3:  const chtype *
// 4:  int
// 5: 
// 6: 
SCM
gucu_waddchnstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddchnstr");
	SCM_ASSERT (_scm_is_chstring (arg2), arg2, SCM_ARG2, "waddchnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "waddchnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 chtype *c_arg2 = _scm_to_chstring (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = waddchnstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int waddchstr
// 2: WINDOW *
// 3:  const chtype *
// 4: 
// 5: 
SCM
gucu_waddchstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddchstr");
	SCM_ASSERT (_scm_is_chstring (arg2), arg2, SCM_ARG2, "waddchstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 chtype *c_arg2 = _scm_to_chstring (arg2);

	int ret = waddchstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int waddnstr
// 2: WINDOW *
// 3:  const char *
// 4:  int
// 5: 
// 6: 
SCM
gucu_waddnstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddnstr");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "waddnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "waddnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = waddnstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int waddstr
// 2: WINDOW *
// 3:  const char *
// 4: 
// 5: 
SCM
gucu_waddstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddstr");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "waddstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);

	int ret = waddstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int wattroff
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
SCM
gucu_wattroff (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wattroff");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wattroff");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = wattroff (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wattron
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
SCM
gucu_wattron (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wattron");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wattron");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = wattron (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wattrset
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
SCM
gucu_wattrset (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wattrset");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wattrset");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = wattrset (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wattr_off
// 2: WINDOW *
// 3:  attr_t
// 4:  void *
// 5: 
// 6: 
SCM
gucu_wattr_off (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wattr-off");
	SCM_ASSERT (_scm_is_attr (arg2), arg2, SCM_ARG2, "wattr-off");
	SCM_ASSERT (_scm_is_voidstring (arg3), arg3, SCM_ARG3, "wattr-off");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	attr_t c_arg2 = _scm_to_attr (arg2);
	void *c_arg3 = _scm_to_voidstring (arg3);

	int ret = wattr_off (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wattr_on
// 2: WINDOW *
// 3:  attr_t
// 4:  void *
// 5: 
// 6: 
SCM
gucu_wattr_on (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wattr-on");
	SCM_ASSERT (_scm_is_attr (arg2), arg2, SCM_ARG2, "wattr-on");
	SCM_ASSERT (_scm_is_voidstring (arg3), arg3, SCM_ARG3, "wattr-on");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	attr_t c_arg2 = _scm_to_attr (arg2);
	void *c_arg3 = _scm_to_voidstring (arg3);

	int ret = wattr_on (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wbkgd
// 2: WINDOW *
// 3:  chtype
// 4: 
// 5: 
SCM
gucu_wbkgd (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wbkgd");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "wbkgd");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = wbkgd (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void wbkgdset
// 2: WINDOW *
// 3:  chtype
// 4: 
// 5: 
SCM
gucu_wbkgdset (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wbkgdset");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "wbkgdset");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	 wbkgdset (c_arg1, c_arg2);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int wborder
// 2: WINDOW *
// 3:  chtype
// 4:  chtype
// 5:  chtype
// 6:  chtype
// 7:  chtype
// 8:  chtype
// 9:  chtype
// 10:  chtype
// 11: 
// 12: 
SCM
gucu_wborder (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8, SCM arg9)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg3), arg3, SCM_ARG3, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg4), arg4, SCM_ARG4, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg5), arg5, SCM_ARG5, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg6), arg6, SCM_ARG6, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg7), arg7, SCM_ARG7, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg8), arg8, 8, "wborder");
	SCM_ASSERT (_scm_is_chtype (arg9), arg9, 9, "wborder");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);
	chtype c_arg3 = _scm_to_chtype (arg3);
	chtype c_arg4 = _scm_to_chtype (arg4);
	chtype c_arg5 = _scm_to_chtype (arg5);
	chtype c_arg6 = _scm_to_chtype (arg6);
	chtype c_arg7 = _scm_to_chtype (arg7);
	chtype c_arg8 = _scm_to_chtype (arg8);
	chtype c_arg9 = _scm_to_chtype (arg9);

	int ret = wborder (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7, c_arg8, c_arg9);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wchgat
// 2: WINDOW *
// 3:  int
// 4:  attr_t
// 5:  short
// 6:  const void *
// 7: 
// 8: 
SCM
gucu_wchgat (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wchgat");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wchgat");
	SCM_ASSERT (_scm_is_attr (arg3), arg3, SCM_ARG3, "wchgat");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "wchgat");
	SCM_ASSERT (_scm_is_voidstring (arg5), arg5, SCM_ARG5, "wchgat");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	attr_t c_arg3 = _scm_to_attr (arg3);
	short c_arg4 = scm_to_short (arg4);
	 void *c_arg5 = _scm_to_voidstring (arg5);

	int ret = wchgat (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wclear
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wclear (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wclear");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wclear (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wclrtobot
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wclrtobot (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wclrtobot");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wclrtobot (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wclrtoeol
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wclrtoeol (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wclrtoeol");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wclrtoeol (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void wcursyncup
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wcursyncup (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wcursyncup");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wcursyncup (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int wcolor_set
// 2: WINDOW *
// 3:  short
// 4:  void *
// 5: 
// 6: 
SCM
gucu_wcolor_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wcolor-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wcolor-set");
	SCM_ASSERT (_scm_is_voidstring (arg3), arg3, SCM_ARG3, "wcolor-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	short c_arg2 = scm_to_short (arg2);
	void *c_arg3 = _scm_to_voidstring (arg3);

	int ret = wcolor_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wdelch
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wdelch (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wdelch");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wdelch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wdeleteln
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wdeleteln (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wdeleteln");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wdeleteln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wechochar
// 2: WINDOW *
// 3:  const chtype
// 4: 
// 5: 
SCM
gucu_wechochar (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wechochar");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "wechochar");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	const chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = wechochar (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: bool wenclose
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int werase
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_werase (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "werase");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = werase (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wgetch
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wgetch (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wgetch");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wgetch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int whline
// 2: WINDOW *
// 3:  chtype
// 4:  int
// 5: 
// 6: 
SCM
gucu_whline (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "whline");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "whline");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "whline");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = whline (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: chtype winch
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_winch (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winch");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	chtype ret = winch (c_arg1);
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

// 1: int winsch
// 2: WINDOW *
// 3:  chtype
// 4: 
// 5: 
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

// 1: int winsdelln
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
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

// 1: int winsertln
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_winsertln (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "winsertln");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = winsertln (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int winsnstr
// 2: WINDOW *
// 3:  const char *
// 4:  int
// 5: 
// 6: 
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

// 1: int winsstr
// 2: WINDOW *
// 3:  const char *
// 4: 
// 5: 
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

// 1: int wmove
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int wnoutrefresh
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wnoutrefresh (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wnoutrefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wnoutrefresh (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wredrawln
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
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

// 1: int wrefresh
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wrefresh (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wrefresh");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wrefresh (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wscrl
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
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

// 1: int wsetscrreg
// 2: WINDOW *
// 3:  int
// 4:  int
// 5: 
// 6: 
SCM
gucu_wsetscrreg (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wsetscrreg");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wsetscrreg");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wsetscrreg");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wsetscrreg (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wstandend
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wstandend (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wstandend");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wstandend (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int wstandout
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wstandout (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wstandout");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	int ret = wstandout (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: void wsyncup
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wsyncup (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wsyncup");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wsyncup (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: void wsyncdown
// 2: WINDOW *
// 3: 
// 4: 
SCM
gucu_wsyncdown (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wsyncdown");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	 wsyncdown (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: void wtimeout
// 2: WINDOW *
// 3:  int
// 4: 
// 5: 
SCM
gucu_wtimeout (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wtimeout");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "wtimeout");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);

	 wtimeout (c_arg1, c_arg2);
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

// 1: int wtouchln
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  int
// 6: 
// 7: 
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

// 1: int wvline
// 2: WINDOW *
// 3:  chtype
// 4:  int
// 5: 
// 6: 
SCM
gucu_wvline (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wvline");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "wvline");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wvline");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wvline (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}


void 
gucu_init_function ()
{
	scm_c_define_gsubr ("addch", 1, 0, 0, gucu_addch);
	scm_c_define_gsubr ("addchnstr", 2, 0, 0, gucu_addchnstr);
	scm_c_define_gsubr ("addchstr", 1, 0, 0, gucu_addchstr);
	scm_c_define_gsubr ("addnstr", 2, 0, 0, gucu_addnstr);
	scm_c_define_gsubr ("addstr", 1, 0, 0, gucu_addstr);
	scm_c_define_gsubr ("attroff", 1, 0, 0, gucu_attroff);
	scm_c_define_gsubr ("attron", 1, 0, 0, gucu_attron);
	scm_c_define_gsubr ("attrset", 1, 0, 0, gucu_attrset);
	scm_c_define_gsubr ("attr-off", 2, 0, 0, gucu_attr_off);
	scm_c_define_gsubr ("attr-on", 2, 0, 0, gucu_attr_on);
	scm_c_define_gsubr ("baudrate", 0, 0, 0, gucu_baudrate);
	scm_c_define_gsubr ("beep", 0, 0, 0, gucu_beep);
	scm_c_define_gsubr ("bkgd", 1, 0, 0, gucu_bkgd);
	scm_c_define_gsubr ("bkgdset", 1, 0, 0, gucu_bkgdset);
	scm_c_define_gsubr ("border", 8, 0, 0, gucu_border);
	scm_c_define_gsubr ("box", 3, 0, 0, gucu_box);
	scm_c_define_gsubr ("can-change-color", 0, 0, 0, gucu_can_change_color);
	scm_c_define_gsubr ("cbreak", 0, 0, 0, gucu_cbreak);
	scm_c_define_gsubr ("chgat", 4, 0, 0, gucu_chgat);
	scm_c_define_gsubr ("clearok", 2, 0, 0, gucu_clearok);
	scm_c_define_gsubr ("clear", 0, 0, 0, gucu_clear);
	scm_c_define_gsubr ("clrtobot", 0, 0, 0, gucu_clrtobot);
	scm_c_define_gsubr ("clrtoeol", 0, 0, 0, gucu_clrtoeol);
	scm_c_define_gsubr ("color-pair", 1, 0, 0, gucu_COLOR_PAIR);
	scm_c_define_gsubr ("color-set", 2, 0, 0, gucu_color_set);
	scm_c_define_gsubr ("copywin", 9, 0, 0, gucu_copywin);
	scm_c_define_gsubr ("curs-set", 1, 0, 0, gucu_curs_set);
	scm_c_define_gsubr ("def-prog-mode", 0, 0, 0, gucu_def_prog_mode);
	scm_c_define_gsubr ("def-shell-mode", 0, 0, 0, gucu_def_shell_mode);
	scm_c_define_gsubr ("delay-output", 1, 0, 0, gucu_delay_output);
	scm_c_define_gsubr ("delch", 0, 0, 0, gucu_delch);
	scm_c_define_gsubr ("deleteln", 0, 0, 0, gucu_deleteln);
	scm_c_define_gsubr ("delscreen", 1, 0, 0, gucu_delscreen);
	scm_c_define_gsubr ("derwin", 5, 0, 0, gucu_derwin);
	scm_c_define_gsubr ("doupdate", 0, 0, 0, gucu_doupdate);
	scm_c_define_gsubr ("dupwin", 1, 0, 0, gucu_dupwin);
	scm_c_define_gsubr ("echo", 0, 0, 0, gucu_echo);
	scm_c_define_gsubr ("echochar", 1, 0, 0, gucu_echochar);
	scm_c_define_gsubr ("endwin", 0, 0, 0, gucu_endwin);
	scm_c_define_gsubr ("erasechar", 0, 0, 0, gucu_erasechar);
	scm_c_define_gsubr ("erase", 0, 0, 0, gucu_erase);
	scm_c_define_gsubr ("filter", 0, 0, 0, gucu_filter);
	scm_c_define_gsubr ("flash", 0, 0, 0, gucu_flash);
	scm_c_define_gsubr ("flushinp", 0, 0, 0, gucu_flushinp);
	scm_c_define_gsubr ("getbkgd", 1, 0, 0, gucu_getbkgd);
	scm_c_define_gsubr ("getch", 0, 0, 0, gucu_getch);
	scm_c_define_gsubr ("getwin", 1, 0, 0, gucu_getwin);
	scm_c_define_gsubr ("halfdelay", 1, 0, 0, gucu_halfdelay);
	scm_c_define_gsubr ("has-colors", 0, 0, 0, gucu_has_colors);
	scm_c_define_gsubr ("has-ic", 0, 0, 0, gucu_has_ic);
	scm_c_define_gsubr ("has-il", 0, 0, 0, gucu_has_il);
	scm_c_define_gsubr ("hline", 2, 0, 0, gucu_hline);
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
	scm_c_define_gsubr ("intrflush", 2, 0, 0, gucu_intrflush);
	scm_c_define_gsubr ("isendwin", 0, 0, 0, gucu_isendwin);
	scm_c_define_gsubr ("is-linetouched", 2, 0, 0, gucu_is_linetouched);
	scm_c_define_gsubr ("is-wintouched", 1, 0, 0, gucu_is_wintouched);
	scm_c_define_gsubr ("key-f", 1, 0, 0, gucu_KEY_F);
	scm_c_define_gsubr ("keyname", 1, 0, 0, gucu_keyname);
	scm_c_define_gsubr ("keypad", 2, 0, 0, gucu_keypad);
	scm_c_define_gsubr ("killchar", 0, 0, 0, gucu_killchar);
	scm_c_define_gsubr ("leaveok", 2, 0, 0, gucu_leaveok);
	scm_c_define_gsubr ("longname", 0, 0, 0, gucu_longname);
	scm_c_define_gsubr ("meta", 2, 0, 0, gucu_meta);
	scm_c_define_gsubr ("mouseinterval", 1, 0, 0, gucu_mouseinterval);
	scm_c_define_gsubr ("move", 2, 0, 0, gucu_move);
	scm_c_define_gsubr ("mvaddch", 3, 0, 0, gucu_mvaddch);
	scm_c_define_gsubr ("mvaddchnstr", 4, 0, 0, gucu_mvaddchnstr);
	scm_c_define_gsubr ("mvaddchstr", 3, 0, 0, gucu_mvaddchstr);
	scm_c_define_gsubr ("mvaddnstr", 4, 0, 0, gucu_mvaddnstr);
	scm_c_define_gsubr ("mvaddstr", 3, 0, 0, gucu_mvaddstr);
	scm_c_define_gsubr ("mvchgat", 6, 0, 0, gucu_mvchgat);
	scm_c_define_gsubr ("mvcur", 4, 0, 0, gucu_mvcur);
	scm_c_define_gsubr ("mvdelch", 2, 0, 0, gucu_mvdelch);
	scm_c_define_gsubr ("mvderwin", 3, 0, 0, gucu_mvderwin);
	scm_c_define_gsubr ("mvgetch", 2, 0, 0, gucu_mvgetch);
	scm_c_define_gsubr ("mvhline", 4, 0, 0, gucu_mvhline);
	scm_c_define_gsubr ("mvinch", 2, 0, 0, gucu_mvinch);
	scm_c_define_gsubr ("mvinsch", 3, 0, 0, gucu_mvinsch);
	scm_c_define_gsubr ("mvinsnstr", 4, 0, 0, gucu_mvinsnstr);
	scm_c_define_gsubr ("mvinsstr", 3, 0, 0, gucu_mvinsstr);
	scm_c_define_gsubr ("mvvline", 4, 0, 0, gucu_mvvline);
	scm_c_define_gsubr ("mvwaddch", 4, 0, 0, gucu_mvwaddch);
	scm_c_define_gsubr ("mvwaddchnstr", 5, 0, 0, gucu_mvwaddchnstr);
	scm_c_define_gsubr ("mvwaddchstr", 4, 0, 0, gucu_mvwaddchstr);
	scm_c_define_gsubr ("mvwaddnstr", 5, 0, 0, gucu_mvwaddnstr);
	scm_c_define_gsubr ("mvwaddstr", 4, 0, 0, gucu_mvwaddstr);
	scm_c_define_gsubr ("mvwchgat", 7, 0, 0, gucu_mvwchgat);
	scm_c_define_gsubr ("mvwdelch", 3, 0, 0, gucu_mvwdelch);
	scm_c_define_gsubr ("mvwgetch", 3, 0, 0, gucu_mvwgetch);
	scm_c_define_gsubr ("mvwhline", 5, 0, 0, gucu_mvwhline);
	scm_c_define_gsubr ("mvwin", 3, 0, 0, gucu_mvwin);
	scm_c_define_gsubr ("mvwinch", 3, 0, 0, gucu_mvwinch);
	scm_c_define_gsubr ("mvwinsch", 4, 0, 0, gucu_mvwinsch);
	scm_c_define_gsubr ("mvwinsnstr", 5, 0, 0, gucu_mvwinsnstr);
	scm_c_define_gsubr ("mvwinsstr", 4, 0, 0, gucu_mvwinsstr);
	scm_c_define_gsubr ("mvwvline", 5, 0, 0, gucu_mvwvline);
	scm_c_define_gsubr ("napms", 1, 0, 0, gucu_napms);
	scm_c_define_gsubr ("newpad", 2, 0, 0, gucu_newpad);
	scm_c_define_gsubr ("newwin", 4, 0, 0, gucu_newwin);
	scm_c_define_gsubr ("nl", 0, 0, 0, gucu_nl);
	scm_c_define_gsubr ("nocbreak", 0, 0, 0, gucu_nocbreak);
	scm_c_define_gsubr ("nodelay", 2, 0, 0, gucu_nodelay);
	scm_c_define_gsubr ("noecho", 0, 0, 0, gucu_noecho);
	scm_c_define_gsubr ("nonl", 0, 0, 0, gucu_nonl);
	scm_c_define_gsubr ("noqiflush", 0, 0, 0, gucu_noqiflush);
	scm_c_define_gsubr ("noraw", 0, 0, 0, gucu_noraw);
	scm_c_define_gsubr ("notimeout", 2, 0, 0, gucu_notimeout);
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
	scm_c_define_gsubr ("setscrreg", 2, 0, 0, gucu_setscrreg);
	scm_c_define_gsubr ("set-term", 1, 0, 0, gucu_set_term);
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
	scm_c_define_gsubr ("standend", 0, 0, 0, gucu_standend);
	scm_c_define_gsubr ("standout", 0, 0, 0, gucu_standout);
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
	scm_c_define_gsubr ("timeout", 1, 0, 0, gucu_timeout);
	scm_c_define_gsubr ("touchline", 3, 0, 0, gucu_touchline);
	scm_c_define_gsubr ("touchwin", 1, 0, 0, gucu_touchwin);
	scm_c_define_gsubr ("typeahead", 1, 0, 0, gucu_typeahead);
	scm_c_define_gsubr ("ungetch", 1, 0, 0, gucu_ungetch);
	scm_c_define_gsubr ("untouchwin", 1, 0, 0, gucu_untouchwin);
	scm_c_define_gsubr ("use-default-colors", 0, 0, 0, gucu_use_default_colors);
	scm_c_define_gsubr ("use-env", 1, 0, 0, gucu_use_env);
	scm_c_define_gsubr ("vidattr", 1, 0, 0, gucu_vidattr);
	scm_c_define_gsubr ("vline", 2, 0, 0, gucu_vline);
	scm_c_define_gsubr ("waddch", 2, 0, 0, gucu_waddch);
	scm_c_define_gsubr ("waddchnstr", 3, 0, 0, gucu_waddchnstr);
	scm_c_define_gsubr ("waddchstr", 2, 0, 0, gucu_waddchstr);
	scm_c_define_gsubr ("waddnstr", 3, 0, 0, gucu_waddnstr);
	scm_c_define_gsubr ("waddstr", 2, 0, 0, gucu_waddstr);
	scm_c_define_gsubr ("wattroff", 2, 0, 0, gucu_wattroff);
	scm_c_define_gsubr ("wattron", 2, 0, 0, gucu_wattron);
	scm_c_define_gsubr ("wattrset", 2, 0, 0, gucu_wattrset);
	scm_c_define_gsubr ("wattr-off", 3, 0, 0, gucu_wattr_off);
	scm_c_define_gsubr ("wattr-on", 3, 0, 0, gucu_wattr_on);
	scm_c_define_gsubr ("wbkgd", 2, 0, 0, gucu_wbkgd);
	scm_c_define_gsubr ("wbkgdset", 2, 0, 0, gucu_wbkgdset);
	scm_c_define_gsubr ("wborder", 9, 0, 0, gucu_wborder);
	scm_c_define_gsubr ("wchgat", 5, 0, 0, gucu_wchgat);
	scm_c_define_gsubr ("wclear", 1, 0, 0, gucu_wclear);
	scm_c_define_gsubr ("wclrtobot", 1, 0, 0, gucu_wclrtobot);
	scm_c_define_gsubr ("wclrtoeol", 1, 0, 0, gucu_wclrtoeol);
	scm_c_define_gsubr ("wcursyncup", 1, 0, 0, gucu_wcursyncup);
	scm_c_define_gsubr ("wcolor-set", 3, 0, 0, gucu_wcolor_set);
	scm_c_define_gsubr ("wdelch", 1, 0, 0, gucu_wdelch);
	scm_c_define_gsubr ("wdeleteln", 1, 0, 0, gucu_wdeleteln);
	scm_c_define_gsubr ("wechochar", 2, 0, 0, gucu_wechochar);
	scm_c_define_gsubr ("wenclose", 3, 0, 0, gucu_wenclose);
	scm_c_define_gsubr ("werase", 1, 0, 0, gucu_werase);
	scm_c_define_gsubr ("wgetch", 1, 0, 0, gucu_wgetch);
	scm_c_define_gsubr ("whline", 3, 0, 0, gucu_whline);
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
	scm_c_define_gsubr ("wsetscrreg", 3, 0, 0, gucu_wsetscrreg);
	scm_c_define_gsubr ("wstandend", 1, 0, 0, gucu_wstandend);
	scm_c_define_gsubr ("wstandout", 1, 0, 0, gucu_wstandout);
	scm_c_define_gsubr ("wsyncup", 1, 0, 0, gucu_wsyncup);
	scm_c_define_gsubr ("wsyncdown", 1, 0, 0, gucu_wsyncdown);
	scm_c_define_gsubr ("wtimeout", 2, 0, 0, gucu_wtimeout);
	scm_c_define_gsubr ("wtouchln", 4, 0, 0, gucu_wtouchln);
	scm_c_define_gsubr ("wvline", 3, 0, 0, gucu_wvline);
}
