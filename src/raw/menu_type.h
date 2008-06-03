#ifndef MENU_TYPE_H
#define MENU_TYPE_H

#include <libguile.h>
#include <menu.h>

extern scm_t_bits menu_tag;

int _scm_is_menu (SCM x);
MENU *_scm_to_menu (SCM x);
SCM _scm_from_menu (MENU *x);

SCM gucu_is_menu_p (SCM x) API;
void gucu_menu_init_type (void);

#endif
