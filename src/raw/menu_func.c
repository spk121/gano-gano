
#include <libguile.h>
#include <curses.h>
#include <menu.h>
#include <config.h>
#include "menu_func.h"
#include "type.h"
#include "menu_type.h"
#define _GNU_SOURCE
#define cstring_t cchar_t
SCM
gucu_set_menu_fore (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-fore");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "set-menu-fore");

	MENU *c_arg1 = _scm_to_menu (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = set_menu_fore (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_set_menu_back (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-back");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "set-menu-back");

	MENU *c_arg1 = _scm_to_menu (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = set_menu_back (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_set_menu_format (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-format");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-menu-format");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "set-menu-format");

	MENU *c_arg1 = _scm_to_menu (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = set_menu_format (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_set_menu_win (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-win");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "set-menu-win");

	MENU *c_arg1 = _scm_to_menu (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = set_menu_win (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_set_menu_sub (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-sub");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "set-menu-sub");

	MENU *c_arg1 = _scm_to_menu (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = set_menu_sub (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_post_menu (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "post-menu");

	MENU *c_arg1 = _scm_to_menu (arg1);

	int ret = post_menu (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_unpost_menu (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "unpost-menu");

	MENU *c_arg1 = _scm_to_menu (arg1);

	int ret = unpost_menu (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_set_menu_mark (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "set-menu-mark");
	SCM_ASSERT (scm_is_string (arg2), arg2, SCM_ARG2, "set-menu-mark");

	MENU *c_arg1 = _scm_to_menu (arg1);
	 char *c_arg2 = scm_to_locale_string (arg2);

	int ret = set_menu_mark (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_menu_win (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "menu-win");

	 MENU *c_arg1 = _scm_to_menu (arg1);

	WINDOW * ret = menu_win (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_menu_sub (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "menu-sub");

	 MENU *c_arg1 = _scm_to_menu (arg1);

	WINDOW * ret = menu_sub (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_menu_driver (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "menu-driver");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "menu-driver");

	MENU *c_arg1 = _scm_to_menu (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = menu_driver (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_item_count (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "item-count");

	 MENU *c_arg1 = _scm_to_menu (arg1);

	int ret = item_count (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_menu_mark (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "menu-mark");

	 MENU *c_arg1 = _scm_to_menu (arg1);

	char * ret = menu_mark (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}

SCM
gucu_menu_pattern (SCM arg1)
{
	SCM_ASSERT (_scm_is_menu (arg1), arg1, SCM_ARG1, "menu-pattern");

	 MENU *c_arg1 = _scm_to_menu (arg1);

	char * ret = menu_pattern (c_arg1);
	SCM s_ret = scm_from_locale_string (ret);

	return s_ret;
}


void 
gucu_menu_init_function ()
{
	scm_c_define_gsubr ("set-menu-fore", 2, 0, 0, gucu_set_menu_fore);
	scm_c_define_gsubr ("set-menu-back", 2, 0, 0, gucu_set_menu_back);
	scm_c_define_gsubr ("set-menu-format", 3, 0, 0, gucu_set_menu_format);
	scm_c_define_gsubr ("set-menu-win", 2, 0, 0, gucu_set_menu_win);
	scm_c_define_gsubr ("set-menu-sub", 2, 0, 0, gucu_set_menu_sub);
	scm_c_define_gsubr ("post-menu", 1, 0, 0, gucu_post_menu);
	scm_c_define_gsubr ("unpost-menu", 1, 0, 0, gucu_unpost_menu);
	scm_c_define_gsubr ("set-menu-mark", 2, 0, 0, gucu_set_menu_mark);
	scm_c_define_gsubr ("menu-win", 1, 0, 0, gucu_menu_win);
	scm_c_define_gsubr ("menu-sub", 1, 0, 0, gucu_menu_sub);
	scm_c_define_gsubr ("menu-driver", 2, 0, 0, gucu_menu_driver);
	scm_c_define_gsubr ("item-count", 1, 0, 0, gucu_item_count);
	scm_c_define_gsubr ("menu-mark", 1, 0, 0, gucu_menu_mark);
	scm_c_define_gsubr ("menu-pattern", 1, 0, 0, gucu_menu_pattern);
}
