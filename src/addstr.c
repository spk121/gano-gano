// addstr.c -- wrap curses functions to write strings

// $Id: addstr.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <libguile.h>
#include <stdio.h>


#include "addstr.h"
#include "core.h"
#include "defines.h"

#include "type_window.h"

// Write the characters of the string to a given window.
SCM
gnc_addstr (SCM str)
{
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG1, "addstr");

  char *c_str = scm_to_locale_string (str);
  int ret = addstr (c_str);

  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_addnstr (SCM str, SCM n)
{
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG1, "addnstr");
  SCM_ASSERT (scm_is_number (n), n, SCM_ARG2, "addnstr");
  
  char *c_str = scm_to_locale_string (str);
  int ret = addnstr (c_str, scm_to_int (n));
  
  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_waddstr (SCM win, SCM str)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "waddstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG2, "waddstr");

  char *c_str = scm_to_locale_string (str);
  int ret = waddstr (_gnc_window_data (win), c_str);
  
  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_waddnstr (SCM win, SCM str, SCM n)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "waddnstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG2, "waddnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "waddnstr");

  char *c_str = scm_to_locale_string (str);
  int ret = waddnstr (_gnc_window_data (win), c_str, scm_to_int (n));
  
  free (c_str);

  return _gnc_is_ok (ret);
}


SCM
gnc_mvaddstr (SCM y, SCM x, SCM str)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvaddstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvaddstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG3, "mvaddstr");

  char *c_str = scm_to_locale_string (str);
  int ret = mvaddstr (scm_to_int (y), scm_to_int (x), c_str);

  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_mvaddnstr (SCM y, SCM x, SCM str, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvaddnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvaddnstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG3, "mvaddnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvaddnstr");

  char *c_str = scm_to_locale_string (str);
  int ret = mvaddnstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));

  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_mvwaddstr (SCM win, SCM y, SCM x, SCM str)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "mvwaddstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwaddstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwaddstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG4, "mvwaddstr");

  char *c_str = scm_to_locale_string (str);
  int ret = mvwaddstr (_gnc_window_data (win),
		       scm_to_int (y),
		       scm_to_int (x),
		       c_str);
  free (c_str);

  return _gnc_is_ok (ret);
}

SCM
gnc_mvwaddnstr (SCM win, SCM y, SCM x, SCM str, SCM n)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "mvwaddnstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwaddnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwaddnstr");
  SCM_ASSERT (scm_is_string (str), str, SCM_ARG4, "mvwaddnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG5, "mvwaddnstr");

  char *c_str = scm_to_locale_string (str);
  int ret = mvwaddnstr (_gnc_window_data (win),
			scm_to_int (y),
			scm_to_int (x),
			c_str,
			scm_to_int (n));
  free (c_str);

  return _gnc_is_ok (ret);
}

void
_gnc_init_addstr ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("addstr", 1, 0, 0, gnc_addstr);
  scm_c_define_gsubr ("addnstr", 2, 0, 0, gnc_addnstr);
  scm_c_define_gsubr ("waddstr", 2, 0, 0, gnc_waddstr);
  scm_c_define_gsubr ("waddnstr", 3, 0, 0, gnc_waddnstr);
  scm_c_define_gsubr ("mvaddstr", 3, 0, 0, gnc_mvaddstr);
  scm_c_define_gsubr ("mvaddnstr", 4, 0, 0, gnc_mvaddnstr);
  scm_c_define_gsubr ("mvwaddstr", 4, 0, 0, gnc_mvwaddstr);
  scm_c_define_gsubr ("mvwaddnstr", 5, 0, 0, gnc_mvwaddnstr);
}



