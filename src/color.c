// color.c -- wrap curses functions that manipulate color

// $Id: color.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "core.h"
#include "defines.h"
#include "color.h"

// To support color, this must be called right after gnc_initscr.
// Returns #t so long as a color table can be allocated.
SCM
gnc_start_color ()
{
  return _gnc_is_ok (start_color ());
}


// Changes the definition of a color pair
SCM
gnc_init_pair (SCM pair, SCM fore, SCM back)
{
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG1, "init-pair");
  SCM_ASSERT (scm_is_integer (fore), fore, SCM_ARG2, "init-pair");
  SCM_ASSERT (scm_is_integer (back), back, SCM_ARG3, "init-pair");
  
  return _gnc_is_ok (init_pair (scm_to_short (pair),
				scm_to_short (fore),
				scm_to_short (back)));
}

// Changes the definition of a given color.  Returns #t on success.
SCM
gnc_init_color (SCM color, SCM r, SCM g, SCM b)
{
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG1, "init-color");
  SCM_ASSERT (scm_is_integer (r), r, SCM_ARG2, "init-color");
  SCM_ASSERT (scm_is_integer (g), g, SCM_ARG3, "init-color");
  SCM_ASSERT (scm_is_integer (b), b, SCM_ARG4, "init-color");
  
  return _gnc_is_ok (init_color (scm_to_short (color),
				 scm_to_short (r),
				 scm_to_short (g),
				 scm_to_short (b)));
}

// Returns #t if the terminal has color capabilities.
SCM
gnc_has_colors ()
{
  return scm_from_bool (has_colors ());
}

// Returns #t if the terminal has colors that can be redefined
SCM
gnc_can_change_color ()
{
  return scm_from_bool (can_change_color ());
}


// Tries to return the red, green and blue in a given color as a list.
// If it cannot, returns #f.
SCM
gnc_color_content (SCM color)
{
  SCM_ASSERT (scm_is_integer (color), color, SCM_ARG1, "color-content");

  short r, g, b;
  int ret;

  ret = color_content (scm_to_short (color), &r, &g, &b);

  if (ret == OK) 
    {
      return scm_list_3 (scm_from_short (r),
			 scm_from_short (g),
			 scm_from_short (b));
    }
  else
    return SCM_BOOL_F;
}

// Tries to return the foreground and background color numbers for a
// given color pair as a pair.  If it cannot, returns #f..
SCM
gnc_pair_content (SCM pair)
{
  SCM_ASSERT (scm_is_integer (pair), pair, SCM_ARG1, "pair-content");

  short fore, back;
  int ret;

  ret = pair_content (scm_to_short (pair), &fore, &back);

  if (ret == OK)
    return scm_list_2 (scm_from_short (fore),
		       scm_from_short (back));
  else
    return SCM_BOOL_F;
}

// Returns the maximum number of colors
SCM
gnc_colors ()
{
  return scm_from_int (COLORS);
}

// Returns the maximum number of color pairs
SCM
gnc_color_pairs ()
{
  return scm_from_int (COLOR_PAIRS);
}

// Returns a character mask value for a given color
SCM
gnc_color_pair (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "color-pair");
  
  int pair = scm_to_signed_integer (n, 0, 255);
  
  return scm_from_ulong (COLOR_PAIR (pair));
}
  
    
  
// Register these functions as scheme functions.
void
_gnc_init_color ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  // Exported constants and macros
  scm_c_define_gsubr ("colors", 0, 0, 0, gnc_colors);
  scm_c_define_gsubr ("color-pairs", 0, 0, 0, gnc_color_pairs);
  scm_c_define_gsubr ("color-pair", 1, 0, 0, gnc_color_pair);
  
  // Exported functions
  scm_c_define_gsubr ("start-color", 0, 0, 0, gnc_start_color);
  scm_c_define_gsubr ("init-pair", 3, 0, 0, gnc_init_pair);
  scm_c_define_gsubr ("init-color", 4, 0, 0, gnc_init_color);
  scm_c_define_gsubr ("has-colors", 0, 0, 0, gnc_has_colors);
  scm_c_define_gsubr ("can-change-color", 0, 0, 0, gnc_can_change_color);
  scm_c_define_gsubr ("color-content", 1, 0, 0, gnc_color_content);
  scm_c_define_gsubr ("pair-content", 1, 0, 0, gnc_pair_content);
}
