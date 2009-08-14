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

void gucu_cursw_init (void) API;

void
gucu_cursw_init ()
{
  gucu_cursw_init_function ();
  gucu_cursw_init_special ();
  gucu_cursw_init_constant ();
}
