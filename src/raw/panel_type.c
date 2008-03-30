#define _GNU_SOURCE
#include <assert.h>
#include <curses.h>
#include <libguile.h>
#include <panel.h>
#include <stdio.h>
#include <string.h>

#include <config.h>

#include "type.h"
#include "panel_type.h"

static scm_t_bits panel_tag;

SCM equalp_panel (SCM x1, SCM x2);
size_t gc_free_panel (SCM x);
SCM mark_panel (SCM x);
int print_panel (SCM x, SCM port, scm_print_state *pstate);


// panel -- in C, a PANEL.  In Scheme, a smob that contains the pointer

int 
_scm_is_panel (SCM x)
{
  return SCM_SMOB_PREDICATE (panel_tag, x);
}

PANEL *
_scm_to_panel (SCM x)
{
  return (PANEL *) SCM_SMOB_DATA (x);
}

SCM
_scm_from_panel (PANEL *x)
{
  SCM s_panel;

  assert (x != NULL);

  SCM_NEWSMOB (s_panel, panel_tag, x);

  assert (x == (PANEL *) SCM_SMOB_DATA (s_panel));

  if (0) 
    {
      fprintf (stderr, "Making smob from panel based on WINDOW * %p\n",
	       x->win);
    }

  return (s_panel);
}

// Panels are equal if they point to the same C structure
SCM
equalp_panel (SCM x1, SCM x2)
{
  PANEL *panel1 = (PANEL *) SCM_SMOB_DATA (x1);
  PANEL *panel2 = (PANEL *) SCM_SMOB_DATA (x2);

  if ((panel1 == NULL) || (panel2 == NULL))
    return SCM_BOOL_F;
  else if ((panel1 != panel2))
    return SCM_BOOL_F;
  else
    return SCM_BOOL_T;
}

SCM
mark_panel (SCM x)
{
  // No SCMs in the panel type: nothing to do here.
  return (SCM_BOOL_F);
}

/* The name is free_panel.  The curses primitive that frees memory is
   called del_panel. Note that del_panel doesn't free the underlying
   window. */
size_t
free_panel (SCM panel)
{
  SCM_ASSERT (_scm_is_panel (panel), panel, SCM_ARG1, "free-panel");

  PANEL *m = _scm_to_panel (panel);

  assert (m != NULL);

  del_panel (m);

  return 0;
}

int
print_panel (SCM x, SCM port, scm_print_state *pstate)
{
  PANEL *pnl = (PANEL *) SCM_SMOB_DATA (x);
  char *str;

  assert (pnl != NULL);

  if (0)
    {
      fprintf (stderr, "Printing smob panel based on window %p\n",
	       pnl->win);
      fflush (stderr);
    }

  scm_puts ("#<panel ", port);

  if (asprintf (&str, "%p", pnl) < 0)
    scm_puts ("???", port);
  else
    scm_puts (str, port);

  scm_puts (">", port);
  
  // non-zero means success 
  return 1;
}

SCM
gucu_is_panel_p (SCM x)
{
  return scm_from_bool (_scm_is_panel (x));
}

void 
gucu_panel_init_type ()
{
  panel_tag = scm_make_smob_type ("panel", sizeof (PANEL *));
  scm_set_smob_mark (panel_tag, mark_panel);
  scm_set_smob_free (panel_tag, gc_free_panel);
  scm_set_smob_print (panel_tag, print_panel);
  scm_set_smob_equalp (panel_tag, equalp_panel);
  scm_c_define_gsubr ("panel?", 1, 0, 0, gucu_is_panel_p);
}
