// terminfo.c -- wrap curses functions that interface with the terminfo database

// $Id: terminfo.c,v 1.1 2007/08/17 14:27:56 spike_gran Exp $


#include <libguile.h>
#include <ncurses/term.h>
#include <ncurses.h>

#include "core.h"
#include "defines.h"
#include "terminfo.h"

// Define the variables for a terminal without initialize its secreen
SCM
gnc_setupterm (SCM term, SCM out_fdes)
{
  SCM_ASSERT (scm_is_string (term), term, SCM_ARG1, "setupterm");
  SCM_ASSERT (scm_is_integer (out_fdes), out_fdes, SCM_ARG2, "setupterm");
  
  int errret;
  int ret;
  char *str;
  
  str = scm_to_locale_string (term);
  ret = setupterm (str, scm_to_int (out_fdes), &errret);
  free (str);
  
  if (ret == OK)
    return SCM_BOOL_T;
  else
    return scm_from_int (errret);
}

// Export functions to guile
void
gnc_init_terminfo ()
{
  scm_c_define_gsubr ("setupterm", 2, 0, 0, gnc_setupterm);
}
    
