// default_colors.h -- wrap curses functions for using terminal's
// default colors 

// $Id: default_colors.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef DEFAULT_COLORS_H
#define DEFAULT_COLORS_H 1

#include <libguile.h>

#include "defines.h"

SCM gnc_use_default_colors (void) API;
SCM gnc_assume_default_colors (SCM fg, SCM bg) API;

void _gnc_init_default_colors (void);


#endif /* not DEFAULT_COLORS_H */
