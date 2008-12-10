#ifndef CURS_PORT_H
#define CURS_PORT_H 1

#include <libguile.h>
#include <config.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

SCM gucu_newterm (SCM a, SCM b, SCM c) API;

void gucu_init_port (void);

#endif /* not CURS_PORT_H */
