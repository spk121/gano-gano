// inopts.h -- wrap curses input options

// $Id: inopts.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef INOPTS_H
#define INOPTS_H 1

#include "defines.h"

SCM gnc_cbreak (void) API;
SCM gnc_nocbreak (void) API;
SCM gnc_echo (void) API;
SCM gnc_noecho (void) API;
SCM gnc_halfdelay (SCM tenths) API;
SCM gnc_intrflush (SCM win_smob, SCM bf) API;
SCM gnc_keypad (SCM win, SCM bf) API;
SCM gnc_meta (SCM win, SCM bf) API;
SCM gnc_nodelay (SCM win, SCM bf) API;
SCM gnc_raw (void) API;
SCM gnc_noraw (void) API;
SCM gnc_noqiflush (void) API;
SCM gnc_qiflush (void) API;
SCM gnc_notimeout (SCM win, SCM bf) API;
SCM gnc_timeout (SCM delay) API;
SCM gnc_wtimeout (SCM win, SCM delay) API;

void _gnc_init_inopts (void);


#endif /* not INOPTS_H */
