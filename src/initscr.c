// curs_initscr.c -- Guile wrappers for the NCurses initialization 

// $Id: initscr.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $ 

#include <curses.h>
#include <libguile.h>
#include <stdio.h>
#include <stdlib.h>

#include "core.h"
#include "defines.h"
#include "type_screen.h"
#include "type_window.h"
#include "initscr.h"


// Returns the standard window
SCM
gnc_stdscr ()
{
  SCM s_win;

  SCM_NEWSMOB (s_win, window_tag, stdscr);
  return s_win;
}

// size of the screen
SCM
gnc_cols()
{
  return scm_from_int (COLS);
}

SCM
gnc_lines()
{
  return scm_from_int (LINES);
}

// Initializes the main curses screen.  Returns the window type of
// that screen
SCM
gnc_initscr ()
{
  WINDOW *win;
  SCM s_win;

  // initscr() will exit on failure
  win = initscr();
  SCM_NEWSMOB (s_win, window_tag, win);
  return s_win;
}

// Prepares the exit or escape from curses.  Returns #t/#f on
// success/failure.
SCM
gnc_endwin ()
{
  int ret;

  ret = endwin ();
  return _gnc_is_ok (ret);
}

// Returns #t if gnc_endwin has been called.  Otherwise #f.
SCM
gnc_isendwin ()
{
  bool ret;
  
  ret = isendwin ();
  return _gnc_is_ok (ret);
}


// The screen *new* becomes the new screen.  The previous screen is
// returned.
SCM
gnc_set_term (SCM new)
{
  SCREEN* sp;
  SCREEN* ret;
  SCM s_ret;

  SCM_ASSERT (SCM_SMOB_PREDICATE (screen_tag, new),
	      new, SCM_ARG1, "set-term");


  sp = (SCREEN *) SCM_SMOB_DATA (new);

  if (sp == NULL)
    abort ();

  ret = set_term (sp);

  SCM_NEWSMOB (s_ret, screen_tag, sp);
  return s_ret;
}


// Frees the storage of a screen type.  After gnc_endwin has been
// called for a given screen, gnc_delscreen can be called to free
// storage if it is no longer needed.
SCM
gnc_delscreen (SCM screen_smob)
{
  SCREEN* sp;

  SCM_ASSERT (SCM_SMOB_PREDICATE (screen_tag, screen_smob),
	      screen_smob, SCM_ARG1, "delscreen");

  sp = (SCREEN *) SCM_SMOB_DATA (screen_smob);
  
  if (sp == NULL)
    scm_syserror ("Tried to delete an already freed screen");

  delscreen (sp);
  
  return SCM_UNSPECIFIED;
}


// Register these functions as scheme functions.
void 
_gnc_init_initscr ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  // Curses Globals
  scm_c_define_gsubr ("stdscr", 0, 0, 0, gnc_stdscr);
  scm_c_define_gsubr ("cols", 0, 0, 0, gnc_cols);
  scm_c_define_gsubr ("lines", 0, 0, 0, gnc_lines);

  // Functions
  scm_c_define_gsubr ("initscr", 0, 0, 0, gnc_initscr);
  scm_c_define_gsubr ("endwin", 0, 0, 0, gnc_endwin);
  scm_c_define_gsubr ("isendwin", 0, 0, 0, gnc_isendwin);
  scm_c_define_gsubr ("set-term", 1, 0, 0, gnc_set_term);
  scm_c_define_gsubr ("delscreen", 1, 0, 0, gnc_delscreen);
}

