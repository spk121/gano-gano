#ifndef ADD_WCH_H
#define ADD_WCH_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_add_wch (SCM s_wch) API;
SCM gnc_wadd_wch (SCM win, SCM s_wch) API;
SCM gnc_mvadd_wch (SCM y, SCM x, SCM s_wch) API;
SCM gnc_mvwadd_wch (SCM win, SCM y, SCM x, SCM s_wch) API;
SCM gnc_echo_wchar (SCM s_wch) API;
SCM gnc_wecho_wchar (SCM win, SCM s_wch) API;

void _gnc_init_add_wch (void);

#endif /* not ADD_WCH_H */
