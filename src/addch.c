// addch.c -- wrap curses functions to add characters to the curses window

// $Id: addch.c,v 1.2 2007/08/13 01:15:08 spike_gran Exp $

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

// Get / set tabsize.  Note that the tabsize is only defined after
// initscr is called.
SCM
gnc_get_tabsize ()
{
  return scm_from_int (TABSIZE);
}

SCM
gnc_set_tabsize (SCM t)
{
  SCM_ASSERT (scm_is_integer (t), t, SCM_ARG1, "set-tabsize");

  TABSIZE = scm_to_int (t);

  return SCM_UNSPECIFIED;
}

// Since the following curses identifiers are implemented as macros
// and don't have values until initscr is called, I'll wrap them as
// functions.
SCM gnc_acs_block () {return scm_from_int (ACS_BLOCK);}
SCM gnc_acs_board () {return scm_from_int (ACS_BOARD);}
SCM gnc_acs_btee () {return scm_from_int (ACS_BTEE);}
SCM gnc_acs_bullet () {return scm_from_int (ACS_BULLET);}
SCM gnc_acs_ckboard () {return scm_from_int (ACS_CKBOARD);}
SCM gnc_acs_darrow () {return scm_from_int (ACS_DARROW);}
SCM gnc_acs_degree () {return scm_from_int (ACS_DEGREE);}
SCM gnc_acs_diamond () {return scm_from_int (ACS_DIAMOND);}
SCM gnc_acs_gequal () {return scm_from_int (ACS_GEQUAL);}
SCM gnc_acs_hline () {return scm_from_int (ACS_HLINE);}
SCM gnc_acs_lantern () {return scm_from_int (ACS_LANTERN);}
SCM gnc_acs_larrow () {return scm_from_int (ACS_LARROW);}
SCM gnc_acs_lequal () {return scm_from_int (ACS_LEQUAL);}
SCM gnc_acs_llcorner () {return scm_from_int (ACS_LLCORNER);}
SCM gnc_acs_lrcorner () {return scm_from_int (ACS_LRCORNER);}
SCM gnc_acs_ltee () {return scm_from_int (ACS_LTEE);}
SCM gnc_acs_nequal () {return scm_from_int (ACS_NEQUAL);}
SCM gnc_acs_pi () {return scm_from_int (ACS_PI);}
SCM gnc_acs_plminus () {return scm_from_int (ACS_PLMINUS);}
SCM gnc_acs_plus () {return scm_from_int (ACS_PLUS);}
SCM gnc_acs_rarrow () {return scm_from_int (ACS_RARROW);}
SCM gnc_acs_rtee () {return scm_from_int (ACS_RTEE);}
SCM gnc_acs_s1 () {return scm_from_int (ACS_S1);}
SCM gnc_acs_s3 () {return scm_from_int (ACS_S3);}
SCM gnc_acs_s7 () {return scm_from_int (ACS_S7);}
SCM gnc_acs_s9 () {return scm_from_int (ACS_S9);}
SCM gnc_acs_sterling () {return scm_from_int (ACS_STERLING);}
SCM gnc_acs_ttee () {return scm_from_int (ACS_TTEE);}
SCM gnc_acs_uarrow () {return scm_from_int (ACS_UARROW);}
SCM gnc_acs_ulcorner () {return scm_from_int (ACS_ULCORNER);}
SCM gnc_acs_urcorner () {return scm_from_int (ACS_URCORNER);}
SCM gnc_acs_vline () {return scm_from_int (ACS_VLINE);}


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
  scm_c_define_gsubr ("get-tabsize", 0, 0, 0, gnc_get_tabsize);
  scm_c_define_gsubr ("set-tabsize", 1, 0, 0, gnc_set_tabsize);

  scm_c_define_gsubr ("acs-block", 0, 0, 0,  gnc_acs_block);
  scm_c_define_gsubr ("acs-board", 0, 0, 0,  gnc_acs_board);
  scm_c_define_gsubr ("acs-btee", 0, 0, 0,  gnc_acs_btee);
  scm_c_define_gsubr ("acs-bullet", 0, 0, 0,  gnc_acs_bullet);
  scm_c_define_gsubr ("acs-ckboard", 0, 0, 0,  gnc_acs_ckboard);
  scm_c_define_gsubr ("acs-darrow", 0, 0, 0,  gnc_acs_darrow);
  scm_c_define_gsubr ("acs-degree", 0, 0, 0,  gnc_acs_degree);
  scm_c_define_gsubr ("acs-diamond", 0, 0, 0,  gnc_acs_diamond);
  scm_c_define_gsubr ("acs-gequal", 0, 0, 0,  gnc_acs_gequal);
  scm_c_define_gsubr ("acs-hline", 0, 0, 0,  gnc_acs_hline);
  scm_c_define_gsubr ("acs-lantern", 0, 0, 0,  gnc_acs_lantern);
  scm_c_define_gsubr ("acs-larrow", 0, 0, 0,  gnc_acs_larrow);
  scm_c_define_gsubr ("acs-lequal", 0, 0, 0,  gnc_acs_lequal);
  scm_c_define_gsubr ("acs-llcorner", 0, 0, 0,  gnc_acs_llcorner);
  scm_c_define_gsubr ("acs-lrcorner", 0, 0, 0,  gnc_acs_lrcorner);
  scm_c_define_gsubr ("acs-ltee", 0, 0, 0,  gnc_acs_ltee);
  scm_c_define_gsubr ("acs-nequal", 0, 0, 0,  gnc_acs_nequal);
  scm_c_define_gsubr ("acs-pi", 0, 0, 0,  gnc_acs_pi);
  scm_c_define_gsubr ("acs-plminus", 0, 0, 0,  gnc_acs_plminus);
  scm_c_define_gsubr ("acs-plus", 0, 0, 0,  gnc_acs_plus);
  scm_c_define_gsubr ("acs-rarrow", 0, 0, 0,  gnc_acs_rarrow);
  scm_c_define_gsubr ("acs-rtee", 0, 0, 0,  gnc_acs_rtee);
  scm_c_define_gsubr ("acs-s1", 0, 0, 0,  gnc_acs_s1);
  scm_c_define_gsubr ("acs-s3" , 0, 0, 0,  gnc_acs_s3);
  scm_c_define_gsubr ("acs-s7", 0, 0, 0,  gnc_acs_s7);
  scm_c_define_gsubr ("acs-s9", 0, 0, 0,  gnc_acs_s9);
  scm_c_define_gsubr ("acs-sterling", 0, 0, 0,  gnc_acs_sterling);
  scm_c_define_gsubr ("acs-ttee", 0, 0, 0,  gnc_acs_ttee);
  scm_c_define_gsubr ("acs-uarrow", 0, 0, 0,  gnc_acs_uarrow);
  scm_c_define_gsubr ("acs-ulcorner", 0, 0, 0,  gnc_acs_ulcorner);
  scm_c_define_gsubr ("acs-urcorner", 0, 0, 0,  gnc_acs_urcorner);
  scm_c_define_gsubr ("acs-vline", 0, 0, 0,  gnc_acs_vline);
  
}

