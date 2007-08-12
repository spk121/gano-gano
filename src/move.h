// move.h -- wrap curses functions to move the cursor in a curses window

// $Id: move.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef MOVE_H
#define MOVE_H 1

#include <libguile.h>
#include <curses.h>
#include "defines.h"

SCM gnc_move (SCM y, SCM x) API;
SCM gnc_wmove (SCM win, SCM y, SCM x) API;

void _gnc_init_move (void);

#endif /* not MOVE_H */
