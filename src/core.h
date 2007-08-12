// core.h -- main initialization and helper functions

// $Id: core.h,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

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
int _gnc_is_cchar (SCM s);
cchar_t* _gnc_to_cchar (SCM s);

#endif
