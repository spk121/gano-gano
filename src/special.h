#ifndef SPECIAL_H
#define SPECIAL_H 1

#include <libguile.h>
#include <config.h>

#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

SCM gucu_attr_get () API;
SCM gucu_color_content (SCM s_color) API;
SCM gucu_getnstr (SCM n) API;
SCM gucu_getstr () API;
SCM gucu_inchnstr (SCM n) API;
SCM gucu_inchstr () API;
SCM gucu_innstr (SCM n) API;
SCM gucu_instr () API;
SCM gucu_mvgetnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvgetstr (SCM y, SCM x) API;
SCM gucu_mvinchnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvinchstr(SCM y, SCM x) API;
SCM gucu_mvinnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvinstr (SCM y, SCM x) API;
SCM gucu_mvwinchnstr (SCM y, SCM x, SCM win, SCM n) API;
SCM gucu_mvwinchstr (SCM y, SCM x, SCM win) API;
SCM gucu_mvwinnstr (SCM y, SCM x, SCM win, SCM n) API;
SCM gucu_mvwinstr (SCM y, SCM x, SCM win) API;
SCM gucu_pair_content (SCM s_color) API;
SCM gucu_wattr_get (SCM win) API;
SCM gucu_wgetnstr (SCM win, SCM n) API;
SCM gucu_wgetstr (SCM win) API;
SCM gucu_winchnstr (SCM win, SCM n) API;
SCM gucu_winchstr (SCM win) API;
SCM gucu_winnstr (SCM win, SCM n) API;
SCM gucu_winstr (SCM win) API;
SCM gugu_getbegyx (SCM win) API;
SCM gugu_getmaxyx (SCM win) API;
SCM gugu_getparyx (SCM win) API;
SCM gugu_getyx (SCM win) API;

SCM gucu_ACS_BLOCK (void) API;
SCM gucu_ACS_BOARD (void) API;
SCM gucu_ACS_BTEE (void) API;
SCM gucu_ACS_BULLET (void) API;
SCM gucu_ACS_CKBOARD (void) API;
SCM gucu_ACS_DARROW (void) API;
SCM gucu_ACS_DEGREE (void) API;
SCM gucu_ACS_DIAMOND (void) API;
SCM gucu_ACS_GEQUAL (void) API;
SCM gucu_ACS_HLINE (void) API;
SCM gucu_ACS_LANTERN (void) API;
SCM gucu_ACS_LARROW (void) API;
SCM gucu_ACS_LEQUAL (void) API;
SCM gucu_ACS_LLCORNER (void) API;
SCM gucu_ACS_LRCORNER (void) API;
SCM gucu_ACS_LTEE (void) API;
SCM gucu_ACS_NEQUAL (void) API;
SCM gucu_ACS_PI (void) API;
SCM gucu_ACS_PLMINUS (void) API;
SCM gucu_ACS_PLUS (void) API;
SCM gucu_ACS_RARROW (void) API;
SCM gucu_ACS_RTEE (void) API;
SCM gucu_ACS_S1 (void) API;
SCM gucu_ACS_S3 (void) API;
SCM gucu_ACS_S7 (void) API;
SCM gucu_ACS_S9 (void) API;
SCM gucu_ACS_STERLING (void) API;
SCM gucu_ACS_TTEE (void) API;
SCM gucu_ACS_UARROW (void) API;
SCM gucu_ACS_ULCORNER (void) API;
SCM gucu_ACS_URCORNER (void) API;
SCM gucu_ACS_VLINE (void) API;


SCM gucu_LINES (void) API;
SCM gucu_COLS (void) API;


void gucu_init_special (void);

#endif /* not SPECIAL_H */
