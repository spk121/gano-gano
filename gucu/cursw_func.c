
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "cursw_func.h"
#include "type.h"
#include "typew.h"
#include "term.h"
#define _GNU_SOURCE
#define cstring_t cchar_t


/* Returns a character string corresponding to the key name */
SCM
gucu_key_name (SCM ch)
{
  wchar_t c_ch;
  char *ret;

  SCM_ASSERT (scm_is_integer (ch), ch, SCM_ARG1, "key-name");
  
  c_ch = _scm_to_wchar (ch);

  ret = key_name (c_ch);

  return scm_from_locale_string (ret);
}


/* Return all the video attributes supported by the terminal */
SCM
gucu_term_attrs ()
{
  attr_t ret;
  SCM s_ret;

  ret = term_attrs ();
  s_ret = _scm_from_attr (ret);

  return s_ret;
}

/* Push a wide character back on the input queue */
SCM
gucu_unget_wch (SCM ch)
{
  int ret;
  SCM s_ret;

  SCM_ASSERT (_scm_is_wchar (ch), ch, SCM_ARG1, "unget-wch");
  
  {
    const wchar_t c_ch = _scm_to_wchar (ch);

    ret = unget_wch (c_ch);
    s_ret = scm_from_int (ret);

    return s_ret;
  }
}

/* Write the wide string to the given window */
SCM
gucu_waddnwstr (SCM win, SCM wstr, SCM n)
{
  WINDOW *c_win;
  wchar_t *c_wstr;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%waddnwstr");
  SCM_ASSERT (_scm_is_wchar_string (wstr), wstr, SCM_ARG2, "%waddnwstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%waddnwstr");

  c_win = _scm_to_window (win);
  c_wstr = _scm_to_wchar_string (wstr);
  c_n = scm_to_int (n);

  ret = waddnwstr (c_win, c_wstr, c_n);

  free (c_wstr);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Add a wide character to a given window */
SCM
gucu_wadd_wch (SCM win, SCM wch)
{
  WINDOW *c_win;
  cchar_t *c_wch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wadd-wch");
  SCM_ASSERT (_scm_is_cchar (wch), wch, SCM_ARG2, "%wadd-wch");
  
  c_win = _scm_to_window (win);
  c_wch = _scm_to_cchar (wch);

  ret = wadd_wch (c_win, c_wch);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}


/* Copy the array of complex characters into the window at the current
   cursor positions.  If N=-1 try to copy all the characters, but, no
   more than one line's worth.  If N > -1, try to copy N characters,
   but, no more than one line's worth. */
SCM
gucu_wadd_wchnstr (SCM win, SCM wchstr, SCM n)
{
  WINDOW *c_win;
  cstring_t *c_wchstr;
  int c_n, ret;
	
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wadd-wchnstr");
  SCM_ASSERT (_scm_is_cstring (wchstr), wchstr, SCM_ARG2, "%wadd-wchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%wadd-wchnstr");

  c_win = _scm_to_window (win);
  c_wchstr = _scm_to_cstring (wchstr);
  c_n = scm_to_int (n);

  ret = wadd_wchnstr (c_win, c_wchstr, c_n);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

/* Set the background property to the window and apply to every char
   in the window */
SCM
gucu_wbkgrnd (SCM win, SCM wch)
{
  WINDOW *c_win;
  cchar_t *c_wch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wbkgrnd");
  SCM_ASSERT (_scm_is_cchar (wch), wch, SCM_ARG2, "%wbkgrnd");
  
  c_win = _scm_to_window (win);
  c_wch = _scm_to_cchar (wch);

  ret = wbkgrnd (c_win, c_wch);

  free (c_wch);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Set the background property to the window and apply to every char
   in the window */
SCM
gucu_wbkgrndset (SCM win, SCM wch)
{
  WINDOW *c_win;
  cchar_t *c_wch;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wbkgrndset");
  SCM_ASSERT (_scm_is_cchar (wch), wch, SCM_ARG2, "%wbkgrndset");

  c_win = _scm_to_window (win);
  c_wch = _scm_to_cchar (wch);

  wbkgrndset (c_win, c_wch);

  free (c_wch);
  
  return SCM_UNSPECIFIED;
}

/* Draw a window border using the followin complex characters */
SCM
gucu_wborder_set (SCM win, SCM left, SCM right, SCM top, SCM bottom, 
		  SCM topleft, SCM topright, SCM bottomleft, SCM bottomright)
{
  WINDOW *c_win;
  cchar_t *c_left, *c_right, *c_top, *c_bottom;
  cchar_t *c_topleft, *c_topright, *c_bottomleft, *c_bottomright;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (left), left, SCM_ARG2, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (right), right, SCM_ARG3, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (top), top, SCM_ARG4, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (bottom), bottom, SCM_ARG5, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (topleft), topleft, SCM_ARG6, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (topright), topright, SCM_ARG7, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (bottomleft), bottomleft, 8, "%wborder-set");
  SCM_ASSERT (_scm_is_cchar (bottomright), bottomright, 9, "%wborder-set");

  c_win = _scm_to_window (win);
  c_left = _scm_to_cchar (left);
  c_right = _scm_to_cchar (right);
  c_top = _scm_to_cchar (top);
  c_bottom = _scm_to_cchar (bottom);
  c_topleft = _scm_to_cchar (topleft);
  c_topright = _scm_to_cchar (topright);
  c_bottomleft = _scm_to_cchar (bottomleft);
  c_bottomright = _scm_to_cchar (bottomright);

  ret = wborder_set (c_win, c_left, c_right, c_top, c_bottom, 
		     c_topleft, c_topright, c_bottomleft, c_bottomright);

  free (c_left);
  free (c_right);
  free (c_top);
  free (c_bottom);
  free (c_topleft);
  free (c_topright);
  free (c_bottomleft);
  free (c_bottomright);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Write a complex haracter to a window, and then refresh that
   window */
SCM
gucu_wecho_wchar (SCM win, SCM ch)
{
  WINDOW *c_win;
  cchar_t *c_ch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wecho-wchar");
  SCM_ASSERT (_scm_is_cchar (ch), ch, SCM_ARG2, "%wecho-wchar");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_cchar (ch);
  
  ret = wecho_wchar (c_win, c_ch);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;

}

/* Draw an hline of N complex characters */
SCM
gucu_whline_set (SCM win, SCM ch, SCM n)
{
  WINDOW *c_win;
  cchar_t *c_ch;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%whline-set");
  SCM_ASSERT (_scm_is_cchar (ch), ch, SCM_ARG2, "%whline-set");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%whline-set");
  
  c_win = _scm_to_window (win);
  c_ch = _scm_to_cchar (ch);
  c_n = scm_to_int (n);

  ret = whline_set (c_win, c_ch, c_n);

  free (c_ch);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

// 1: int wins_nwstr
// 2: WINDOW *
// 3:  const wchar_t *
// 4:  int
// 5: 
// 6:  
SCM
gucu_wins_nwstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "%wins-nwstr");
	SCM_ASSERT (_scm_is_wchar_string (arg2), arg2, SCM_ARG2, "%wins-nwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "5wins-nwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wchar_string (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wins_nwstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int wins_wch
// 2: WINDOW *
// 3:  const cchar_t *
// 4: 
// 5: 
SCM
gucu_wins_wch (SCM arg1, SCM arg2)
{
  SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "%wins-wch");
  SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "%wins-wch");
  
  WINDOW *c_arg1 = _scm_to_window (arg1);
  cchar_t *c_arg2 = _scm_to_cchar (arg2);
  
  int ret = wins_wch (c_arg1, c_arg2);
  SCM s_ret = scm_from_int (ret);
  
  free (c_arg2);
  
  return s_ret;
}

/* Draw an vline of N complex characters */
SCM
gucu_wvline_set (SCM win, SCM ch, SCM n)
{
  WINDOW *c_win;
  cchar_t *c_ch;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wvline-set");
  SCM_ASSERT (_scm_is_cchar (ch), ch, SCM_ARG2, "%wvline-set");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%wvline-set");
  
  c_win = _scm_to_window (win);
  c_ch = _scm_to_cchar (ch);
  c_n = scm_to_int (n);

  ret = wvline_set (c_win, c_ch, c_n);

  free (c_ch);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

void 
gucu_cursw_init_function ()
{
	scm_c_define_gsubr ("key-name", 1, 0, 0, gucu_key_name);
	scm_c_define_gsubr ("term-attrs", 0, 0, 0, gucu_term_attrs);
	scm_c_define_gsubr ("unget-wch", 1, 0, 0, gucu_unget_wch);
	scm_c_define_gsubr ("%waddnwstr", 3, 0, 0, gucu_waddnwstr);
	scm_c_define_gsubr ("%wadd-wch", 2, 0, 0, gucu_wadd_wch);
	scm_c_define_gsubr ("%wadd-wchnstr", 3, 0, 0, gucu_wadd_wchnstr);
	scm_c_define_gsubr ("%wbkgrnd", 2, 0, 0, gucu_wbkgrnd);
	scm_c_define_gsubr ("%wbkgrndset", 2, 0, 0, gucu_wbkgrndset);
	scm_c_define_gsubr ("%wborder-set", 9, 0, 0, gucu_wborder_set);
	scm_c_define_gsubr ("%wecho-wchar", 2, 0, 0, gucu_wecho_wchar);
	scm_c_define_gsubr ("%whline-set", 3, 0, 0, gucu_whline_set);
	scm_c_define_gsubr ("%wins-nwstr", 3, 0, 0, gucu_wins_nwstr);
	scm_c_define_gsubr ("%wins-wch", 2, 0, 0, gucu_wins_wch);
	scm_c_define_gsubr ("%wvline-set", 3, 0, 0, gucu_wvline_set);
}
