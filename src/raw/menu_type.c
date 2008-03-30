#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <libguile.h>
#include <menu.h>
#include <stdio.h>
#include <string.h>

#include <config.h>

#include "type.h"
#include "menu_type.h"

scm_t_bits menu_tag;

SCM equalp_menu (SCM x1, SCM x2);
size_t gc_free_menu (SCM x);
SCM mark_menu (SCM x);
int print_menu (SCM x, SCM port, scm_print_state *pstate);


// menu -- in C, a MENU *.  In Scheme, a smob that contains the pointer

int 
_scm_is_menu (SCM x)
{
  return SCM_SMOB_PREDICATE (menu_tag, x);
}

MENU *
_scm_to_menu (SCM x)
{
  return (MENU *) SCM_SMOB_DATA (x);
}

SCM
_scm_from_menu (MENU *x)
{
  SCM s_menu;

  assert (x != NULL);

  SCM_NEWSMOB (s_menu, menu_tag, x);

  assert (x == (MENU *) SCM_SMOB_DATA (s_menu));

  if (0) 
    {
      fprintf (stderr, "Making smob from menu of height %d, width %d\n",
	       x->height, x->width);
    }

  return (s_menu);
}

// Menus are equal if they point to the same C structure
SCM
equalp_menu (SCM x1, SCM x2)
{
  MENU *menu1 = (MENU *) SCM_SMOB_DATA (x1);
  MENU *menu2 = (MENU *) SCM_SMOB_DATA (x2);

  if ((menu1 == NULL) || (menu2 == NULL))
    return SCM_BOOL_F;
  else if ((menu1 != menu2))
    return SCM_BOOL_F;
  else
    return SCM_BOOL_T;
}

SCM
mark_menu (SCM x)
{
  // No SCMs in the menu type: nothing to do here.
  return (SCM_BOOL_F);
}

/* The name is gc_free_menu because the curses primitive that frees
   memory is called free_menu. */
size_t
gc_free_menu (SCM menu)
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "gc-free-menu");

  MENU *m = _scm_to_menu (menu);
  ITEM **ip;
  int count;
  
  if (m != 0) 
    {
      delwin(menu_sub(m));
      delwin(menu_win(m));
      
      ip = menu_items(m);
      count = item_count(m);
      
      free_menu(m);
    }

  return 0;
}

int
print_menu (SCM x, SCM port, scm_print_state *pstate)
{
  MENU *win = (MENU *) SCM_SMOB_DATA (x);
  char *str;

  assert (win != NULL);

  if (0)
    {
      fprintf (stderr, "Printing smob menu of height %d, width %d\n",
	       win->height, win->width);
      fflush (stderr);
    }

  scm_puts ("#<menu ", port);

  if (asprintf (&str, "%p", win) < 0)
    scm_puts ("???", port);
  else
    scm_puts (str, port);

  scm_puts (">", port);
  
  // non-zero means success 
  return 1;
}

SCM
gucu_is_menu_p (SCM x)
{
  return scm_from_bool (_scm_is_menu (x));
}

void 
gucu_menu_init_type ()
{
  menu_tag = scm_make_smob_type ("menu", sizeof (MENU *));
  scm_set_smob_mark (menu_tag, mark_menu);
  scm_set_smob_free (menu_tag, gc_free_menu);
  scm_set_smob_print (menu_tag, print_menu);
  scm_set_smob_equalp (menu_tag, equalp_menu);
  scm_c_define_gsubr ("menu?", 1, 0, 0, gucu_is_menu_p);
}
