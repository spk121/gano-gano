// kernel -- wrap low-level curses functions

// $Id: kernel.h,v 1.1 2007/08/12 23:52:43 spike_gran Exp $

#ifndef KERNEL_H
#define KERNEL_H 1

#include "defines.h"
SCM gnc_def_prog_mode (void) API;
SCM gnc_def_shell_mode (void) API;
SCM gnc_reset_prog_mode (void) API;
SCM gnc_reset_shell_mode (void) API;
SCM gnc_resetty (void) API;
SCM gnc_savetty (void) API;
SCM gnc_getsyx (void) API;
SCM gnc_setsyx (SCM y, SCM x) API;
SCM gnc_curs_set (SCM visibility) API;
SCM gnc_napms (SCM ms) API;

void _gnc_init_kernel (void);

#endif
