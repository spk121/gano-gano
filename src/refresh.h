// refresh.h -- refresh curses windows and lines

// $Id: refresh.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef REFRESH_H
#define REFRESH_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_refresh (void) API;
SCM gnc_wrefresh (SCM win) API;
SCM gnc_wnoutrefresh (SCM win) API; 
SCM gnc_doupdate (void) API;
SCM gnc_redrawwin (SCM win) API;
SCM gnc_wredrawln (SCM win, SCM beg_line, SCM num_lines) API;

void _gnc_init_refresh (void);

#endif /* not REFRESH_H */
