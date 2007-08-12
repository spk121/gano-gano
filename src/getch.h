// getch.h -- wrap curses function to get characters from the keyboard

// $Id: getch.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef GETCH_H
#define GETCH_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_getch (void) API;
SCM gnc_wgetch (SCM win) API;
SCM gnc_mvgetch (SCM y, SCM x) API;
SCM gnc_mvwgetch (SCM win, SCM y, SCM x) API;
SCM gnc_ungetch (SCM ch) API;
SCM gnc_has_key (SCM ch) API;
void _gnc_init_getch (void);

#endif /* not GETCH_H */
