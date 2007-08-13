// termattrs.h -- guile wrapper for curses functions that query the environment

#ifndef TERMATTRS_H
#define TERMATTRS_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_baudrate (void) API;
void gnc_init_termattrs (void) API;

#endif
