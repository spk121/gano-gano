// addch.h -- wrap curses functions to add a character to the curses window

// $Id: addch.h,v 1.2 2007/08/13 01:15:08 spike_gran Exp $

#ifndef ADDCH_H
#define ADDCH_H 1

#include <libguile.h>
#include <curses.h>
#include "defines.h"

SCM gnc_addch (SCM ch) API;
SCM gnc_waddch (SCM win, SCM ch) API;
SCM gnc_mvaddch (SCM y, SCM x, SCM ch) API;
SCM gnc_mvwaddch (SCM win, SCM y, SCM x, SCM ch) API;
SCM gnc_echochar (SCM ch) API;
SCM gnc_wechochar (SCM win, SCM ch) API;
SCM gnc_get_tabsize (void) API;
SCM gnc_set_tabsize (SCM t) API;

SCM gnc_acs_block (void) API; 
SCM gnc_acs_board (void) API; 
SCM gnc_acs_btee (void) API; 
SCM gnc_acs_bullet (void) API;
SCM gnc_acs_ckboard (void) API;
SCM gnc_acs_darrow (void) API;
SCM gnc_acs_degree (void) API;
SCM gnc_acs_diamond (void) API;
SCM gnc_acs_gequal (void) API;
SCM gnc_acs_hline (void) API;
SCM gnc_acs_lantern (void) API; 
SCM gnc_acs_larrow (void) API;
SCM gnc_acs_lequal (void) API;
SCM gnc_acs_llcorner (void) API;
SCM gnc_acs_lrcorner (void) API; 
SCM gnc_acs_ltee (void) API;
SCM gnc_acs_nequal (void) API; 
SCM gnc_acs_pi (void) API;
SCM gnc_acs_plminus (void) API;
SCM gnc_acs_plus (void) API;
SCM gnc_acs_rarrow (void) API; 
SCM gnc_acs_rtee (void) API;
SCM gnc_acs_s1 (void) API;
SCM gnc_acs_s3 (void) API;
SCM gnc_acs_s7 (void) API;
SCM gnc_acs_s9 (void) API;
SCM gnc_acs_sterling (void) API;
SCM gnc_acs_ttee (void) API;
SCM gnc_acs_uarrow (void) API; 
SCM gnc_acs_ulcorner (void) API; 
SCM gnc_acs_urcorner (void) API;
SCM gnc_acs_vline (void) API;



void _gnc_init_addch (void);

#endif /* not ADDCH_H */
