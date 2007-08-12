#define _GNU_SOURCE

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "defines.h"
#include "type_window.h"

scm_t_bits window_tag;

// Local Function Declarations
static SCM equalp_window (SCM window_smob_1, SCM window_smob_2);
static size_t free_window (SCM window_smob);
static SCM mark_window (SCM window_smob);
static int print_window (SCM window_smob, SCM port, scm_print_state *pstate);


// Return #t if two smobs point to the same window data
SCM
equalp_window (SCM window_smob_1, SCM window_smob_2)
{
  WINDOW *win1 = (WINDOW *) SCM_SMOB_DATA (window_smob_1);
  WINDOW *win2 = (WINDOW *) SCM_SMOB_DATA (window_smob_2);

  if ((win1 == NULL) || (win2 == NULL))
    return SCM_BOOL_F;
  else if ((win1 != win2))
    return SCM_BOOL_F;
  else
    return SCM_BOOL_T;
}
  
// Freeing windows is a job that only the ncurses library should do
static size_t
free_window (SCM window_smob)
{
  // It is ncurses' job to free pointers 
  return 0;
}

// Since the window smob has no guile data, there is nothing to mark.
// Returns #f always.
SCM
mark_window (SCM window_smob)
{
  return SCM_BOOL_F;
}

// Prints the window type.  Always returns 1 for success.
static int
print_window (SCM window_smob, SCM port, scm_print_state *pstate)
{
  WINDOW *win = (WINDOW *) SCM_SMOB_DATA (window_smob);
  char *str;

  scm_puts ("#<ncurses-window ", port);
  if (asprintf (&str, "%p", win) < 0)
    scm_puts ("???", port);
  else 
    scm_puts (str, port);
  
  scm_puts(">", port);
  
  // non-zero means success 
  return 1;
}


// Register this type as a scheme type
void
_gnc_init_type_window (void)
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  window_tag = scm_make_smob_type ("ncurses-window", sizeof (WINDOW *));
  scm_set_smob_equalp (window_tag, equalp_window);
  scm_set_smob_free (window_tag, free_window);
  scm_set_smob_mark (window_tag, mark_window);
  scm_set_smob_print (window_tag, print_window);
}

// A convenience function to extract window data
WINDOW *
_gnc_window_data (SCM win)
{
  scm_assert_smob_type (window_tag, win);
  
  return (WINDOW *) SCM_SMOB_DATA (win);
}
