#ifndef MENU_SPEC_H
#define MENU_SPEC_H

#include <libguile.h>

SCM gucu_new_menu (SCM labels);
SCM gucu_free_menu (SCM menu);
SCM gucu_scale_menu (SCM menu);
SCM gucu_item_index (SCM menu);
SCM gucu_menu_spacing (SCM menu);
SCM gucu_menu_itemlen (SCM menu);


void gucu_menu_init_special (void);

#endif
