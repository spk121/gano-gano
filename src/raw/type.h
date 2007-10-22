#ifndef TYPE_H
#define TYPE_H 1

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include <config.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif


int _scm_is_attr (SCM x);
attr_t _scm_to_attr (SCM x) ;
SCM _scm_from_attr (attr_t x);

SCM _scm_from_cchar (cchar_t *x);
int _scm_is_cchar (SCM x);
cchar_t *_scm_to_cchar (SCM x);

cchar_t *_scm_to_cstring (SCM x);
SCM _scm_from_cstring (cchar_t *x);
int _scm_is_cstring (SCM x);

int _scm_is_chstring (SCM x);
chtype *_scm_to_chstring (SCM x);
SCM _scm_from_chstring (chtype *x);

int _scm_is_chtype (SCM x);
chtype _scm_to_chtype (SCM x);
SCM _scm_from_chtype (chtype x);

int  _scm_is_file (SCM x);
FILE *_scm_to_file (SCM x);
SCM _scm_from_file (FILE *x);

int _scm_is_mevent (SCM x);
MEVENT *_scm_to_mevent (SCM x);
SCM _scm_from_mevent (MEVENT *);

int  _scm_is_screen (SCM x);
SCREEN *_scm_to_screen (SCM x);
SCM _scm_from_screen (SCREEN *x);

int _scm_is_voidstring (SCM x);
void *_scm_to_voidstring (SCM x);
SCM _scm_from_voidstring (void *x);

int _scm_is_wchar (SCM x);
SCM _scm_from_wchar (wchar_t x);
wchar_t _scm_to_wchar (SCM x);

int _scm_is_wstring (SCM x);
SCM _scm_from_wstring (wchar_t *x);
wchar_t *_scm_to_wstring (SCM x);

int _scm_is_window (SCM x);
WINDOW *_scm_to_window (SCM x);
SCM _scm_from_window (WINDOW *x);

SCM gucu_is_window_p (SCM x) API;
SCM gucu_fopen(SCM path, SCM mode) API; 
SCM gucu_fclose(SCM file) API;

void gucu_init_type (void) API;

#endif /* not TYPE_H */
