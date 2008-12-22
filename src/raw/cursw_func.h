
#ifndef CURSW_FUNC_H
#define CURSW_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t

SCM gucu_ins_nwstr (SCM arg1, SCM arg2) API;
SCM gucu_ins_wch (SCM arg1) API;
SCM gucu_ins_wstr (SCM arg1) API;
SCM gucu_mvins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4) API;
SCM gucu_mvins_wch (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_mvins_wstr (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_mvwins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5) API;
SCM gucu_mvwins_wch (SCM arg1, SCM arg2, SCM arg3, SCM arg4) API;
SCM gucu_mvwins_wstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4) API;
SCM gucu_term_attrs (void) API;
SCM gucu_unget_wch (SCM arg1) API;
SCM gucu_waddnwstr (SCM win, SCM wstr, SCM n) API;
SCM gucu_wadd_wch (SCM arg1, SCM arg2) API;
SCM gucu_wadd_wchnstr (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_wbkgrnd (SCM arg1, SCM arg2) API;
SCM gucu_wbkgrndset (SCM arg1, SCM arg2) API;
SCM gucu_wborder_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8, SCM arg9) API;
SCM gucu_wecho_wchar (SCM arg1, SCM arg2) API;
SCM gucu_whline_set (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_wins_nwstr (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_wins_wch (SCM arg1, SCM arg2) API;
SCM gucu_wins_wstr (SCM arg1, SCM arg2) API;
SCM gucu_wvline_set (SCM arg1, SCM arg2, SCM arg3) API;

void gucu_cursw_init_function (void) API;
#endif

