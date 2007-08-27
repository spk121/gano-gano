#include <libguile.h>
#include <curses.h>
#include "function.h"
#include "special.h"
#include "constant.h"
#include <config.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

void gucu_init (void) API;

void
gucu_init ()
{
  gucu_init_function ();
  gucu_init_special ();
  gucu_init_constant ();
  gucu_init_type ();
}
