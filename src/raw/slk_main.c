#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "slk_func.h"

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

void gucu_slk_init (void) API;

void
gucu_slk_init ()
{
  gucu_slk_init_function ();
}
