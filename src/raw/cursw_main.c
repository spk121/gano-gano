#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "cursw_func.h"
#include "cursw_spec.h"
#include "cursw_const.h"

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
}
