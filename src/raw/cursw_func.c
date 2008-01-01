
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "cursw_func.h"
#include "type.h"
#include "typew.h"
#include "term.h"
#define _GNU_SOURCE
#define cstring_t cchar_t
SCM
gucu_addnwstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_wstring (arg1), arg1, SCM_ARG1, "addnwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "addnwstr");

	 wchar_t *c_arg1 = _scm_to_wstring (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = addnwstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_add_wch (SCM arg1)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "add-wch");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);

	int ret = add_wch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_add_wchnstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_cstring (arg1), arg1, SCM_ARG1, "add-wchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "add-wchnstr");

	 cstring_t *c_arg1 = _scm_to_cstring (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = add_wchnstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_add_wchstr (SCM arg1)
{
	SCM_ASSERT (_scm_is_cstring (arg1), arg1, SCM_ARG1, "add-wchstr");

	 cstring_t *c_arg1 = _scm_to_cstring (arg1);

	int ret = add_wchstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_addwstr (SCM arg1)
{
	SCM_ASSERT (_scm_is_wstring (arg1), arg1, SCM_ARG1, "addwstr");

	 wchar_t *c_arg1 = _scm_to_wstring (arg1);

	int ret = addwstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_bkgrnd (SCM arg1)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "bkgrnd");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);

	int ret = bkgrnd (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_bkgrndset (SCM arg1)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "bkgrndset");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);

	 bkgrndset (c_arg1);
	SCM s_ret = SCM_UNSPECIFIED;

	free (c_arg1);

	return s_ret;
}

SCM
gucu_border_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg5), arg5, SCM_ARG5, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg6), arg6, SCM_ARG6, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg7), arg7, SCM_ARG7, "border-set");
	SCM_ASSERT (_scm_is_cchar (arg8), arg8, 8, "border-set");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);
	 cchar_t *c_arg5 = _scm_to_cchar (arg5);
	 cchar_t *c_arg6 = _scm_to_cchar (arg6);
	 cchar_t *c_arg7 = _scm_to_cchar (arg7);
	 cchar_t *c_arg8 = _scm_to_cchar (arg8);

	int ret = border_set (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7, c_arg8);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);
	free (c_arg2);
	free (c_arg3);
	free (c_arg4);
	free (c_arg5);
	free (c_arg6);
	free (c_arg7);
	free (c_arg8);

	return s_ret;
}

SCM
gucu_box_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "box-set");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "box-set");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "box-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);

	int ret = box_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);
	free (c_arg3);

	return s_ret;
}

SCM
gucu_echo_wchar (SCM arg1)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "echo-wchar");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);

	int ret = echo_wchar (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_hline_set (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "hline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "hline-set");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = hline_set (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_ins_nwstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_wstring (arg1), arg1, SCM_ARG1, "ins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "ins-nwstr");

	 wchar_t *c_arg1 = _scm_to_wstring (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = ins_nwstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_ins_wch (SCM arg1)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "ins-wch");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);

	int ret = ins_wch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_ins_wstr (SCM arg1)
{
	SCM_ASSERT (_scm_is_wstring (arg1), arg1, SCM_ARG1, "ins-wstr");

	 wchar_t *c_arg1 = _scm_to_wstring (arg1);

	int ret = ins_wstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_mvaddnwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddnwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddnwstr");
	SCM_ASSERT (_scm_is_wstring (arg3), arg3, SCM_ARG3, "mvaddnwstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvaddnwstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wstring (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvaddnwstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvadd_wch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvadd-wch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvadd-wch");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "mvadd-wch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);

	int ret = mvadd_wch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvadd_wchnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvadd-wchnstr");
	SCM_ASSERT (_scm_is_cstring (arg3), arg3, SCM_ARG3, "mvadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvadd-wchnstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cstring_t *c_arg3 = _scm_to_cstring (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvadd_wchnstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvadd_wchstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvadd-wchstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvadd-wchstr");
	SCM_ASSERT (_scm_is_cstring (arg3), arg3, SCM_ARG3, "mvadd-wchstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cstring_t *c_arg3 = _scm_to_cstring (arg3);

	int ret = mvadd_wchstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvaddwstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvaddwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvaddwstr");
	SCM_ASSERT (_scm_is_wstring (arg3), arg3, SCM_ARG3, "mvaddwstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wstring (arg3);

	int ret = mvaddwstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvhline_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvhline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvhline-set");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "mvhline-set");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvhline-set");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvhline_set (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvins-nwstr");
	SCM_ASSERT (_scm_is_wstring (arg3), arg3, SCM_ARG3, "mvins-nwstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvins-nwstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wstring (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvins_nwstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvins_wch (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvins-wch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvins-wch");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "mvins-wch");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);

	int ret = mvins_wch (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvins_wstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvins-wstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvins-wstr");
	SCM_ASSERT (_scm_is_wstring (arg3), arg3, SCM_ARG3, "mvins-wstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wstring (arg3);

	int ret = mvins_wstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvvline_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvvline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvvline-set");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "mvvline-set");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvvline-set");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvvline_set (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

SCM
gucu_mvwaddnwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddnwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddnwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddnwstr");
	SCM_ASSERT (_scm_is_wstring (arg4), arg4, SCM_ARG4, "mvwaddnwstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwaddnwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wstring (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwaddnwstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwaddwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwaddwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwaddwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwaddwstr");
	SCM_ASSERT (_scm_is_wstring (arg4), arg4, SCM_ARG4, "mvwaddwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wstring (arg4);

	int ret = mvwaddwstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwadd_wch (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwadd-wch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwadd-wch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwadd-wch");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "mvwadd-wch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);

	int ret = mvwadd_wch (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwadd_wchnstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwadd-wchnstr");
	SCM_ASSERT (_scm_is_cstring (arg4), arg4, SCM_ARG4, "mvwadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwadd-wchnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cstring_t *c_arg4 = _scm_to_cstring (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwadd_wchnstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwadd_wchstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwadd-wchstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwadd-wchstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwadd-wchstr");
	SCM_ASSERT (_scm_is_cstring (arg4), arg4, SCM_ARG4, "mvwadd-wchstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cstring_t *c_arg4 = _scm_to_cstring (arg4);

	int ret = mvwadd_wchstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwhline_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwhline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwhline-set");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwhline-set");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "mvwhline-set");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwhline-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwhline_set (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwins-nwstr");
	SCM_ASSERT (_scm_is_wstring (arg4), arg4, SCM_ARG4, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwins-nwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wstring (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwins_nwstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwins_wch (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwins-wch");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwins-wch");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwins-wch");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "mvwins-wch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);

	int ret = mvwins_wch (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwins_wstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwins-wstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwins-wstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwins-wstr");
	SCM_ASSERT (_scm_is_wstring (arg4), arg4, SCM_ARG4, "mvwins-wstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wstring (arg4);

	int ret = mvwins_wstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_mvwvline_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwvline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwvline-set");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwvline-set");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "mvwvline-set");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwvline-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwvline_set (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

SCM
gucu_vline_set (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_cchar (arg1), arg1, SCM_ARG1, "vline-set");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "vline-set");

	 cchar_t *c_arg1 = _scm_to_cchar (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = vline_set (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

SCM
gucu_waddnwstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddnwstr");
	SCM_ASSERT (_scm_is_wstring (arg2), arg2, SCM_ARG2, "waddnwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "waddnwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wstring (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = waddnwstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_waddwstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "waddwstr");
	SCM_ASSERT (_scm_is_wstring (arg2), arg2, SCM_ARG2, "waddwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wstring (arg2);

	int ret = waddwstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wadd_wch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wadd-wch");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wadd-wch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);

	int ret = wadd_wch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wadd_wchnstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wadd-wchnstr");
	SCM_ASSERT (_scm_is_cstring (arg2), arg2, SCM_ARG2, "wadd-wchnstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wadd-wchnstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cstring_t *c_arg2 = _scm_to_cstring (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wadd_wchnstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wadd_wchstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wadd-wchstr");
	SCM_ASSERT (_scm_is_cstring (arg2), arg2, SCM_ARG2, "wadd-wchstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cstring_t *c_arg2 = _scm_to_cstring (arg2);

	int ret = wadd_wchstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wbkgrnd (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wbkgrnd");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wbkgrnd");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);

	int ret = wbkgrnd (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wbkgrndset (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wbkgrndset");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wbkgrndset");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);

	 wbkgrndset (c_arg1, c_arg2);
	SCM s_ret = SCM_UNSPECIFIED;

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wborder_set (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5, SCM arg6, SCM arg7, SCM arg8, SCM arg9)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg3), arg3, SCM_ARG3, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg4), arg4, SCM_ARG4, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg5), arg5, SCM_ARG5, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg6), arg6, SCM_ARG6, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg7), arg7, SCM_ARG7, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg8), arg8, 8, "wborder-set");
	SCM_ASSERT (_scm_is_cchar (arg9), arg9, 9, "wborder-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);
	 cchar_t *c_arg3 = _scm_to_cchar (arg3);
	 cchar_t *c_arg4 = _scm_to_cchar (arg4);
	 cchar_t *c_arg5 = _scm_to_cchar (arg5);
	 cchar_t *c_arg6 = _scm_to_cchar (arg6);
	 cchar_t *c_arg7 = _scm_to_cchar (arg7);
	 cchar_t *c_arg8 = _scm_to_cchar (arg8);
	 cchar_t *c_arg9 = _scm_to_cchar (arg9);

	int ret = wborder_set (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5, c_arg6, c_arg7, c_arg8, c_arg9);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);
	free (c_arg3);
	free (c_arg4);
	free (c_arg5);
	free (c_arg6);
	free (c_arg7);
	free (c_arg8);
	free (c_arg9);

	return s_ret;
}

SCM
gucu_wecho_wchar (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wecho-wchar");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wecho-wchar");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);

	int ret = wecho_wchar (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_whline_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "whline-set");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "whline-set");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "whline-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = whline_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wins_nwstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wins-nwstr");
	SCM_ASSERT (_scm_is_wstring (arg2), arg2, SCM_ARG2, "wins-nwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wins-nwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wstring (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wins_nwstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wins_wch (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wins-wch");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wins-wch");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);

	int ret = wins_wch (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wins_wstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wins-wstr");
	SCM_ASSERT (_scm_is_wstring (arg2), arg2, SCM_ARG2, "wins-wstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wstring (arg2);

	int ret = wins_wstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

SCM
gucu_wvline_set (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wvline-set");
	SCM_ASSERT (_scm_is_cchar (arg2), arg2, SCM_ARG2, "wvline-set");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wvline-set");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 cchar_t *c_arg2 = _scm_to_cchar (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wvline_set (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}


void 
gucu_init_function ()
{
	scm_c_define_gsubr ("addnwstr", 2, 0, 0, gucu_addnwstr);
	scm_c_define_gsubr ("add-wch", 1, 0, 0, gucu_add_wch);
	scm_c_define_gsubr ("add-wchnstr", 2, 0, 0, gucu_add_wchnstr);
	scm_c_define_gsubr ("add-wchstr", 1, 0, 0, gucu_add_wchstr);
	scm_c_define_gsubr ("addwstr", 1, 0, 0, gucu_addwstr);
	scm_c_define_gsubr ("bkgrnd", 1, 0, 0, gucu_bkgrnd);
	scm_c_define_gsubr ("bkgrndset", 1, 0, 0, gucu_bkgrndset);
	scm_c_define_gsubr ("border-set", 8, 0, 0, gucu_border_set);
	scm_c_define_gsubr ("box-set", 3, 0, 0, gucu_box_set);
	scm_c_define_gsubr ("echo-wchar", 1, 0, 0, gucu_echo_wchar);
	scm_c_define_gsubr ("hline-set", 2, 0, 0, gucu_hline_set);
	scm_c_define_gsubr ("ins-nwstr", 2, 0, 0, gucu_ins_nwstr);
	scm_c_define_gsubr ("ins-wch", 1, 0, 0, gucu_ins_wch);
	scm_c_define_gsubr ("ins-wstr", 1, 0, 0, gucu_ins_wstr);
	scm_c_define_gsubr ("mvaddnwstr", 4, 0, 0, gucu_mvaddnwstr);
	scm_c_define_gsubr ("mvadd-wch", 3, 0, 0, gucu_mvadd_wch);
	scm_c_define_gsubr ("mvadd-wchnstr", 4, 0, 0, gucu_mvadd_wchnstr);
	scm_c_define_gsubr ("mvadd-wchstr", 3, 0, 0, gucu_mvadd_wchstr);
	scm_c_define_gsubr ("mvaddwstr", 3, 0, 0, gucu_mvaddwstr);
	scm_c_define_gsubr ("mvhline-set", 4, 0, 0, gucu_mvhline_set);
	scm_c_define_gsubr ("mvins-nwstr", 4, 0, 0, gucu_mvins_nwstr);
	scm_c_define_gsubr ("mvins-wch", 3, 0, 0, gucu_mvins_wch);
	scm_c_define_gsubr ("mvins-wstr", 3, 0, 0, gucu_mvins_wstr);
	scm_c_define_gsubr ("mvvline-set", 4, 0, 0, gucu_mvvline_set);
	scm_c_define_gsubr ("mvwaddnwstr", 5, 0, 0, gucu_mvwaddnwstr);
	scm_c_define_gsubr ("mvwaddwstr", 4, 0, 0, gucu_mvwaddwstr);
	scm_c_define_gsubr ("mvwadd-wch", 4, 0, 0, gucu_mvwadd_wch);
	scm_c_define_gsubr ("mvwadd-wchnstr", 5, 0, 0, gucu_mvwadd_wchnstr);
	scm_c_define_gsubr ("mvwadd-wchstr", 4, 0, 0, gucu_mvwadd_wchstr);
	scm_c_define_gsubr ("mvwhline-set", 5, 0, 0, gucu_mvwhline_set);
	scm_c_define_gsubr ("mvwins-nwstr", 5, 0, 0, gucu_mvwins_nwstr);
	scm_c_define_gsubr ("mvwins-wch", 4, 0, 0, gucu_mvwins_wch);
	scm_c_define_gsubr ("mvwins-wstr", 4, 0, 0, gucu_mvwins_wstr);
	scm_c_define_gsubr ("mvwvline-set", 5, 0, 0, gucu_mvwvline_set);
	scm_c_define_gsubr ("vline-set", 2, 0, 0, gucu_vline_set);
	scm_c_define_gsubr ("waddnwstr", 3, 0, 0, gucu_waddnwstr);
	scm_c_define_gsubr ("waddwstr", 2, 0, 0, gucu_waddwstr);
	scm_c_define_gsubr ("wadd-wch", 2, 0, 0, gucu_wadd_wch);
	scm_c_define_gsubr ("wadd-wchnstr", 3, 0, 0, gucu_wadd_wchnstr);
	scm_c_define_gsubr ("wadd-wchstr", 2, 0, 0, gucu_wadd_wchstr);
	scm_c_define_gsubr ("wbkgrnd", 2, 0, 0, gucu_wbkgrnd);
	scm_c_define_gsubr ("wbkgrndset", 2, 0, 0, gucu_wbkgrndset);
	scm_c_define_gsubr ("wborder-set", 9, 0, 0, gucu_wborder_set);
	scm_c_define_gsubr ("wecho-wchar", 2, 0, 0, gucu_wecho_wchar);
	scm_c_define_gsubr ("whline-set", 3, 0, 0, gucu_whline_set);
	scm_c_define_gsubr ("wins-nwstr", 3, 0, 0, gucu_wins_nwstr);
	scm_c_define_gsubr ("wins-wch", 2, 0, 0, gucu_wins_wch);
	scm_c_define_gsubr ("wins-wstr", 2, 0, 0, gucu_wins_wstr);
	scm_c_define_gsubr ("wvline-set", 3, 0, 0, gucu_wvline_set);
}
