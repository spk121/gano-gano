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


int _scm_is_wchar (SCM x);
SCM _scm_from_wchar (wchar_t x);
wchar_t _scm_to_wchar (SCM x);

int _scm_is_wchar_string (SCM x);
SCM _scm_from_wchar_string (wchar_t *x);
wchar_t *_scm_to_wchar_string (SCM x);

int _scm_is_wint (SCM x);
SCM _scm_from_wint (wint_t x);
wint_t _scm_to_wint (SCM x);

int _scm_is_wint_string (SCM x);
SCM _scm_from_wint_string (wint_t *x);
wint_t *_scm_to_wint_string (SCM x);

SCM _scm_from_cchar (cchar_t *x);
int _scm_is_cchar (SCM x);
cchar_t *_scm_to_cchar (SCM x);

cchar_t *_scm_to_cstring (SCM x);
SCM _scm_from_cstring (cchar_t *x);
int _scm_is_cstring (SCM x);



#endif /* not TYPEW_H */
