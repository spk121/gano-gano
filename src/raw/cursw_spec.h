#ifndef CURSW_SPEC_H
#define CURSW_SPEC_H 1

#include <libguile.h>
#include <config.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

SCM gucu_WACS_BLOCK (void) API;
SCM gucu_WACS_BOARD (void) API;
SCM gucu_WACS_BTEE (void) API;
SCM gucu_WACS_BULLET (void) API;
SCM gucu_WACS_CKBOARD (void) API;
SCM gucu_WACS_DARROW (void) API;
SCM gucu_WACS_DEGREE (void) API;
SCM gucu_WACS_DIAMOND (void) API;
SCM gucu_WACS_HLINE (void) API;
SCM gucu_WACS_LANTERN (void) API;
SCM gucu_WACS_LARROW (void) API;
SCM gucu_WACS_LLCORNER (void) API;
SCM gucu_WACS_LRCORNER (void) API;
SCM gucu_WACS_LTEE (void) API;
SCM gucu_WACS_PLMINUS (void) API;
SCM gucu_WACS_PLUS (void) API;
SCM gucu_WACS_RARROW (void) API;
SCM gucu_WACS_RTEE (void) API;
SCM gucu_WACS_S1 (void) API;
SCM gucu_WACS_S9 (void) API;
SCM gucu_WACS_TTEE (void) API;
SCM gucu_WACS_UARROW (void) API; 
SCM gucu_WACS_ULCORNER (void) API;
SCM gucu_WACS_URCORNER (void) API;
SCM gucu_WACS_VLINE (void) API;
SCM gucu_erasewchar (void) API;
SCM gucu_get_wch (void) API;
SCM gucu_getbkgrnd (void) API;
SCM gucu_getn_wstr (SCM n) API;
SCM gucu_in_wch (void) API;
SCM gucu_in_wchnstr (SCM n) API;
SCM gucu_in_wchstr (void) API;
SCM gucu_inwstr () API;
SCM gucu_killwchar (void) API;
SCM gucu_mvget_wch (SCM y, SCM x) API;
SCM gucu_mvgetn_wstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvin_wch (SCM y, SCM x) API;
SCM gucu_mvin_wchnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvin_wchstr (SCM y, SCM x) API;
SCM gucu_mvinwstr (SCM y, SCM x) API;
SCM gucu_mvwget_wch (SCM win, SCM y, SCM x) API;
SCM gucu_mvwgetn_wstr (SCM win, SCM y, SCM x, SCM n) API;
SCM gucu_mvwin_wch (SCM win, SCM y, SCM x) API;
SCM gucu_mvwin_wchnstr (SCM win, SCM y, SCM x, SCM n) API;
SCM gucu_mvwin_wchstr (SCM win, SCM y, SCM x) API;
SCM gucu_mvwinnwstr (SCM y, SCM x, SCM win, SCM n) API;
SCM gucu_mvwinwstr (SCM y, SCM x, SCM win) API;
SCM gucu_wget_wch (SCM win) API;
SCM gucu_wgetbkgrnd (SCM win) API;
SCM gucu_wgetn_wstr (SCM win, SCM n) API;
SCM gucu_win_wch (SCM win) API;
SCM gucu_win_wchnstr (SCM win, SCM n) API;
SCM gucu_win_wchstr (SCM win) API;
SCM gucu_winnwstr (SCM win, SCM n) API;
SCM gucu_winwstr (SCM win) API;

void gucu_cursw_init_special (void);
#endif
