// color.h -- wrap curses functions that manipulate color

// $Id: color.h,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#ifndef COLOR_H
#define COLOR_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_start_color (void) API;
SCM gnc_init_pair (SCM pair, SCM fore, SCM back) API;
SCM gnc_init_color (SCM color, SCM r, SCM g, SCM b) API;
SCM gnc_has_colors (void) API;
SCM gnc_can_change_color (void) API;
SCM gnc_color_content (SCM color) API;
SCM gnc_pair_content (SCM pair) API;
SCM gnc_colors (void) API;
SCM gnc_color_pairs (void) API;

void _gnc_init_color (void);

#endif /* not COLOR_H */
