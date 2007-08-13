// addchstr.h -- wrap curss functions to quickly add characters to a window

// $Id: addchstr.h,v 1.1 2007/08/13 02:26:21 spike_gran Exp $

#ifndef ADDCHSTR_H
#define ADDCHSTR_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_addchstr (SCM str) API;
SCM gnc_addchnstr (SCM str, SCM n) API;
SCM gnc_waddchstr (SCM win, SCM str) API;
SCM gnc_waddchnstr (SCM win, SCM str, SCM n) API;
SCM gnc_mvaddchstr (SCM y, SCM x, SCM str) API;
SCM gnc_mvaddchnstr (SCM y, SCM x, SCM str, SCM n) API;
SCM gnc_mvwaddchstr (SCM win, SCM y, SCM x, SCM str) API;
SCM gnc_mvwaddchnstr (SCM win, SCM y, SCM x, SCM str, SCM n) API;

void _gnc_init_addchstr (void);

#endif /* not ADDCHSTR_H */
