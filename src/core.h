// core.h -- main initialization and helper functions

// $Id: core.h,v 1.2 2007/08/13 01:15:08 spike_gran Exp $

#ifndef CORE_H
#define CORE_H 1

#include <libguile.h>
#include <curses.h>

#include "defines.h"


void gnc_init_core (void) API;
SCM _gnc_is_ok (int);
int _gnc_is_chtype (SCM c);
chtype _gnc_to_chtype (SCM c);
int _gnc_is_attr (SCM x);
attr_t _gnc_to_attr (SCM x);
SCM _gnc_from_attr (attr_t x);

#endif
