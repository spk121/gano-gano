// addch.c -- wrap curses functions to add characters to the curses window

// $Id: addch.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "addch.h"
#include "core.h"
#include "defines.h"

#include "type_window.h"

// Put the character ch into the standard window and advance the
// cursor.  Return #t is successful.
SCM
gnc_addch (SCM ch)
{
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG1, "addch");

  chtype c_char = _gnc_to_chtype (ch);
  return _gnc_is_ok (addch (c_char));
}

// Put the character ch into a specified window, and advance the
// cursor.  Return #t if successful.
SCM
gnc_waddch (SCM win, SCM ch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "waddch");
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG1, "addch");

  chtype c_char = _gnc_to_chtype (ch);

  return _gnc_is_ok (waddch (_gnc_window_data (win), c_char));
}

// Move the cursor to a specified position in the standard window, put
// ch into the standard window, and then advance the cursor.  Return
// #t if successful.
SCM
gnc_mvaddch (SCM y, SCM x, SCM ch)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvaddch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvaddch");
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG3, "mvaddch");

  chtype c_char = _gnc_to_chtype (ch);
  return _gnc_is_ok (mvaddch (scm_to_int (y),
			      scm_to_int (x),
			      c_char));
}

// Move the cursor to a specified position in a given window; put ch
// into that window, and advance the cursor.  Return #t if successful.
SCM
gnc_mvwaddch (SCM win, SCM y, SCM x, SCM ch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "mvwaddch");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwaddch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwaddch");
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG4, "mvwaddch");

  chtype c_char = _gnc_to_chtype (ch);
  return _gnc_is_ok (mvwaddch (_gnc_window_data (win), 
			       scm_to_int (y),
			       scm_to_int (x),
			       c_char));
}

// Add a char and then refresh the screen for that char.
SCM
gnc_echochar (SCM ch)
{
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG1, "echochar");

  chtype c_char = _gnc_to_chtype (ch);
  return _gnc_is_ok (echochar (c_char));
}

// Add a char for a given window, and, then, refresh the screen.
SCM
gnc_wechochar (SCM win, SCM ch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wechochar");
  SCM_ASSERT (_gnc_is_chtype (ch), ch, SCM_ARG2, "wechochar");

  chtype c_char = _gnc_to_chtype (ch);
  return _gnc_is_ok (wechochar (_gnc_window_data (win), 
				c_char));
}



// Register these functions as scheme functions
void
_gnc_init_addch ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("addch", 1, 0, 0, gnc_addch);
  scm_c_define_gsubr ("waddch", 2, 0, 0, gnc_waddch);
  scm_c_define_gsubr ("mvaddch", 3, 0, 0, gnc_mvaddch);
  scm_c_define_gsubr ("mvwaddch", 4, 0, 0, gnc_mvwaddch);
  scm_c_define_gsubr ("echochar", 1, 0, 0, gnc_echochar);
  scm_c_define_gsubr ("wechochar", 2, 0, 0, gnc_wechochar);

}
