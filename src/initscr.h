#ifndef CURS_INITSCR_H
#define CURS_INITSCR_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_stdscr (void) API;
SCM gnc_cols (void) API;
SCM gnc_lines (void) API;
SCM gnc_initscr (void) API;
SCM gnc_endwin (void) API;
SCM gnc_isendwin (void) API; 

void _gnc_init_initscr (void);

#endif
