// add_wch.c -- add a complex character to a curses window

// $Id: add_wch.c,v 1.1 2007/08/12 23:52:39 spike_gran Exp $

#include <curses.h>
#include <libguile.h>

#include "add_wch.h"
#include "core.h"
#include "defines.h"

#include "type_window.h"



SCM
gnc_add_wch (SCM s_wch)
{
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG1, "add-wch");

  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);

  ret = add_wch (c_wch);
  free (c_wch);

  return _gnc_is_ok (ret);
}

SCM
gnc_wadd_wch (SCM win, SCM s_wch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, "wadd-wch");
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG2, "wadd-wch");

  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);

  ret = wadd_wch (_gnc_window_data (win), c_wch);
  free (c_wch);

  return _gnc_is_ok (ret);
}

SCM
gnc_mvadd_wch (SCM y, SCM x, SCM s_wch)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvadd-wch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvadd-wch");
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG3, "wadd-wch");
  
  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);
  ret = mvadd_wch (scm_to_int (y),
		   scm_to_int (x),
		   c_wch);
  free (c_wch);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_mvwadd_wch (SCM win, SCM y, SCM x, SCM s_wch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "mvwadd-wch");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwadd-wch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwadd-wch");
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG4, "mvwadd-wch");
  
  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);
  ret = mvwadd_wch (_gnc_window_data (win),
		    scm_to_int (y),
		    scm_to_int (x),
		    c_wch);
  free (c_wch);
  
  return _gnc_is_ok (ret);
}

SCM
gnc_echo_wchar (SCM s_wch)
{
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG1, "echo-wchar");

  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);

  ret = echo_wchar (c_wch);
  free (c_wch);

  return _gnc_is_ok (ret);
}

SCM
gnc_wecho_wchar (SCM win, SCM s_wch)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), win, SCM_ARG1, 
	      "wecho-wchar");
  SCM_ASSERT (_gnc_is_cchar (s_wch), s_wch, SCM_ARG2, "wecho-wchar");

  cchar_t *c_wch;
  int ret;

  c_wch = _gnc_to_cchar (s_wch);

  ret = wadd_wch (_gnc_window_data (win), c_wch);
  free (c_wch);

  return _gnc_is_ok (ret);
}

void
_gnc_init_add_wch ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);

  scm_c_define_gsubr ("add-wch", 1, 0, 0, gnc_add_wch);
  scm_c_define_gsubr ("wadd-wch", 2, 0, 0, gnc_wadd_wch);
  scm_c_define_gsubr ("mvadd-wch", 3, 0, 0, gnc_mvadd_wch);
  scm_c_define_gsubr ("mvwadd-wch", 4, 0, 0, gnc_mvwadd_wch);
  scm_c_define_gsubr ("echo-wchar", 1, 0, 0, gnc_echo_wchar);
  scm_c_define_gsubr ("wecho-wchar", 2, 0, 0, gnc_wecho_wchar);
}
