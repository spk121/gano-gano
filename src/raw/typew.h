#ifndef TYPEW_H
#define TYPEW_H 1

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include <config.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif


SCM _scm_from_cchar (cchar_t *x);
int _scm_is_cchar (SCM x);
cchar_t *_scm_to_cchar (SCM x);

cchar_t *_scm_to_cstring (SCM x);
SCM _scm_from_cstring (cchar_t *x);
int _scm_is_cstring (SCM x);

#endif /* not TYPEW_H */
