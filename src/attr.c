// attr.c -- wrap curses functions for controlling window and
// character attributes

// $Id: attr.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "attr.h"
#include "core.h"
#include "defines.h"

#include "type_window.h"

// Turns off the named attribute.  Probably always returns #t.
SCM
gnc_attroff (SCM attrs)
{
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG1, "attroff");

  return _gnc_is_ok (attroff (scm_to_int (attrs)));
}

// Tries to turn off the named attribute for a given window.  Returns
// #t if successful.
SCM
gnc_wattroff (SCM win, SCM attrs)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattroff");
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG2, "wattroff");

  return _gnc_is_ok (wattroff (_gnc_window_data (win),
			       scm_to_int (attrs)));
}

// Turns on the named attribute.  Probably always returns #t.
SCM
gnc_attron (SCM attrs)
{
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG1, "attron");

  return _gnc_is_ok (attron (scm_to_int (attrs)));
}

// Tries to turn on the named attribute for a given window.  Returns
// #t if successful.
SCM
gnc_wattron (SCM win, SCM attrs)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattron");
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG2, "wattron");

  return _gnc_is_ok (wattron (_gnc_window_data (win),
			      scm_to_int (attrs)));
}


// Sets the current attributes of the standard window to attrs.
SCM
gnc_attrset (SCM attrs)
{
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG1, "attrset");

  return _gnc_is_ok (attrset (scm_to_int (attrs)));
}

// Tries to set the attributes for a given window to attrs. Returns #t
// if successful.
SCM
gnc_wattrset (SCM win, SCM attrs)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattrset");
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG2, "wattrset");
  
  return _gnc_is_ok (wattrset (_gnc_window_data (win),
			       scm_to_int (attrs)));
}

// Sets the color of the standard window to the given pair.
SCM
gnc_color_set (SCM pair)
{
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG1, "color-set");
  
  return _gnc_is_ok (color_set (scm_to_short (pair), 0));
}

// Sets the color of a window to the given pair.
SCM
gnc_wcolor_set (SCM win, SCM pair)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wcolor-set");
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG2, "wcolor-set");
  
  return _gnc_is_ok (wcolor_set (_gnc_window_data (win),
				 scm_to_short (pair), 
				 0));
}

SCM
gnc_standend ()
{
  return _gnc_is_ok (standend ());
}

SCM
gnc_wstandend (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wstandend");

  return _gnc_is_ok (wstandend (_gnc_window_data (win)));
}

SCM
gnc_standout ()
{
  return _gnc_is_ok (standout ());
}

SCM
gnc_wstandout (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wstandout");

  return _gnc_is_ok (wstandout (_gnc_window_data (win)));
}

SCM
gnc_attr_get ()
{
  attr_t attrs;
  short pair;
  int ret;

  ret = attr_get (&attrs, &pair, 0);
  if (ret == OK)
    return scm_list_2 (_gnc_from_attr (attrs),
		       scm_from_short (pair));
  else
    return SCM_BOOL_F;
}
  
SCM
gnc_wattr_get (SCM win)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattr_get");

  attr_t attrs;
  short pair;
  int ret;

  ret = wattr_get (_gnc_window_data (win), &attrs, &pair, 0);
  if (ret == OK)
    return scm_list_2 (_gnc_from_attr (attrs),
		       scm_from_short (pair));
  else
    return SCM_BOOL_F;
}

SCM
gnc_attr_off (SCM attrs)
{
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG1, "attr-off");
  
  return _gnc_is_ok (attr_off (_gnc_to_attr (attrs), 0));
}

SCM
gnc_wattr_off (SCM win, SCM attrs)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattr_off");
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG2, "wattr-off");

  return _gnc_is_ok (wattr_off (_gnc_window_data (win),
				_gnc_to_attr (attrs), 
				0));
}

SCM
gnc_attr_on (SCM attrs)
{
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG1, "attr-on");
  
  return _gnc_is_ok (attr_on (_gnc_to_attr (attrs), 0));
}

SCM
gnc_wattr_on (SCM win, SCM attrs)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattr_on");
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG2, "wattr-on");

  return _gnc_is_ok (wattr_on (_gnc_window_data (win),
			       _gnc_to_attr (attrs), 
			       0));
}

SCM
gnc_attr_set (SCM attrs, SCM pair)
{
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG1, "attr-set");
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG1, "attr-set");

  return _gnc_is_ok (attr_set (_gnc_to_attr (attrs),
			       scm_to_short (pair),
			       0));
}

SCM
gnc_wattr_set (SCM win, SCM attrs, SCM pair)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wattr_set");
  SCM_ASSERT (_gnc_is_attr (attrs), attrs, SCM_ARG2, "attr-set");
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG3, "attr-set");

  return _gnc_is_ok (wattr_set (_gnc_window_data (win),
				_gnc_to_attr (attrs),
				scm_to_short (pair),
				0));
}

// Changes the attributes of a given number of characters beginning at
// the current cursor location in the standard window
SCM
gnc_chgat (SCM n, SCM attr, SCM color)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "chgat");
  SCM_ASSERT (_gnc_is_attr (attr), attr, SCM_ARG2, "chgat");
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG3, "chgat");

  return _gnc_is_ok (chgat (scm_to_int (n),
			    _gnc_to_attr (attr),
			    scm_to_short (color),
			    0));
}

SCM
gnc_wchgat (SCM win,SCM n, SCM attr, SCM color)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "wchgat");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "wchgat");
  SCM_ASSERT (_gnc_is_attr (attr), attr, SCM_ARG3, "wchgat");
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG4, "wchgat");

  return _gnc_is_ok (wchgat (_gnc_window_data (win),
			     scm_to_int (n),
			     _gnc_to_attr (attr),
			     scm_to_short (color),
			     0));
}


SCM
gnc_mvchgat (SCM y, SCM x, SCM n, SCM attr, SCM color)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvchgat");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvchgat");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvchgat");
  SCM_ASSERT (_gnc_is_attr (attr), attr, SCM_ARG4,  "mvchgat");
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG5, "mvchgat");

  return _gnc_is_ok (mvchgat (scm_to_int (y),
			     scm_to_int (x),
			     scm_to_int (n),
			     _gnc_to_attr (attr),
			     scm_to_short (color),
			     0));
}



SCM
gnc_mvwchgat (SCM win, SCM y, SCM x, SCM n, SCM attr, SCM color)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "mvwchgat");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwchgat");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwchgat");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvwchgat");
  SCM_ASSERT (_gnc_is_attr (attr), attr, SCM_ARG5,  "mvwchgat");
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG6, "mvwchgat");

  return _gnc_is_ok (mvwchgat (_gnc_window_data (win),
			     scm_to_int (y),
			     scm_to_int (x),
			     scm_to_int (n),
			     _gnc_to_attr (attr),
			     scm_to_short (color),
			     0));
}

SCM
gnc_pair_number (SCM attrs)
{
  SCM_ASSERT (scm_is_integer (attrs), attrs, SCM_ARG1, "pair-number");

  return scm_from_int (PAIR_NUMBER (scm_to_int (attrs)));
}


void
_gnc_init_attr ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("attroff", 1, 0, 0, gnc_attroff);
  scm_c_define_gsubr ("wattroff", 2, 0, 0, gnc_wattroff);
  scm_c_define_gsubr ("attron", 1, 0, 0, gnc_attron);
  scm_c_define_gsubr ("wattron", 2, 0, 0, gnc_wattron);
  scm_c_define_gsubr ("attrset", 1, 0, 0, gnc_attrset);
  scm_c_define_gsubr ("wattrset", 2, 0, 0, gnc_wattrset);
  scm_c_define_gsubr ("color-set", 1, 0, 0, gnc_color_set);
  scm_c_define_gsubr ("wcolor-set", 2, 0, 0, gnc_wcolor_set);
  scm_c_define_gsubr ("standend", 0, 0, 0, gnc_standend);
  scm_c_define_gsubr ("wstandend", 1, 0, 0, gnc_wstandend);
  scm_c_define_gsubr ("standout", 0, 0, 0, gnc_standout);
  scm_c_define_gsubr ("wstandout", 1, 0, 0, gnc_wstandout);
  scm_c_define_gsubr ("attr-get", 0, 0, 0, gnc_attr_get);
  scm_c_define_gsubr ("wattr-get", 1, 0, 0, gnc_wattr_get);
  scm_c_define_gsubr ("attr-off", 1, 0, 0, gnc_attr_off);
  scm_c_define_gsubr ("wattr-off", 2, 0, 0, gnc_wattr_off);
  scm_c_define_gsubr ("attr-set", 2, 0, 0, gnc_attr_set);
  scm_c_define_gsubr ("wattr-set", 3, 0, 0, gnc_wattr_set);
  scm_c_define_gsubr ("chgat", 3, 0, 0, gnc_chgat);
  scm_c_define_gsubr ("wchgat", 4, 0, 0, gnc_wchgat);
  scm_c_define_gsubr ("mvchgat", 5, 0, 0, gnc_mvchgat);
  scm_c_define_gsubr ("mvwchgat", 6, 0, 0, gnc_mvwchgat);
  scm_c_define_gsubr ("pair-number", 1, 0, 0, gnc_pair_number);
}





  
