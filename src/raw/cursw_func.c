
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include "cursw_func.h"
#include "type.h"
#include "typew.h"
#include "term.h"
#define _GNU_SOURCE
#define cstring_t cchar_t


// 1: int bkgrnd
// 2: const cchar_t *
// 3: 
// 4: 
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

// 1: void bkgrndset
// 2: const cchar_t *
// 3: 
// 4: 
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

// 1: int border_set
// 2: const cchar_t *
// 3:  const cchar_t *
// 4:  const cchar_t *
// 5:  const cchar_t *
// 6:  const cchar_t *
// 7:  const cchar_t *
// 8:  const cchar_t *
// 9:  const cchar_t *
// 10: 
// 11: 
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

// 1: int box_set
// 2: WINDOW *
// 3:  const cchar_t *
// 4:  const cchar_t *
// 5: 
// 6: 
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

// 1: int hline_set
// 2: const cchar_t *
// 3:  int
// 4: 
// 5: 
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

// 1: int ins_nwstr
// 2: const wchar_t *
// 3:  int
// 4: 
// 5: 
SCM
gucu_ins_nwstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_wchar_string (arg1), arg1, SCM_ARG1, "ins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "ins-nwstr");

	 wchar_t *c_arg1 = _scm_to_wchar_string (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = ins_nwstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int ins_wch
// 2: const cchar_t *
// 3: 
// 4: 
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

// 1: int ins_wstr
// 2: const wchar_t *
// 3: 
// 4: 
SCM
gucu_ins_wstr (SCM arg1)
{
	SCM_ASSERT (_scm_is_wchar_string (arg1), arg1, SCM_ARG1, "ins-wstr");

	 wchar_t *c_arg1 = _scm_to_wchar_string (arg1);

	int ret = ins_wstr (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: int mvhline_set
// 2: int
// 3:  int
// 4:  const cchar_t *
// 5:  int
// 6: 
// 7: 
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

// 1: int mvins_nwstr
// 2: int
// 3:  int
// 4:  const wchar_t *
// 5:  int
// 6: 
// 7: 
SCM
gucu_mvins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvins-nwstr");
	SCM_ASSERT (_scm_is_wchar_string (arg3), arg3, SCM_ARG3, "mvins-nwstr");
	SCM_ASSERT (scm_is_integer (arg4), arg4, SCM_ARG4, "mvins-nwstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wchar_string (arg3);
	int c_arg4 = scm_to_int (arg4);

	int ret = mvins_nwstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvins_wch
// 2: int
// 3:  int
// 4:  const cchar_t *
// 5: 
// 6: 
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

// 1: int mvins_wstr
// 2: int
// 3:  int
// 4:  const wchar_t *
// 5: 
// 6: 
SCM
gucu_mvins_wstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "mvins-wstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvins-wstr");
	SCM_ASSERT (_scm_is_wchar_string (arg3), arg3, SCM_ARG3, "mvins-wstr");

	int c_arg1 = scm_to_int (arg1);
	int c_arg2 = scm_to_int (arg2);
	 wchar_t *c_arg3 = _scm_to_wchar_string (arg3);

	int ret = mvins_wstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int mvvline_set
// 2: int
// 3:  int
// 4:  const cchar_t *
// 5:  int
// 6: 
// 7: 
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

// 1: int mvwhline_set
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const cchar_t *
// 6:  int
// 7: 
// 8: 
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

// 1: int mvwins_nwstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const wchar_t *
// 6:  int
// 7: 
// 8: 
SCM
gucu_mvwins_nwstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4, SCM arg5)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwins-nwstr");
	SCM_ASSERT (_scm_is_wchar_string (arg4), arg4, SCM_ARG4, "mvwins-nwstr");
	SCM_ASSERT (scm_is_integer (arg5), arg5, SCM_ARG5, "mvwins-nwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wchar_string (arg4);
	int c_arg5 = scm_to_int (arg5);

	int ret = mvwins_nwstr (c_arg1, c_arg2, c_arg3, c_arg4, c_arg5);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwins_wch
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const cchar_t *
// 6: 
// 7: 
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

// 1: int mvwins_wstr
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const wchar_t *
// 6: 
// 7: 
SCM
gucu_mvwins_wstr (SCM arg1, SCM arg2, SCM arg3, SCM arg4)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "mvwins-wstr");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "mvwins-wstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "mvwins-wstr");
	SCM_ASSERT (_scm_is_wchar_string (arg4), arg4, SCM_ARG4, "mvwins-wstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);
	 wchar_t *c_arg4 = _scm_to_wchar_string (arg4);

	int ret = mvwins_wstr (c_arg1, c_arg2, c_arg3, c_arg4);
	SCM s_ret = scm_from_int (ret);

	free (c_arg4);

	return s_ret;
}

// 1: int mvwvline_set
// 2: WINDOW *
// 3:  int
// 4:  int
// 5:  const cchar_t *
// 6:  int
// 7: 
// 8: 
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

/* Return all the video attributes supported by the terminal */
SCM
gucu_term_attrs ()
{
  attr_t ret;
  SCM s_ret;

  ret = term_attrs ();
  s_ret = _scm_from_attr (ret);

  return s_ret;
}



// 1: int unget_wch
// 2: const wchar_t
// 3: 
// 4: 
SCM
gucu_unget_wch (SCM arg1)
{
	SCM_ASSERT (_scm_is_wchar (arg1), arg1, SCM_ARG1, "unget-wch");

	const wchar_t c_arg1 = _scm_to_wchar (arg1);

	int ret = unget_wch (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int vline_set
// 2: const cchar_t *
// 3:  int
// 4: 
// 5: 
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

/* Write the wide string to the given window */
SCM
gucu_waddnwstr (SCM win, SCM wstr, SCM n)
{
  WINDOW *c_win;
  wchar_t *c_wstr;
  int c_n, ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%waddnwstr");
  SCM_ASSERT (_scm_is_wchar_string (wstr), wstr, SCM_ARG2, "%waddnwstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%waddnwstr");

  c_win = _scm_to_window (win);
  c_wstr = _scm_to_wchar_string (wstr);
  c_n = scm_to_int (n);

  ret = waddnwstr (c_win, c_wstr, c_n);

  free (c_wstr);

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

/* Add a wide character to a given window */
SCM
gucu_wadd_wch (SCM win, SCM wch)
{
  WINDOW *c_win;
  cchar_t *c_wch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wadd-wch");
  SCM_ASSERT (_scm_is_cchar (wch), wch, SCM_ARG2, "%wadd-wch");
  
  c_win = _scm_to_window (win);
  c_wch = _scm_to_cchar (wch);

  ret = wadd_wch (c_win, c_wch);
  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}


/* Copy the array of complex characters into the window at the current
   cursor positions.  If N=-1 try to copy all the characters, but, no
   more than one line's worth.  If N > -1, try to copy N characters,
   but, no more than one line's worth. */
SCM
gucu_wadd_wchnstr (SCM win, SCM wchstr, SCM n)
{
  WINDOW *c_win;
  cstring_t *c_wchstr;
  int c_n, ret;
	
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wadd-wchnstr");
  SCM_ASSERT (_scm_is_cstring (wchstr), wchstr, SCM_ARG2, "%wadd-wchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "%wadd-wchnstr");

  c_win = _scm_to_window (win);
  c_wchstr = _scm_to_cstring (wchstr);
  c_n = scm_to_int (n);

  ret = wadd_wchnstr (c_win, c_wchstr, c_n);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;
}

// 1: int wbkgrnd
// 2: WINDOW *
// 3:  const cchar_t *
// 4: 
// 5: 
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

// 1: void wbkgrndset
// 2: WINDOW *
// 3:  const cchar_t *
// 4: 
// 5: 
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

// 1: int wborder_set
// 2: WINDOW *
// 3:  const cchar_t *
// 4:  const cchar_t *
// 5:  const cchar_t *
// 6:  const cchar_t *
// 7:  const cchar_t *
// 8:  const cchar_t *
// 9:  const cchar_t *
// 10:  const cchar_t *
// 11: 
// 12: 
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

/* Write a complex haracter to a window, and then refresh that
   window */
SCM
gucu_wecho_wchar (SCM win, SCM ch)
{
  WINDOW *c_win;
  cchar_t *c_ch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wecho-wchar");
  SCM_ASSERT (_scm_is_cchar (ch), ch, SCM_ARG2, "%wecho-wchar");

  c_win = _scm_to_window (win);
  c_ch = _scm_to_cchar (ch);
  
  ret = wecho_wchar (c_win, c_ch);
  if (ret == ERR)
    return SCM_BOOL_F;
  
  return SCM_BOOL_T;

}

// 1: int whline_set
// 2: WINDOW *
// 3:  const cchar_t *
// 4:  int
// 5: 
// 6: 
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

// 1: int wins_nwstr
// 2: WINDOW *
// 3:  const wchar_t *
// 4:  int
// 5: 
// 6:  
SCM
gucu_wins_nwstr (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wins-nwstr");
	SCM_ASSERT (_scm_is_wchar_string (arg2), arg2, SCM_ARG2, "wins-nwstr");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "wins-nwstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wchar_string (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = wins_nwstr (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int wins_wch
// 2: WINDOW *
// 3:  const cchar_t *
// 4: 
// 5: 
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

// 1: int wins_wstr
// 2: WINDOW *
// 3:  const wchar_t *
// 4: 
// 5: 
SCM
gucu_wins_wstr (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_window (arg1), arg1, SCM_ARG1, "wins-wstr");
	SCM_ASSERT (_scm_is_wchar_string (arg2), arg2, SCM_ARG2, "wins-wstr");

	WINDOW *c_arg1 = _scm_to_window (arg1);
	 wchar_t *c_arg2 = _scm_to_wchar_string (arg2);

	int ret = wins_wstr (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	free (c_arg2);

	return s_ret;
}

// 1: int wvline_set
// 2: WINDOW *
// 3:  const cchar_t *
// 4:  int
// 5: 
// 6: 
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
gucu_cursw_init_function ()
{
	scm_c_define_gsubr ("bkgrnd", 1, 0, 0, gucu_bkgrnd);
	scm_c_define_gsubr ("bkgrndset", 1, 0, 0, gucu_bkgrndset);
	scm_c_define_gsubr ("border-set", 8, 0, 0, gucu_border_set);
	scm_c_define_gsubr ("box-set", 3, 0, 0, gucu_box_set);
	scm_c_define_gsubr ("hline-set", 2, 0, 0, gucu_hline_set);
	scm_c_define_gsubr ("ins-nwstr", 2, 0, 0, gucu_ins_nwstr);
	scm_c_define_gsubr ("ins-wch", 1, 0, 0, gucu_ins_wch);
	scm_c_define_gsubr ("ins-wstr", 1, 0, 0, gucu_ins_wstr);
	scm_c_define_gsubr ("mvhline-set", 4, 0, 0, gucu_mvhline_set);
	scm_c_define_gsubr ("mvins-nwstr", 4, 0, 0, gucu_mvins_nwstr);
	scm_c_define_gsubr ("mvins-wch", 3, 0, 0, gucu_mvins_wch);
	scm_c_define_gsubr ("mvins-wstr", 3, 0, 0, gucu_mvins_wstr);
	scm_c_define_gsubr ("mvvline-set", 4, 0, 0, gucu_mvvline_set);
	scm_c_define_gsubr ("mvwhline-set", 5, 0, 0, gucu_mvwhline_set);
	scm_c_define_gsubr ("mvwins-nwstr", 5, 0, 0, gucu_mvwins_nwstr);
	scm_c_define_gsubr ("mvwins-wch", 4, 0, 0, gucu_mvwins_wch);
	scm_c_define_gsubr ("mvwins-wstr", 4, 0, 0, gucu_mvwins_wstr);
	scm_c_define_gsubr ("mvwvline-set", 5, 0, 0, gucu_mvwvline_set);
	scm_c_define_gsubr ("term-attrs", 0, 0, 0, gucu_term_attrs);
	scm_c_define_gsubr ("unget-wch", 1, 0, 0, gucu_unget_wch);
	scm_c_define_gsubr ("vline-set", 2, 0, 0, gucu_vline_set);
	scm_c_define_gsubr ("%waddnwstr", 3, 0, 0, gucu_waddnwstr);
	scm_c_define_gsubr ("%wadd-wch", 2, 0, 0, gucu_wadd_wch);
	scm_c_define_gsubr ("%wadd-wchnstr", 3, 0, 0, gucu_wadd_wchnstr);
	scm_c_define_gsubr ("wbkgrnd", 2, 0, 0, gucu_wbkgrnd);
	scm_c_define_gsubr ("wbkgrndset", 2, 0, 0, gucu_wbkgrndset);
	scm_c_define_gsubr ("wborder-set", 9, 0, 0, gucu_wborder_set);
	scm_c_define_gsubr ("%wecho-wchar", 2, 0, 0, gucu_wecho_wchar);
	scm_c_define_gsubr ("whline-set", 3, 0, 0, gucu_whline_set);
	scm_c_define_gsubr ("wins-nwstr", 3, 0, 0, gucu_wins_nwstr);
	scm_c_define_gsubr ("wins-wch", 2, 0, 0, gucu_wins_wch);
	scm_c_define_gsubr ("wins-wstr", 2, 0, 0, gucu_wins_wstr);
	scm_c_define_gsubr ("wvline-set", 3, 0, 0, gucu_wvline_set);
}
