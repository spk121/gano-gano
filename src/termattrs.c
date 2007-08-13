// termattrs.c -- guile wrapper for ncurses functions the query the environment

// $Id: termattrs.c,v 1.1 2007/08/13 13:58:54 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "defines.h"
#include "termattrs.h"

// Returns the baudrate of the terminal.
SCM
gnc_baudrate ()
{
  return scm_from_int (baudrate ());
}


void
gnc_init_termattrs ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("baudrate", 0, 0, 0, gnc_baudrate);
}
