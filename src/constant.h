
#ifndef CONSTANT_H
#define CONSTANT_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

void gucu_init_constant (void) API;
#endif /* not CONSTANT_H */
