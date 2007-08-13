// beep.h -- guile wrapper for curses bell and screen flash routines

#ifndef BEEP_H
#define BEEP_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_beep (void) API;
SCM gnc_flash (void) API;

void gnc_init_beep (void) API;

#endif /* not BEEP_H */
