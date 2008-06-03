
#include <curses.h>
#include <libguile.h>
#include <wchar.h>
#include "cursw_const.h"
#include "type.h"
#include "typew.h"
#define _GNU_SOURCE
SCM gucu_WEOF;

void 
gucu_cursw_init_constant ()
{
	gucu_WEOF = scm_permanent_object (scm_c_define ("WEOF", scm_from_uint (WEOF)));
}
