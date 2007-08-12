// addstr.h -- wrap curses functions to add strings to curses windows

// $Id: addstr.h,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#ifndef ADDSTR_H
#define ADDSTR_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_addstr (SCM str) API;
SCM gnc_addnstr (SCM str, SCM n) API;
SCM gnc_waddstr (SCM win, SCM str) API;
SCM gnc_waddnstr (SCM win, SCM str, SCM n) API;
SCM gnc_mvaddstr (SCM y, SCM x, SCM str) API;
SCM gnc_mvaddnstr (SCM y, SCM x, SCM str, SCM n) API;
SCM gnc_mvwaddstr (SCM win, SCM y, SCM x, SCM str) API;
SCM gnc_mvwaddnstr (SCM win, SCM y, SCM x, SCM str, SCM n) API;

void _gnc_init_addstr (void);

#endif /* not ADDSTR_H */

