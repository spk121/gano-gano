// refresh.c -- wrap curses functions to refresh windows and lines

// $Id: refresh.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "core.h"
#include "defines.h"
#include "refresh.h"

#include "type_window.h"

// Refreshes the standard screen.  Returns #t if successful.
SCM
gnc_refresh ()
{
  return _gnc_is_ok (refresh ());
}

// Refreshes the specified window.  Returns #t if successful.
SCM
gnc_wrefresh (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win),
	      win, SCM_ARG1, "wrefresh");

  int ret = wrefresh (_gnc_window_data (win));
  return _gnc_is_ok (ret);
}

// Copies the named window the the virtual screen.  Should return
// #t always.
SCM
gnc_wnoutrefresh (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win),
	      win, SCM_ARG1, "wnoutrefresh");

  int ret = wrefresh (_gnc_window_data (win));
  return _gnc_is_ok (ret);
}

// Compares the virtual screen to the actual and does an update.
SCM
gnc_doupdate ()
{
  return _gnc_is_ok (doupdate ());
}

// Inform curses that the screen is corrupt.
SCM
gnc_redrawwin (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win),
	      win, SCM_ARG1, "wnoutrefresh");

  int ret = redrawwin (_gnc_window_data (win));
  return _gnc_is_ok (ret);
}

// Inform curses that part of the screen is corrupt betwen beg_line
// and beg_line + num_lines.
SCM
gnc_wredrawln (SCM win, SCM beg_line, SCM num_lines)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win),
	      win, SCM_ARG1, "wredrawln");
  SCM_ASSERT (scm_is_number (beg_line), beg_line, SCM_ARG2, "wredrawln");
  SCM_ASSERT (scm_is_number (num_lines), num_lines, SCM_ARG3, "wredrawln");

  int ret = wredrawln (_gnc_window_data (win), 
		       scm_to_int (beg_line),
		       scm_to_int (num_lines));
  return _gnc_is_ok (ret);
}


void
_gnc_init_refresh ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("refresh", 0, 0, 0, gnc_refresh);
  scm_c_define_gsubr ("wrefresh", 1, 0, 0, gnc_wrefresh);
  scm_c_define_gsubr ("wnoutrefresh", 1, 0, 0, gnc_wnoutrefresh);
  scm_c_define_gsubr ("doupdate", 0, 0, 0, gnc_doupdate);
  scm_c_define_gsubr ("redrawwin", 1, 0, 0, gnc_redrawwin);
  scm_c_define_gsubr ("wredrawln", 3, 0, 0, gnc_wredrawln);
}
