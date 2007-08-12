// type_screen.c -- creates a guile type for curses screens

// $Id: type_screen.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $
#define _GNU_SOURCE

#include <curses.h>
#include <libguile.h>
#include <stdio.h>
#include <stdlib.h>

#include "defines.h"
#include "type_screen.h"

scm_t_bits screen_tag;

// Local Function Declarations
static SCM equalp_screen (SCM screen_smob_1, SCM screen_smob_2);
static size_t free_screen (SCM screen_smob);
static SCM mark_screen (SCM screen_smob);
static int print_screen (SCM screen_smob, SCM port, scm_print_state *pstate);

// Returns #t if two smobs point to the same screen data
SCM
equalp_screen (SCM screen_smob_1, SCM screen_smob_2)
{
  SCREEN *sp1 = (SCREEN *) SCM_SMOB_DATA (screen_smob_1);
  SCREEN *sp2 = (SCREEN *) SCM_SMOB_DATA (screen_smob_2);

  if ((sp1 == NULL) || (sp2 == NULL))
    return SCM_BOOL_F;
  else if ((sp1 != sp2))
    return SCM_BOOL_F;
  else
    return SCM_BOOL_T;
}
  
// Frees the non-garbage-collectable part of the screen smob
static size_t
free_screen (SCM screen_smob)
{
  SCREEN *sp = (SCREEN *) SCM_SMOB_DATA (screen_smob);

  /* The SCREEN data may already have been freed by an explicit call
     to delscreen.  If so, the pointer is already null.  If not,
     delscreen is called here. */

  if (sp != (SCREEN *) NULL)
    {
      delscreen (sp);
      sp = NULL;
    }
      
  return 0;
}

// Since the screen smob has no guile data, there is nothing to mark.
// Returns #f always.
SCM
mark_screen (SCM screen_smob)
{
  return SCM_BOOL_F;
}

// Prints the screen type.  Always returns 1 for success
static int
print_screen (SCM screen_smob, SCM port, scm_print_state *pstate)
{
  SCREEN *sp = (SCREEN *) SCM_SMOB_DATA (screen_smob);
  char *str;

  scm_puts ("#<ncurses-screen ", port);
  if (asprintf (&str, "%p", sp) < 0)
    scm_puts ("???", port);
  else 
    scm_puts (str, port);
  
  scm_puts(">", port);
  
  /* non-zero means success */
  return 1;
}

// Register this type as a scheme type
void
_gnc_init_type_screen (void)
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  screen_tag = scm_make_smob_type ("ncurses-screen", sizeof (SCREEN *));
  scm_set_smob_equalp (screen_tag, equalp_screen);
  scm_set_smob_free (screen_tag, free_screen);
  scm_set_smob_mark (screen_tag, mark_screen);
  scm_set_smob_print (screen_tag, print_screen);
}
