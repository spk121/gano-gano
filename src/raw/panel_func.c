
#include <libguile.h>
#include <curses.h>
#include <panel.h>
#include <config.h>
#include "panel_func.h"
#include "type.h"
#include "panel_type.h"
#define _GNU_SOURCE
#define cstring_t cchar_t
SCM
gucu_new_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "new-panel");

	WINDOW *c_arg1 = _scm_to_window (arg1);

	PANEL * ret = new_panel (c_arg1);
	SCM s_ret = _scm_from_panel (ret);

	return s_ret;
}

SCM
gucu_bottom_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "bottom-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = bottom_panel (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_top_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "top-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = top_panel (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_show_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "show-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = show_panel (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_update_panels ()
{
	 update_panels ();
	SCM s_ret = SCM_UNSPECIFIED;

	return s_ret;
}

SCM
gucu_hide_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "hide-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = hide_panel (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_panel_window (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "panel-window");

	 PANEL *c_arg1 = _scm_to_panel (arg1);

	WINDOW * ret = panel_window (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

SCM
gucu_replace_panel (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "replace-panel");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "replace-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = replace_panel (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_move_panel (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "move-panel");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "move-panel");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "move-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = move_panel (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_panel_hidden (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "panel-hidden");

	 PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = panel_hidden (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

SCM
gucu_del_panel (SCM arg1)
{
	SCM_ASSERT (_scm_is_panel (arg1), arg1, SCM_ARG1, "del-panel");

	PANEL *c_arg1 = _scm_to_panel (arg1);

	int ret = del_panel (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}


void 
gucu_panel_init_function ()
{
	scm_c_define_gsubr ("new-panel", 1, 0, 0, gucu_new_panel);
	scm_c_define_gsubr ("bottom-panel", 1, 0, 0, gucu_bottom_panel);
	scm_c_define_gsubr ("top-panel", 1, 0, 0, gucu_top_panel);
	scm_c_define_gsubr ("show-panel", 1, 0, 0, gucu_show_panel);
	scm_c_define_gsubr ("update-panels", 0, 0, 0, gucu_update_panels);
	scm_c_define_gsubr ("hide-panel", 1, 0, 0, gucu_hide_panel);
	scm_c_define_gsubr ("panel-window", 1, 0, 0, gucu_panel_window);
	scm_c_define_gsubr ("replace-panel", 2, 0, 0, gucu_replace_panel);
	scm_c_define_gsubr ("move-panel", 3, 0, 0, gucu_move_panel);
	scm_c_define_gsubr ("panel-hidden", 1, 0, 0, gucu_panel_hidden);
	scm_c_define_gsubr ("del-panel", 1, 0, 0, gucu_del_panel);
}
