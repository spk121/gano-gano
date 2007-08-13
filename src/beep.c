// beep.c -- guile wrapper for curses bel and screen flash routines

// $Id: beep.c,v 1.1 2007/08/13 13:58:54 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "beep.h"
#include "core.h"
#include "defines.h"

SCM
gnc_beep ()
{
  return _gnc_is_ok (beep ());
}

SCM
gnc_flash ()
{
  return _gnc_is_ok (flash ());
}

void
gnc_init_beep ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("beep", 0, 0, 0, gnc_beep);
  scm_c_define_gsubr ("flash", 0, 0, 0, gnc_flash);
}
