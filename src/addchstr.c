// addchstr -- add strings to a curses window 

// $Id: addchstr.c,v 1.1 2007/08/13 02:26:21 spike_gran Exp $

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "addchstr.h"
#include "core.h"
#include "defines.h"
#include "type_window.h"

// Copy chstr into the window image structure after the current cursor
// position.  The cursor is not advanced. No checking or conversion
// occurs.  These functions should be faster than addstr.
// They all return #t always, if the window is not null.

SCM
gnc_addchstr (SCM str)
{
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG1, "addchstr");

  chtype *chstr;
  int ret;
  
  
  chstr = _gnc_to_chstr (str);
  ret = addchstr (chstr);
  free(chstr);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_addchnstr (SCM str, SCM n)
{
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG1, "addchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "addchnstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = addchnstr (chstr,
		   scm_to_int (n));
  free(chstr);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_waddchstr (SCM win, SCM str)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "waddchstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG2, "waddchstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = waddchstr (_gnc_window_data (win),
		   chstr);
  free(chstr);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_waddchnstr (SCM win, SCM str, SCM n)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "waddchnstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG2, "waddchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "waddchnstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = waddchnstr (_gnc_window_data (win),
		    chstr,
		    scm_to_int (n));
  free(chstr);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_mvaddchstr (SCM y, SCM x, SCM str)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvaddchstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvaddchstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG3, "mvaddchstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = mvaddchstr (scm_to_int (y),
		    scm_to_int (x),
		    chstr);
  free(chstr);
  
  return _gnc_is_ok (ret);
}


SCM
gnc_mvaddchnstr (SCM y, SCM x, SCM str, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvaddchnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvaddchnstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG3, "mvaddchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvaddchnstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = mvaddchnstr (scm_to_int (y),
		     scm_to_int (x),
		     chstr,
		     scm_to_int (n));
  free(chstr);
  
  return _gnc_is_ok (ret);
}



SCM
gnc_mvwaddchstr (SCM win, SCM y, SCM x, SCM str)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "mvwaddchstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwaddchstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwaddchstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG4, "mvwaddchstr");
  
  chtype *chstr;
  int ret;
  
  chstr = _gnc_to_chstr (str);
  ret = mvwaddchstr (_gnc_window_data (win),
		     scm_to_int (y),
		     scm_to_int (x),
		     chstr);
  free(chstr);
  
  return _gnc_is_ok (ret);
}


SCM
gnc_mvwaddchnstr (SCM win, SCM y, SCM x, SCM str, SCM n)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "mvwaddchnstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwaddchnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwaddchnstr");
  SCM_ASSERT (_gnc_is_chstr (str), str, SCM_ARG4, "mvwaddchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG5, "mvwaddchnstr");

  chtype *chstr;
  int ret;

  chstr = _gnc_to_chstr (str);
  ret = mvwaddchnstr (_gnc_window_data (win),
		      scm_to_int (y),
		      scm_to_int (x),
		      chstr,
		      scm_to_int (n));
  free(chstr);
  
  return _gnc_is_ok (ret);
}

void
_gnc_init_addchstr ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("addchstr", 1, 0, 0, gnc_addchstr);
  scm_c_define_gsubr ("addchnstr", 2, 0, 0, gnc_addchnstr);
  scm_c_define_gsubr ("waddchstr", 2, 0, 0, gnc_waddchstr);
  scm_c_define_gsubr ("waddchnstr", 3, 0, 0, gnc_waddchnstr);
  scm_c_define_gsubr ("mvaddchstr", 3, 0, 0, gnc_mvaddchstr);
  scm_c_define_gsubr ("mvaddchnstr", 4, 0, 0, gnc_mvaddchnstr);
  scm_c_define_gsubr ("mvwaddchstr", 4, 0, 0, gnc_mvwaddchstr);
  scm_c_define_gsubr ("mvwaddchnstr", 5, 0, 0, gnc_mvwaddchnstr);
}
  
