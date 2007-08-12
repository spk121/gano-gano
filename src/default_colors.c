// default_colors.c -- wrap curses functions for using terminal's
// default colors

// $Id: default_colors.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "core.h"
#include "default_colors.h"

// Assign this terminal's default foreground and background colors to
// color number -1.  Return #t if this assignement was supported on
// this terminal. .
SCM
gnc_use_default_colors ()
{
  return _gnc_is_ok (use_default_colors ());
}

// Sets the colors for color pair zero, the default color pair.
// Return #t if this assignment was possible on this termina.
SCM
gnc_assume_default_colors (SCM fg, SCM bg)
{
  SCM_ASSERT (scm_is_integer (fg), fg, SCM_ARG1, "assume-default-colors");
  SCM_ASSERT (scm_is_integer (bg), bg, SCM_ARG1, "assume-default-colors");

  return _gnc_is_ok (assume_default_colors (scm_to_int (fg),
					    scm_to_int (bg)));
}

// Register these functions as scheme functions
void
_gnc_init_default_colors ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("use-default-colors", 0, 0, 0, gnc_use_default_colors);
  scm_c_define_gsubr ("assume-default-colors", 2, 0, 0, 
		      gnc_assume_default_colors);
}
