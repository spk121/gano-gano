// attr.h -- wrap curses functions for controlling window and
// character attributes

// $Id: attr.h,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#ifndef ATTR_H
#define ATTR_H 1

#include <libguile.h>

#include "defines.h"

SCM gnc_attroff (SCM attrs) API;
SCM gnc_wattroff (SCM win, SCM attrs) API;
SCM gnc_attron (SCM attrs) API;
SCM gnc_wattron (SCM win, SCM attrs) API;
SCM gnc_attrset (SCM attrs) API;
SCM gnc_wattrset (SCM win, SCM attrs) API;
SCM gnc_color_set (SCM pair) API;
SCM gnc_wcolor_set (SCM win, SCM pair) API;
SCM gnc_standend (void) API;
SCM gnc_wstandend (SCM win) API;
SCM gnc_standout (void) API;
SCM gnc_wstandout (SCM win) API;
SCM gnc_attr_get (void) API;
SCM gnc_wattr_get (SCM win) API;
SCM gnc_attr_off (SCM attrs) API;
SCM gnc_wattr_off (SCM win, SCM attrs) API;
SCM gnc_attr_on (SCM attrs) API;
SCM gnc_wattr_on (SCM win, SCM attrs) API;
SCM gnc_attr_set (SCM attrs, SCM pair) API;
SCM gnc_wattr_set (SCM win, SCM attrs, SCM pair) API;
SCM gnc_chgat (SCM n, SCM attr, SCM color) API;
SCM gnc_wchgat (SCM win,SCM n, SCM attr, SCM color) API;
SCM gnc_mvchgat (SCM y, SCM x, SCM n, SCM attr, SCM color) API;
SCM gnc_mvwchgat (SCM win, SCM y, SCM x, SCM n, SCM attr, SCM color) API;
SCM gnc_pair_number (SCM attrs);

void _gnc_init_attr (void);

#endif
