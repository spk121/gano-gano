#define _GNU_SOURCE
#include <assert.h>
#include <curses.h>
#include <errno.h>
#include <libguile.h>
#include <stdio.h>
#include <string.h>

#include <config.h>

#include "type.h"

scm_t_bits screen_tag;
scm_t_bits window_tag;

SCM equalp_window (SCM x1, SCM x2);
size_t free_window (SCM x);
SCM mark_window (SCM x);
int print_window (SCM x, SCM port, scm_print_state *pstate);

int print_screen (SCM x, SCM port, scm_print_state *pstate);

// attr -- character attributes, bit flags packed into an unsigned:
// probably uint32

int
_scm_is_attr (SCM x)
{
  return scm_is_integer (x);
}

attr_t
_scm_to_attr (SCM x)
{
  if (SIZEOF_INT == SIZEOF_ATTR_T)
    return (attr_t) scm_to_uint (x);
  else if (SIZEOF_LONG == SIZEOF_ATTR_T)
    return (attr_t) scm_to_ulong (x);
  else
    abort ();
}

SCM
_scm_from_attr (attr_t x)
{
  if (SIZEOF_INT == SIZEOF_ATTR_T)
    return scm_from_uint (x);
  else if (SIZEOF_LONG == SIZEOF_ATTR_T)
    return scm_from_ulong (x);
  else
    abort ();
}



// chstring -- in C, a zero-terminated array of characters and their
// renditions.  In Scheme, a list of integers.

int
_scm_is_chstring (SCM x)
{
  int i;
  int err = 0;			
  SCM member;			

  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      for (i=0; i<len; i++)
	{
	  member = scm_list_ref (x, scm_from_int (i));
	  if (!_scm_is_chtype (member))
	    err ++;
	}
    }
  else
    err ++;

  if (err > 0)
    return 0;
  else
    return 1;
}
	  
// Caller must free returned array
chtype *
_scm_to_chstring (SCM x)
{
  int i;
  chtype *str;
  SCM member;

  int len = scm_to_int (scm_length (x));

  str = (chtype *) scm_malloc ((len + 1)* sizeof (chtype));
  for (i=0; i<len; i++)
    {
      member = scm_list_ref (x, scm_from_int (i));
      str[i] = _scm_to_chtype (member);
    }
  str[len] = (chtype) 0;

  return str;
}

SCM
_scm_from_chstring (chtype *x)
{
  int i;
  SCM element;
  SCM element_list;
  SCM total_list = SCM_EOL;

  assert (x != NULL);

  /* FIXME: possible infinite loop if X is junk */
  i = 0;
  while (x[i] != 0) 
    {
      element = _scm_from_chtype (x[i]);
      element_list = scm_list_1 (element);
      total_list = scm_append (scm_list_2 (total_list, element_list));
      i ++;
    }
  return (total_list);
}

// chtype -- in C, an integer that contains a characters and its rendition.
// In Scheme, an integer.
  
int
_scm_is_chtype (SCM x)
{
  return scm_is_integer (x);
}

chtype
_scm_to_chtype (SCM x)
{
  if (SIZEOF_INT == SIZEOF_CHTYPE)
    return (chtype) scm_to_uint (x);
  else if (SIZEOF_LONG == SIZEOF_CHTYPE)
    return (chtype) scm_to_ulong (x);
  else
    abort ();
}

SCM
_scm_from_chtype (chtype x)
{
  if (SIZEOF_INT == SIZEOF_CHTYPE)
    return scm_from_uint (x);
  else if (SIZEOF_LONG == SIZEOF_CHTYPE)
    return scm_from_ulong (x);
  else
    abort ();
}

// mevent -- in C, a MEVENT.  In scheme, a list of 5 elements
int
_scm_is_mevent (SCM x)
{
  int err = 0;
  SCM member;
  int i;

  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      
      for (i = 0; i < len; i ++)
	{
	  member = scm_list_ref (x, scm_from_int (i));
	  if (!scm_is_integer (member))
	    err ++;
	}
    }
  err ++;

  if (err > 0)
    return 0;
  else
    return 1;
}

MEVENT *
_scm_to_mevent (SCM x)
{
  MEVENT *me;

  me = (MEVENT *) malloc (sizeof (MEVENT));

  me->id = scm_to_short (scm_list_ref (x, scm_from_int (0)));
  me->x = scm_to_int (scm_list_ref (x, scm_from_int (1)));
  me->y = scm_to_int (scm_list_ref (x, scm_from_int (2)));
  me->z = scm_to_int (scm_list_ref (x, scm_from_int (3)));
  me->bstate = scm_to_ulong (scm_list_ref (x, scm_from_int (4)));

  return (me);
}

SCM
_scm_from_mevent (MEVENT *me)
{
  return scm_list_5 
    ( 
     scm_from_short (me->id),
     scm_from_int (me->x),
     scm_from_int (me->y), 
     scm_from_int (me->z),
     scm_from_ulong (me->bstate)
     );
}

// screen -- in C, a SCREEN *.  In Scheme, a smob that contains that pointer.

int 
_scm_is_screen (SCM x)
{
  if (SCM_SMOB_PREDICATE (screen_tag, x))
    {
      if (SCM_SMOB_DATA (x) != 0)
	return 1;
      else
	return 0;
    }
  else
    return 0;
}

SCREEN *
_scm_to_screen (SCM x)
{
  return (SCREEN *) SCM_SMOB_DATA (x);
}

SCM
_scm_from_screen (SCREEN *x)
{
  SCM s_screen;

  assert (x != NULL);

  SCM_NEWSMOB (s_screen, screen_tag, x);
  return s_screen;
}

int
print_screen (SCM x, SCM port, scm_print_state *pstate __attribute__ ((unused)))
{
  SCREEN *screen = (SCREEN *) SCM_SMOB_DATA (x);
  char *str;


  scm_puts ("#<screen ", port);

  if (screen == NULL)
    {
      scm_puts ("(freed)", port);
    }
  else
    {
      if (asprintf (&str, "%p", screen) < 0)
	scm_puts ("???", port);
      else
	scm_puts (str, port);
    }

  scm_puts (">", port);
  
  // non-zero means success 
  return 1;
}


// voidstring -- In C, (void *)NULL.  In Scheme, doesn't matter.  This
// is because all of the (void *) arguments in the directly wrapped
// list are unused by curses.

int
_scm_is_voidstring (SCM x __attribute__ ((unused)))
{
  return 1;
}

void *
_scm_to_voidstring (SCM x __attribute__ ((unused)))
{
  return NULL;
}

SCM
_scm_from_voidstring (void *x __attribute ((unused)))
{
  return SCM_EOL;
}

// window -- in C, a WINDOW *.  In Scheme, a smob that contains the pointer

int 
_scm_is_window (SCM x)
{
  if (SCM_SMOB_PREDICATE (window_tag, x))
    {
      if (SCM_SMOB_DATA (x) != 0)
	return 1;
      else
	return 0;
    }
  else
    return 0;
  
}

WINDOW *
_scm_to_window (SCM x)
{
  return (WINDOW *) SCM_SMOB_DATA (x);
}

SCM
_scm_from_window (WINDOW *x)
{
  SCM s_win;

  assert (x != NULL);

  SCM_NEWSMOB (s_win, window_tag, x);

  assert (x == (WINDOW *) SCM_SMOB_DATA (s_win));

  if (0) 
    {
      fprintf (stderr, "Making smob from window at %d, %d\n",
	       x->_begx, x->_begy);
    }

  return (s_win);
}

// Windows are equal if they point to the same C structure
SCM
equalp_window (SCM x1, SCM x2)
{
  WINDOW *win1 = (WINDOW *) SCM_SMOB_DATA (x1);
  WINDOW *win2 = (WINDOW *) SCM_SMOB_DATA (x2);

  if ((win1 == NULL) || (win2 == NULL))
    return SCM_BOOL_F;
  else if ((win1 != win2))
    return SCM_BOOL_F;
  else
    return SCM_BOOL_T;
}

SCM
mark_window (SCM x __attribute__ ((unused)))
{
  // No SCMs in the window type: nothing to do here.
  return (SCM_BOOL_F);
}

size_t
free_window (SCM x)
{
  WINDOW *win = (WINDOW *) SCM_SMOB_DATA (x);

  /* Windows should already be null if delwin has been called on them */
  if (win != NULL)
    {
      if (win == stdscr)
	{
	  endwin ();
	  fprintf (stderr, "Freeing stdscr #<window %p>", stdscr);
	  delwin (stdscr);
	  SCM_SET_SMOB_DATA (x, NULL);
	}
      else
	{
	  /* This is going to break something */
	  delwin (win);
	  SCM_SET_SMOB_DATA (x, NULL);
	}
    }

  return 0;
}

int
print_window (SCM x, SCM port, scm_print_state *pstate __attribute__ ((unused)))
{
  WINDOW *win = (WINDOW *) SCM_SMOB_DATA (x);
  char *str;

  scm_puts ("#<window ", port);

  if (win == 0)
    scm_puts ("(freed)", port);
  else
    {
      if (asprintf (&str, "%p", win) < 0)
	scm_puts ("???", port);
      else
	scm_puts (str, port);
    }
  scm_puts (">", port);
  
  // non-zero means success 
  return 1;
}

SCM
gucu_is_window_p (SCM x)
{
  return scm_from_bool (_scm_is_window (x));
}


void 
gucu_init_type ()
{
  static int first = 1;

  if (first)
    {
      screen_tag = scm_make_smob_type ("screen", sizeof (SCREEN *));
      scm_set_smob_print (screen_tag, print_screen);
      
      window_tag = scm_make_smob_type ("window", sizeof (WINDOW *));
      scm_set_smob_mark (window_tag, mark_window);
      scm_set_smob_free (window_tag, free_window);
      scm_set_smob_print (window_tag, print_window);
      scm_set_smob_equalp (window_tag, equalp_window);
      scm_c_define_gsubr ("window?", 1, 0, 0, gucu_is_window_p);
      
      first = 0;
    }
}
