// kernel.c -- wrap low-level curses functions

// $Id: kernel.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "core.h"
#include "defines.h"
#include "kernel.h"

#include "type_window.h"

// Save the current program terminal mode for later restoration
// Always returns #t.
SCM
gnc_def_prog_mode ()
{
  return _gnc_is_ok (def_prog_mode ());
}

// Save the current shell terminal mode for later restoration. 
// Always returns #t.
SCM
gnc_def_shell_mode ()
{
  return _gnc_is_ok (def_shell_mode ());
}

// Restore the program terminal mode.  Always returns #t.
SCM
gnc_reset_prog_mode ()
{
  return _gnc_is_ok (reset_prog_mode ());
}

// Restore the shell terminal mode.  Always returns #t.
SCM
gnc_reset_shell_mode ()
{
  return _gnc_is_ok (reset_shell_mode ());
}

// Reset the state of the terminal mode to the previously stored mode.
// Always returns #t.
SCM
gnc_resetty ()
{
  return _gnc_is_ok (resetty ());
}


// Save the state of the terminal mode.  Always returns #t.
SCM
gnc_savetty ()
{
  return _gnc_is_ok (savetty ());
}

// Return the current coordinates of the virtual screen cursor.  The
// values are returned as a pair.
SCM 
gnc_getsyx ()
{
  int y;
  int x;

  getsyx(y, x);
  
  return scm_cons (scm_from_int (y), scm_from_int (x));
}

// Set the virtual screen cursor location.  Returns UNSPECIFIED.
SCM
gnc_setsyx (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "setsyx");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "setsyx");

  // The macro implementation of setsyx requires a simple call
  int c_x, c_y;

  c_x = scm_to_int (x);
  c_y = scm_to_int (y);


  setsyx (c_y, c_x);

  return SCM_UNSPECIFIED;
}

// Make lines at the top or bottom of the screen unavailable for use.
// If *line* is positive, a line is removed from the top of the standard
// window.  If it is negative, a line is removed from the bottom of
// the standad window.  Always returns #t.

// SCM gnc_ripoffline (SCM line, SCM func);

// Tries to set the cursor state to invisible, normal, or very visible
// on 0, 1, or 2.  Returns #t if successful.
SCM
gnc_curs_set (SCM visibility)
{
  SCM_ASSERT (scm_is_integer (visibility), visibility, SCM_ARG1, "curs-set");

  int v = scm_to_signed_integer (visibility, 0, 2);
  
  return _gnc_is_ok (curs_set (v));
}

// Use the curses library to sleep for *ms* milliseconds.  Always
// returns #t.
SCM
gnc_napms (SCM ms)
{
  SCM_ASSERT (scm_is_integer (ms), ms, SCM_ARG1, "napms");

  return _gnc_is_ok (napms (scm_to_int (ms)));
}


// Register these functions as scheme functions.
void 
_gnc_init_kernel ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("def-prog-mode", 0, 0, 0, gnc_def_prog_mode);
  scm_c_define_gsubr ("def-shell-mode", 0, 0, 0, gnc_def_shell_mode);
  scm_c_define_gsubr ("reset-prog-mode", 0, 0, 0, gnc_reset_prog_mode);
  scm_c_define_gsubr ("reset-shell-mode", 0, 0, 0, gnc_reset_shell_mode);
  scm_c_define_gsubr ("resetty", 0, 0, 0, gnc_resetty);
  scm_c_define_gsubr ("savetty", 0, 0, 0, gnc_savetty);
  scm_c_define_gsubr ("getsyx", 0, 0, 0, gnc_getsyx);
  scm_c_define_gsubr ("setsyx", 2, 0, 0, gnc_setsyx);
  scm_c_define_gsubr ("curs-set", 1, 0, 0, gnc_curs_set);
  scm_c_define_gsubr ("napms", 1, 0, 0, gnc_napms);
}

