#ifndef PANEL_TYPE_H
#define PANEL_TYPE_H

#include <libguile.h>
#include <panel.h>

int _scm_is_panel (SCM x);
PANEL *_scm_to_panel (SCM x);
SCM _scm_from_panel (PANEL *x);

SCM gucu_is_panel_p (SCM x) API;

void gucu_panel_init_type (void);

#endif
