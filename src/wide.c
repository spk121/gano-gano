// core.c -- main initialization of ncurses wrapper library and helper
// functions for wide characters

// $Id: wide.c,v 1.1 2007/08/12 23:52:44 spike_gran Exp $

#include <curses.h>
#include <stdio.h>
#include <stdlib.h>

#include "core.h"
#include "defines.h"
#include "wide.h"

#include "add_wch.h"

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

  _gnc_init_add_wch ();
}



// Ncurses represents some complex characters as the struct cchar_t.

// #define CCHARW_MAX      5
// typedef struct
// {
//     attr_t      attr;
//     wchar_t     chars[CCHARW_MAX];
// }

// Without the ability to test this, I'm going to be oddly literal
// about this.  and require that the SCM representation be a pair
// (attr . '(list of chars))

// Hopefully we can clean this up on the scheme side with some helper
// functions


int
_gnc_is_cchar (SCM s)
{
  SCM car, cdr, element;
  int i, len;
  
  if !(scm_is_pair (s))
    return 0;

  car = scm_car (s);
  cdr = scm_cdr (s);

  if !(scm_is_integer (car))
    return 0;

  if !(scm_is_true (scm_list_p (cdr)))
    return 0;

  len = scm_to_int (scm_length (cdr));
      
  if (len == 0 || len >= CCHARW_MAX)
    return 0;

  for (i = 0; i < len; i++)
    {
      element = scm_list_ref (cdr, scm_from_int (i));
      if (!scm_is_integer (element))
	return 0;
    }

  return 1;
}

// This presumes that s has alredy been validated.  C will have to be
// freed by the calling functions.
cchar_t *
_gnc_to_cchar (SCM s)
{
  SCM car, cdr, element;
  int len, i;
  cchar_t *c;

  c = (cchar_t *) scm_malloc (cchar_t);

  car = scm_car (s);

  c->attr = scm_to_int (car);

  cdr = scm_cdr (s);
  len = scm_to_int (scm_length (cdr));
  for (i = 0; i < len; i ++)
    {
      element = scm_list_ref (cdr, scm_from_int (i));
      c->chars[i] = scm_to_integer (element);
    }
  c->chars[len] = 0;

  return c;
}
