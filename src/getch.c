// getch.c -- wrap curses function to get characters from the keyboard

// $Id: getch.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "core.h"
#include "defines.h"
#include "getch.h"

#include "type_window.h"

// Local Function Definitions
static SCM int_or_err_to_scm (int c);


static SCM
int_or_err_to_scm (int c)
{
  if (c == ERR)
    return SCM_BOOL_F;
  else
    return scm_from_int (c);
}

SCM
gnc_getch ()
{
  return int_or_err_to_scm (getch ());
}

SCM 
gnc_wgetch (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "wgetch");
  
  int c = wgetch (_gnc_window_data (win));

  return int_or_err_to_scm (c);
}

SCM
gnc_mvgetch (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvgetch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvgetch");

  int c = mvgetch (scm_to_int (y), scm_to_int (x));

  return int_or_err_to_scm (c);
}

SCM
gnc_mvwgetch (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "mvwgetch");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwgetch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwgetch");

  int c = mvwgetch (_gnc_window_data (win),
		    scm_to_int (y),
		    scm_to_int (x));

  return int_or_err_to_scm (c);
}

SCM
gnc_ungetch (SCM ch)
{
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG1, "ungetch");
  
  return _gnc_is_ok (ungetch (_gnc_to_chtype (ch)));
}

SCM
gnc_has_key (SCM ch)
{
  SCM_ASSERT (scm_is_integer (ch), ch, SCM_ARG1, "has-key");

  return scm_from_bool (has_key (scm_to_int (ch)));
}

void
_gnc_init_getch ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("getch", 0, 0, 0, gnc_getch);
  scm_c_define_gsubr ("wgetch", 1, 0, 0, gnc_wgetch);
  scm_c_define_gsubr ("mvgetch", 2, 0, 0, gnc_mvgetch);
  scm_c_define_gsubr ("mvwgetch", 3, 0, 0, gnc_mvwgetch);
  scm_c_define_gsubr ("ungetch", 1, 0, 0, gnc_ungetch);
  scm_c_define_gsubr ("has-key", 1, 0, 0, gnc_has_key);
}
