// core.c -- main initialization of ncurses wrapper library and helper
// functions

// $Id: core.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <stdio.h>
#include <stdlib.h>

#include "core.h"
#include "defines.h"

#include "addch.h"
#include "addstr.h"
#include "attr.h"
#include "color.h"
#include "default_colors.h"
#include "getch.h"
#include "initscr.h"
#include "inopts.h"
#include "kernel.h"
#include "move.h"
#include "refresh.h"

#include "type_screen.h"
#include "type_window.h"

#ifdef TESTBED
#include "testbed.h"
#endif /* TESTBED */ 

void
gnc_init_core ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  _gnc_init_type_screen ();
  _gnc_init_type_window ();

  _gnc_init_addch ();
  _gnc_init_addstr ();
  _gnc_init_attr ();
  _gnc_init_color ();
  _gnc_init_default_colors ();
  _gnc_init_getch ();
  _gnc_init_initscr ();
  _gnc_init_inopts ();
  _gnc_init_kernel ();
  _gnc_init_move ();
  _gnc_init_refresh ();

  if (TESTBED)
    _gnc_init_testbed ();
}

// Convert curses OK/ERR to scheme #t/#f
SCM 
_gnc_is_ok (int status)
{
  if (status == OK)
    return SCM_BOOL_T;
  else
    return SCM_BOOL_F;
}


// Convert the various guile types to a curses chtype
int 
_gnc_is_chtype (SCM c)
{
  if (scm_is_true (scm_char_p (c)))
    return 1;
  else if (scm_is_number (c))
    return 1;
  else if (scm_is_string (c) && scm_c_string_length (c) == 1)
    return 1;
  else 
    return 0;
}

// Convert the various guile types to a curses chtype
chtype 
_gnc_to_chtype (SCM c)
{
  // A pointer to the function that converts SCM numbers to 
  // chtypes.
  chtype (*scm_to_chtype) (SCM x);

  if (sizeof(chtype) == sizeof(unsigned))
    scm_to_chtype = scm_to_uint;
  else if (sizeof (chtype) == sizeof (unsigned long))
    scm_to_chtype = scm_to_ulong;
  else
    abort ();

  if (scm_is_true (scm_char_p (c)))
    return (scm_to_chtype (scm_char_to_integer (c)));
  else if (scm_is_number (c))
    return (scm_to_chtype (c));
  else if (scm_is_string (c) && scm_c_string_length (c) == 1)
    {
      SCM first_char = scm_c_string_ref (c, 0);
      return (scm_to_chtype (scm_char_to_integer (first_char)));
    }
  else
    {
      scm_syserror ("Cannot convert this to a chtype.");
      
      // Unreachable
      return 0;
    }
}

int
_gnc_is_attr (SCM x)
{
  return scm_is_integer (x);
}

attr_t
_gnc_to_attr (SCM x)
{
  if (sizeof(attr_t) == sizeof(unsigned))
    return scm_to_uint (x);
  else if (sizeof (attr_t) == sizeof (unsigned long))
    return scm_to_ulong (x);
  else
    abort ();
}  

SCM
_gnc_from_attr (attr_t x)
{
  if (sizeof(attr_t) == sizeof(unsigned))
    return scm_from_uint (x);
  else if (sizeof (attr_t) == sizeof (unsigned long))
    return scm_from_ulong (x);
  else
    abort ();
}  

