// move.c -- wrap curses functions to move the cursor in the curses window

// $Id: move.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "core.h"
#include "defines.h"
#include "move.h"

#include "type_window.h"

// Move the cursor to the given location in the standard window.
// Returns #t if successful.
SCM
gnc_move (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "move");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "move");

  return _gnc_is_ok (move (scm_to_int (y),
			   scm_to_int (x)));
}

// Move the cursor to the given location in the window.
// Returns #t if successful.
SCM
gnc_wmove (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wmove");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "move");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "move");

  return _gnc_is_ok (wmove (_gnc_window_data (win), 
			    scm_to_int (y),
			    scm_to_int (x)));
}

// Register these functions as scheme functions
void
_gnc_init_move ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("move", 2, 0, 0, gnc_move);
  scm_c_define_gsubr ("wmove", 3, 0, 0, gnc_wmove);
}
