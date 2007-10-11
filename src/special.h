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
SCM gucu_getbkgrnd () API;
SCM gucu_getnstr (SCM n) API;
SCM gucu_getstr () API;
SCM gucu_inchnstr (SCM n) API;
SCM gucu_inchstr () API;
SCM gucu_innstr (SCM n) API;
SCM gucu_instr () API;
SCM guci_in_wch (void) API;
SCM gucu_mvgetnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvgetstr (SCM y, SCM x) API;
SCM gucu_mvinchnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvinchstr(SCM y, SCM x) API;
SCM gucu_mvinnstr (SCM y, SCM x, SCM n) API;
SCM gucu_mvinstr (SCM y, SCM x) API;
SCM gucu_mvinwstr (SCM y, SCM x) API;
SCM gucu_mvin_wch (SCM y, SCM x) API;
SCM gucu_mvin_wchstr (SCM y, SCM x) API;
SCM gucu_mvwgetnstr (SCM win, SCM y, SCM x, SCM n) API;
SCM gucu_mvwgetstr (SCM win, SCM y, SCM x) API;
SCM gucu_mvwinchnstr (SCM y, SCM x, SCM win, SCM n) API;
SCM gucu_mvwinchstr (SCM y, SCM x, SCM win) API;
SCM gucu_mvwinnstr (SCM y, SCM x, SCM win, SCM n) API;
SCM gucu_mvwinstr (SCM y, SCM x, SCM win) API;
SCM gucu_mvwinwstr (SCM y, SCM x, SCM win) API;
SCM gucu_mvwin_wch (SCM win, SCM y, SCM x) API;
SCM gucu_mvwin_wchstr (SCM win, SCM y, SCM x) API;
SCM gucu_newterm (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_pair_content (SCM s_color) API;
SCM gucu_wattr_get (SCM win) API;
SCM gucu_wgetbkgrnd (SCM win) API;
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
SCM gucu_ACS_HLINE (void) API;
SCM gucu_ACS_LANTERN (void) API;
SCM gucu_ACS_LARROW (void) API;
SCM gucu_ACS_LLCORNER (void) API;
SCM gucu_ACS_LRCORNER (void) API;
SCM gucu_ACS_LTEE (void) API;
SCM gucu_ACS_PLMINUS (void) API;
SCM gucu_ACS_PLUS (void) API;
SCM gucu_ACS_RARROW (void) API;
SCM gucu_ACS_RTEE (void) API;
SCM gucu_ACS_S1 (void) API;
SCM gucu_ACS_S9 (void) API;
SCM gucu_ACS_TTEE (void) API;
SCM gucu_ACS_UARROW (void) API;
SCM gucu_ACS_ULCORNER (void) API;
SCM gucu_ACS_URCORNER (void) API;
SCM gucu_ACS_VLINE (void) API;

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


SCM gucu_LINES (void) API;
SCM gucu_COLS (void) API;
SCM gucu_COLORS (void) API;
SCM gucu_COLOR_PAIRS (void) API;
SCM gucu_TABSIZE (void) API;
SCM gucu_set_TABSIZE (SCM x) API;
SCM gucu_stdscr (void) API;

void gucu_init_special (void);

#endif /* not SPECIAL_H */
