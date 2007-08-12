// addch.h -- wrap curses functions to add a character to the curses window

// $Id: addch.h,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#ifndef ADDCH_H
#define ADDCH_H 1

#include <libguile.h>
#include <curses.h>
#include "defines.h"

SCM gnc_addch (SCM ch) API;
SCM gnc_waddch (SCM win, SCM ch) API;
SCM gnc_mvaddch (SCM y, SCM x, SCM ch) API;
SCM gnc_mvwaddch (SCM win, SCM y, SCM x, SCM ch) API;
SCM gnc_echochar (SCM ch) API;
SCM gnc_wechochar (SCM win, SCM ch) API;

void _gnc_init_addch (void);

#endif /* not ADDCH_H */
