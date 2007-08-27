#include <curses.h>
#include <libguile.h>
#include "type.h"
#include "special.h"

SCM
gucu_attr_get ()
{
  attr_t c_attrs;
  short c_pair;
  SCM s_list;
  int ret;

  ret = attr_get(&c_attrs, &c_pair, NULL);
  if (ret == OK)
    s_list = scm_list_2 (_scm_from_attr (c_attrs), scm_from_short (c_pair));
  else
    abort ();

  return s_list;
}


// FIXME: since color_content can return #f for nonsense values of COLOR,
// this will abort.  Fix in scheme wrapper. 
SCM
gucu_color_content (SCM s_color)
{
  SCM_ASSERT (scm_is_integer (s_color), s_color, SCM_ARG1, "color-content");

  int ret;
  short c_red, c_green, c_blue;
  SCM s_list;

  ret = color_content(scm_to_short (s_color), &c_red, &c_green, &c_blue);
  if (ret)
    {
      s_list = scm_list_3 (scm_from_short (c_red), 
			   scm_from_short (c_green),
			   scm_from_short (c_blue));
    }
  else
    abort ();

  return s_list; 
}

SCM
gucu_getnstr (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "getnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = getnstr (c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);
}

SCM
gucu_getstr ()
{
  char *c_str;
  SCM s_str;
  int ret;

  ret = getstr (c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);
}

SCM
gucu_inchnstr (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "inchnstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = inchnstr (c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_inchstr ()
{
  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = inchstr (c_str);
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_innstr (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "innstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = innstr (c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_instr ()
{
  char *c_str;
  SCM s_str;
  int ret;

  ret = instr (c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvgetnstr (SCM y, SCM x, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvgetnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvgetnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvgetnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvgetnstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);

}

SCM
gucu_mvgetstr (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvgetstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvgetstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvgetstr (scm_to_int (y), scm_to_int (x), c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);
}

SCM
gucu_mvinchnstr (SCM y, SCM x, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinchnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvinchnstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = mvinchnstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvinchstr(SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinchstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinchstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = mvinchstr (scm_to_int (y), scm_to_int (x), c_str);
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvinnstr (SCM y, SCM x, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvinnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvinnstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvinstr (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvinstr (scm_to_int (y), scm_to_int (x), c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvwinchnstr (SCM win, SCM y, SCM x, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinchnstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinchnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvwinchnstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = mvwinchnstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x),
		     c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvwinchstr (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinchstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinchstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinchstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = mvwinchstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), 
		     c_str);
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvwinnstr (SCM win, SCM y, SCM x, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinnstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvwinnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvwinnstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), 
		   c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_mvwinstr (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinnstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinnstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = mvwinstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), c_str);

  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_pair_content (SCM s_color)
{
  SCM_ASSERT (scm_is_integer (s_color), s_color, SCM_ARG1, "color-content");

  int ret;
  short c_fore, c_back;
  SCM s_list;

  ret = pair_content(scm_to_short (s_color), &c_fore, &c_back);
  if (ret)
    {
      s_list = scm_list_2 (scm_from_short (c_fore), 
			   scm_from_short (c_back));
    }
  else
    abort ();

  return s_list; 
}

SCM
gucu_wattr_get (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "wattr-get");

  attr_t c_attrs;
  short c_pair;
  SCM s_list;
  int ret;
  
  WINDOW *c_win = _scm_to_window (win);

  ret = wattr_get(c_win, &c_attrs, &c_pair, NULL);
  if (ret == OK)
    s_list = scm_list_2 (_scm_from_attr (c_attrs), scm_from_short (c_pair));
  else
    abort ();

  return s_list;
}


SCM
gucu_wgetnstr (SCM win, SCM n)
{
  SCM_ASSERT (scm_is_integer (win), win, SCM_ARG1, "wgetnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "wgetnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = wgetnstr (_scm_to_window (win), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);
}

SCM
gucu_wgetstr (SCM win)
{
  SCM_ASSERT (scm_is_integer (win), win, SCM_ARG1, "wgetnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = wgetstr (_scm_to_window (win), c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();
  
  return (s_str);
}

SCM
gucu_winchnstr (SCM win, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "winchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "winchnstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = winchnstr (_scm_to_window (win), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_winchstr (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "winchstr");

  chtype *c_str;
  SCM s_str;
  int ret;
  
  ret = winchstr (_scm_to_window (win), c_str);
  if (ret == OK)
    {
      s_str = _scm_from_chstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_winnstr (SCM win, SCM n)
{
  SCM_ASSERT (scm_is_integer (win), win, SCM_ARG1, "winnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "winnstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = winnstr (_scm_to_window (win), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_winstr (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "winstr");

  char *c_str;
  SCM s_str;
  int ret;

  ret = winstr (_scm_to_window (win), c_str);
  if (ret == OK)
    {
      s_str = scm_take_locale_string (c_str);
    }
  else
    abort ();

  return s_str;
}

SCM
gucu_getbegyx (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "getbegyx");

  int y, x;

  getbegyx (_scm_to_window (win), y, x);

  return (scm_list_2 (scm_from_int (y), scm_from_int (x)));
}

SCM
gucu_getmaxyx (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "getmaxyx");

  int y, x;

  getmaxyx (_scm_to_window (win), y, x);

  return (scm_list_2 (scm_from_int (y), scm_from_int (x)));
}

SCM
gucu_getparyx (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "getparyx");

  int y, x;

  getparyx (_scm_to_window (win), y, x);

  return (scm_list_2 (scm_from_int (y), scm_from_int (x)));
}

SCM
gucu_getyx (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "getyx");

  int y, x;

  getyx (_scm_to_window (win), y, x);

  return (scm_list_2 (scm_from_int (y), scm_from_int (x)));
}

// The ACS_XXX are supposed to be constants, but in ncurses, they
// are macros that have no value until after initscr().  So here
// they are being bound as scheme thunks.

SCM
gucu_ACS_ULCORNER ()
{
	chtype ret = ACS_ULCORNER;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_LLCORNER ()
{
	chtype ret = ACS_LLCORNER;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_URCORNER ()
{
	chtype ret = ACS_URCORNER;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_LRCORNER ()
{
	chtype ret = ACS_LRCORNER;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_LTEE ()
{
	chtype ret = ACS_LTEE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_RTEE ()
{
	chtype ret = ACS_RTEE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_BTEE ()
{
	chtype ret = ACS_BTEE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_TTEE ()
{
	chtype ret = ACS_TTEE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_HLINE ()
{
	chtype ret = ACS_HLINE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_VLINE ()
{
	chtype ret = ACS_VLINE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_PLUS ()
{
	chtype ret = ACS_PLUS;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_S1 ()
{
	chtype ret = ACS_S1;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_S9 ()
{
	chtype ret = ACS_S9;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_DIAMOND ()
{
	chtype ret = ACS_DIAMOND;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_CKBOARD ()
{
	chtype ret = ACS_CKBOARD;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_DEGREE ()
{
	chtype ret = ACS_DEGREE;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_PLMINUS ()
{
	chtype ret = ACS_PLMINUS;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_BULLET ()
{
	chtype ret = ACS_BULLET;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_LARROW ()
{
	chtype ret = ACS_LARROW;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_RARROW ()
{
	chtype ret = ACS_RARROW;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_DARROW ()
{
	chtype ret = ACS_DARROW;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_UARROW ()
{
	chtype ret = ACS_UARROW;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_BOARD ()
{
	chtype ret = ACS_BOARD;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_LANTERN ()
{
	chtype ret = ACS_LANTERN;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}

SCM
gucu_ACS_BLOCK ()
{
	chtype ret = ACS_BLOCK;
	SCM s_ret = _scm_from_chtype (ret);

	return s_ret;
}


void
gucu_init_special ()
{
  scm_c_define_gsubr ("attr-get", 0, 0, 0, gucu_attr_get);
  scm_c_define_gsubr ("color-content", 1, 0, 0, gucu_color_content);
  scm_c_define_gsubr ("getnstr", 1, 0, 0, gucu_getnstr);
  scm_c_define_gsubr ("getstr", 1, 0, 0, gucu_getstr);
  scm_c_define_gsubr ("inchnstr", 1, 0, 0, gucu_inchnstr);
  scm_c_define_gsubr ("inchstr", 1, 0, 0, gucu_inchstr);
  scm_c_define_gsubr ("innstr", 1, 0, 0, gucu_innstr);
  scm_c_define_gsubr ("instr", 0, 0, 0, gucu_instr);
  scm_c_define_gsubr ("mvgetnstr", 3, 0, 0, gucu_mvgetnstr);
  scm_c_define_gsubr ("mvgetstr", 2, 0, 0, gucu_mvgetstr);
  scm_c_define_gsubr ("mvinchnstr", 3, 0, 0, gucu_mvinchnstr);
  scm_c_define_gsubr ("mvinchstr", 2, 0, 0, gucu_mvinchstr);
  scm_c_define_gsubr ("mvinnstr", 3, 0, 0, gucu_mvinnstr);
  scm_c_define_gsubr ("mvinstr", 2, 0, 0, gucu_mvinstr);
  scm_c_define_gsubr ("mvwinchnstr", 4, 0, 0, gucu_mvwinchnstr);
  scm_c_define_gsubr ("mvwinchstr", 3, 0, 0, gucu_mvwinchstr);
  scm_c_define_gsubr ("mvwinnstr", 3, 0, 0, gucu_mvwinnstr);
  scm_c_define_gsubr ("mvwinstr", 3, 0, 0, gucu_mvwinstr);
  scm_c_define_gsubr ("pair-content", 1, 0, 0, gucu_pair_content);
  scm_c_define_gsubr ("wattr-get", 1, 0, 0, gucu_wattr_get);
  scm_c_define_gsubr ("wgetnstr", 2, 0, 0, gucu_wgetnstr);
  scm_c_define_gsubr ("wgetstr", 1, 0, 0, gucu_wgetstr);
  scm_c_define_gsubr ("winchnstr", 2, 0, 0, gucu_winchnstr);
  scm_c_define_gsubr ("winchstr", 1, 0, 0, gucu_winchstr);
  scm_c_define_gsubr ("winnstr", 2, 0, 0, gucu_winnstr);
  scm_c_define_gsubr ("winstr", 2, 0, 0, gucu_winstr);
  scm_c_define_gsubr ("getbegyz", 1, 0, 0, gucu_getbegyx);
  scm_c_define_gsubr ("getmaxyz", 1, 0, 0, gucu_getmaxyx);
  scm_c_define_gsubr ("getparyz", 1, 0, 0, gucu_getparyx);
  scm_c_define_gsubr ("getyz", 1, 0, 0, gucu_getmaxyx);
  scm_c_define_gsubr ("ACS-ULCORNER", 0, 0, 0, gucu_ACS_ULCORNER);
  scm_c_define_gsubr ("ACS-LLCORNER", 0, 0, 0, gucu_ACS_LLCORNER);
  scm_c_define_gsubr ("ACS-URCORNER", 0, 0, 0, gucu_ACS_URCORNER);
  scm_c_define_gsubr ("ACS-LRCORNER", 0, 0, 0, gucu_ACS_LRCORNER);
  scm_c_define_gsubr ("ACS-LTEE", 0, 0, 0, gucu_ACS_LTEE);
  scm_c_define_gsubr ("ACS-RTEE", 0, 0, 0, gucu_ACS_RTEE);
  scm_c_define_gsubr ("ACS-BTEE", 0, 0, 0, gucu_ACS_BTEE);
  scm_c_define_gsubr ("ACS-TTEE", 0, 0, 0, gucu_ACS_TTEE);
  scm_c_define_gsubr ("ACS-HLINE", 0, 0, 0, gucu_ACS_HLINE);
  scm_c_define_gsubr ("ACS-VLINE", 0, 0, 0, gucu_ACS_VLINE);
  scm_c_define_gsubr ("ACS-PLUS", 0, 0, 0, gucu_ACS_PLUS);
  scm_c_define_gsubr ("ACS-S1", 0, 0, 0, gucu_ACS_S1);
  scm_c_define_gsubr ("ACS-S9", 0, 0, 0, gucu_ACS_S9);
  scm_c_define_gsubr ("ACS-DIAMOND", 0, 0, 0, gucu_ACS_DIAMOND);
  scm_c_define_gsubr ("ACS-CKBOARD", 0, 0, 0, gucu_ACS_CKBOARD);
  scm_c_define_gsubr ("ACS-DEGREE", 0, 0, 0, gucu_ACS_DEGREE);
  scm_c_define_gsubr ("ACS-PLMINUS", 0, 0, 0, gucu_ACS_PLMINUS);
  scm_c_define_gsubr ("ACS-BULLET", 0, 0, 0, gucu_ACS_BULLET);
  scm_c_define_gsubr ("ACS-LARROW", 0, 0, 0, gucu_ACS_LARROW);
  scm_c_define_gsubr ("ACS-RARROW", 0, 0, 0, gucu_ACS_RARROW);
  scm_c_define_gsubr ("ACS-DARROW", 0, 0, 0, gucu_ACS_DARROW);
  scm_c_define_gsubr ("ACS-UARROW", 0, 0, 0, gucu_ACS_UARROW);
  scm_c_define_gsubr ("ACS-BOARD", 0, 0, 0, gucu_ACS_BOARD);
  scm_c_define_gsubr ("ACS-LANTERN", 0, 0, 0, gucu_ACS_LANTERN);
  scm_c_define_gsubr ("ACS-BLOCK", 0, 0, 0, gucu_ACS_BLOCK);
}
