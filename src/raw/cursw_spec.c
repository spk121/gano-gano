#include <curses.h>
#include <libguile.h>
#include <config.h>
#include "type.h"
#include "typew.h"
#include "cursw_spec.h"

/* The Cygwin version of NCurses does not properly declare the
 * acs_map, which is the array that holds the line-drawing
 * characters. */
#ifdef ENABLE_ACS_MAP_FIX
  extern NCURSES_EXPORT_VAR(chtype*) _nc_acs_map(void);
  #define acs_map (_nc_acs_map())
#endif

#define MAXLEN 1000

/* Return the character use for erasing */
SCM
gucu_erasewchar ()
{
  wchar_t wch;

  int ret = erasewchar (&wch);

  if (ret == OK)
    return _scm_from_wchar (wch);
  else
    return SCM_BOOL_F;
}
    

SCM
gucu_getn_wstr (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "getn-wstr");
  
  wint_t *c_str;
  SCM s_str;
  
  c_str = (wint_t *) scm_malloc (sizeof (wint_t) * (scm_to_int (n) + 1));
  c_str[scm_to_int (n)] = 0;

  int ret = getn_wstr (c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_wint_string (c_str);
    }
  else
    abort ();

  free (c_str);
  
  return (s_str);
}


SCM
gucu_get_wch ()
{
  wint_t wch = 0;

  int ret = get_wch (&wch);
  return scm_list_2 (scm_from_int (ret), _scm_from_wint (wch));
}

SCM
gucu_innwstr (SCM n)
{
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG1, "innwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (scm_to_int (n) + 1));

  ret = innwstr (c_str, scm_to_int (n) + 1);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}

SCM
gucu_inwstr (void)
{
  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (COLS + 1));
  ret = inwstr (c_str);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  return s_str;
}


/* Return the current line kill character */
SCM
gucu_killwchar ()
{
  wchar_t wch;

  int ret = erasewchar (&wch);

  if (ret == OK)
    return _scm_from_wchar (wch);
  else
    return SCM_BOOL_F;
}

SCM
gucu_mvgetn_wstr (SCM y, SCM x, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvgetn-wstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvgetn-wstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvgetn-wstr");

  wint_t *c_str;
  SCM s_str;

  c_str = (wint_t *) scm_malloc (sizeof (wint_t) * (scm_to_int (n) + 1));

  int ret = mvgetn_wstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));
  c_str[scm_to_int (n)] = 0;

  if (ret == OK)
    {
      s_str = _scm_from_wint_string (c_str);
      free (c_str); 
    }
  else
    abort ();

  return (s_str);
}

SCM
gucu_mvget_wch (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvget-wch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvget-wch");
  wint_t wch = 0;

  int ret = mvget_wch (scm_to_int (y), scm_to_int (x), &wch);
  return scm_list_2 (scm_from_int (ret), _scm_from_wint (wch));

}

SCM
gucu_mvwgetn_wstr (SCM win, SCM y, SCM x, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwgetn-wstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwgetn-wstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwgetn-wstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvwgetn-wstr");

  wint_t *c_str;
  SCM s_str;

  c_str = (wint_t *) scm_malloc (sizeof (wint_t) * (scm_to_int (n) + 1));
  c_str[scm_to_int (n)] = 0;

  int ret = mvwgetn_wstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n));
  if (ret == OK)
    {
      s_str = _scm_from_wint_string (c_str);
    }
  else
    abort ();

  free (c_str);
  
  return (s_str);
}

SCM
gucu_mvwget_wch (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwget-wch");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwget-wch");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwget-wch");

  wint_t wch = 0;

  int ret = mvwget_wch (_scm_to_window (win), scm_to_int (y), scm_to_int (x), &wch);
  return scm_list_2 (scm_from_int (ret), _scm_from_wint (wch));

}

SCM
gucu_mvinnwstr (SCM y, SCM x, SCM n)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinnwstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinnwstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG3, "mvinnwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (scm_to_int (n) + 1));

  ret = mvinnwstr (scm_to_int (y), scm_to_int (x), c_str, scm_to_int (n) + 1);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}

SCM
gucu_mvinwstr (SCM y, SCM x)
{
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG1, "mvinwstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG2, "mvinwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (COLS + 1));

  ret = mvinwstr (scm_to_int (y), scm_to_int (x), c_str);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}


SCM
gucu_mvwinwstr (SCM win, SCM y, SCM x)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinwstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinwstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;
  
  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (COLS + 1));

  ret = mvwinwstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), c_str);

  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}


SCM
gucu_mvwinnwstr (SCM win, SCM y, SCM x, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "mvwinnwstr");
  SCM_ASSERT (scm_is_integer (y), y, SCM_ARG2, "mvwinnwstr");
  SCM_ASSERT (scm_is_integer (x), x, SCM_ARG3, "mvwinnwstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG4, "mvwinnstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (scm_to_int (n) + 1));

  ret = mvwinnwstr (_scm_to_window (win), scm_to_int (y), scm_to_int (x), 
		   c_str, scm_to_int (n) + 1);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}

/* Return the given window's current background character and attribute */
SCM
gucu_wgetbkgrnd (SCM win)
{
  cchar_t wch;
  SCM s_wch;
  int ret;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%wgetbkgrnd");

  ret = wgetbkgrnd(_scm_to_window (win), &wch);
  if (ret == OK)
    s_wch = _scm_from_cchar (&wch);
  else
    abort();

  return s_wch;
}

SCM
gucu_wgetn_wstr (SCM win, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "wgetn-wstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "wgetn-wstr");

  wint_t *c_str;
  SCM s_str;

  c_str = (wint_t *) scm_malloc (sizeof (wint_t) * (scm_to_int (n) + 1));

  int ret = wgetn_wstr (_scm_to_window (win), c_str, scm_to_int (n));
  c_str[scm_to_int (n)] = (wint_t) 0;

  if (ret == OK)
    {
      s_str = _scm_from_wint_string (c_str);
    }
  else
    abort ();

  free (c_str);
  
  return (s_str);
}

SCM
gucu_wget_wch (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "wget-wch");

  wint_t wch = 0;

  int ret = wget_wch (_scm_to_window (win), &wch);
  return scm_list_2 (scm_from_int (ret), _scm_from_wint (wch));
}

SCM
gucu_winnwstr (SCM win, SCM n)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "winnwstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "winnwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (scm_to_int (n) + 1));

  ret = winnwstr (_scm_to_window (win), c_str, scm_to_int (n) + 1);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}

SCM
gucu_winwstr (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "winwstr");

  wchar_t *c_str;
  SCM s_str;
  int ret;

  c_str = (wchar_t *) scm_malloc (sizeof (wchar_t) * (COLS + 1));

  ret = winwstr (_scm_to_window (win), c_str);
  if (ret != ERR)
    {
      s_str = _scm_from_wchar_string (c_str);
    }
  else
    abort ();

  free (c_str);

  return s_str;
}


/* extract a complex rendered character from the window */
SCM
gucu_win_wch (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%win-wch");

  int ret;
  cchar_t ch;
  
  ret = win_wch (_scm_to_window (win), &ch);
  
  return _scm_from_cchar (&ch);
}

/* Get an array of complex characters and renditions from a curses window */
SCM
gucu_win_wchnstr (SCM win, SCM n)
{
  cchar_t *c_str;
  SCM s_str;
  int c_n;
  int ret;
  int y, x;

  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "%win-wchnstr");
  SCM_ASSERT (scm_is_integer (n), n, SCM_ARG2, "%win-wchnstr");
  
  c_n = scm_to_int (n);
  if (c_n == -1)
    {
      getmaxyx (_scm_to_window (win), y, x);
      c_n = x;
    }
  if (c_n <= 0)
    scm_out_of_range ("%win-wchnstr", n);

  c_str = (cchar_t *) scm_malloc (sizeof(cchar_t) * (c_n + 1));

  ret = win_wchnstr (_scm_to_window (win), c_str, c_n);
  if (ret != ERR)
    {
      s_str = _scm_from_cstring (c_str);
      free (c_str);
    }
  else
    abort ();

  return s_str;
}


SCM
gucu_WACS_ULCORNER ()
{
  cchar_t *ret = WACS_ULCORNER;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_LLCORNER ()
{
  cchar_t *ret = WACS_LLCORNER;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_URCORNER ()
{
  cchar_t *ret = WACS_URCORNER;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_LRCORNER ()
{
  cchar_t *ret = WACS_LRCORNER;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_RTEE ()
{
  cchar_t *ret = WACS_RTEE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_LTEE ()
{
  cchar_t *ret = WACS_LTEE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_BTEE ()
{
  cchar_t *ret = WACS_BTEE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_TTEE ()
{
  cchar_t *ret = WACS_TTEE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_HLINE ()
{
  cchar_t *ret = WACS_HLINE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_VLINE ()
{
  cchar_t *ret = WACS_VLINE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_PLUS ()
{
  cchar_t *ret = WACS_PLUS;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_S1 ()
{
  cchar_t *ret = WACS_S1;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_S9 ()
{
  cchar_t *ret = WACS_S9;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_DIAMOND ()
{
  cchar_t *ret = WACS_DIAMOND;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_CKBOARD ()
{
  cchar_t *ret = WACS_CKBOARD;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_DEGREE ()
{
  cchar_t *ret = WACS_DEGREE;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_PLMINUS ()
{
  cchar_t *ret = WACS_PLMINUS;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_BULLET ()
{
  cchar_t *ret = WACS_BULLET;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_LARROW ()
{
  cchar_t *ret = WACS_LARROW;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_RARROW ()
{
  cchar_t *ret = WACS_RARROW;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_DARROW ()
{
  cchar_t *ret = WACS_DARROW;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_UARROW ()
{
  cchar_t *ret = WACS_UARROW;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_BOARD ()
{
  cchar_t *ret = WACS_BOARD;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_LANTERN ()
{
  cchar_t *ret = WACS_LANTERN;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

SCM
gucu_WACS_BLOCK ()
{
  cchar_t *ret = WACS_BLOCK;
  SCM s_ret = _scm_from_cchar (ret);

  return s_ret;
}

void
gucu_cursw_init_special ()
{
   scm_c_define_gsubr ("erasewchar", 0, 0, 0, gucu_erasewchar);
   scm_c_define_gsubr ("getn-wstr", 1, 0, 0, gucu_getn_wstr);
   scm_c_define_gsubr ("get-wch", 0, 0, 0, gucu_get_wch);
   scm_c_define_gsubr ("innwstr", 1, 0, 0, gucu_innwstr);
   scm_c_define_gsubr ("inwstr", 0, 0, 0, gucu_inwstr);
   scm_c_define_gsubr ("killwchar", 0, 0, 0, gucu_killwchar);
   scm_c_define_gsubr ("mvgetn-wstr", 3, 0, 0, gucu_mvgetn_wstr);
   scm_c_define_gsubr ("mvget-wch", 2, 0, 0, gucu_mvget_wch);
   scm_c_define_gsubr ("mvinnwstr", 3, 0, 0, gucu_mvinnwstr);
   scm_c_define_gsubr ("mvinwstr", 2, 0, 0, gucu_mvinwstr);
   scm_c_define_gsubr ("mvwgetn-wstr", 4, 0, 0, gucu_mvwgetn_wstr);
   scm_c_define_gsubr ("mvwget-wch", 3, 0, 0, gucu_mvwget_wch);
   scm_c_define_gsubr ("mvwinnwstr", 4, 0, 0, gucu_mvwinnwstr);
   scm_c_define_gsubr ("mvwinwstr", 3, 0, 0, gucu_mvwinwstr);
   scm_c_define_gsubr ("%wgetbkgrnd", 0, 0, 0, gucu_wgetbkgrnd);
   scm_c_define_gsubr ("wgetn-wstr", 2, 0, 0, gucu_wgetn_wstr);
   scm_c_define_gsubr ("wget-wch", 1, 0, 0, gucu_wget_wch);
   scm_c_define_gsubr ("winnwstr", 2, 0, 0, gucu_winnwstr);
   scm_c_define_gsubr ("winwstr", 1, 0, 0, gucu_winwstr);
   scm_c_define_gsubr ("%win-wch", 1, 0, 0, gucu_win_wch);
   scm_c_define_gsubr ("%win-wchnstr", 2, 0, 0, gucu_win_wchnstr);
   scm_c_define_gsubr ("wacs-block", 0, 0, 0, gucu_WACS_BLOCK);
   scm_c_define_gsubr ("wacs-board", 0, 0, 0, gucu_WACS_BOARD);
   scm_c_define_gsubr ("wacs-btee", 0, 0, 0, gucu_WACS_BTEE);
   scm_c_define_gsubr ("wacs-bullet", 0, 0, 0, gucu_WACS_BULLET);
   scm_c_define_gsubr ("wacs-ckboard", 0, 0, 0, gucu_WACS_CKBOARD);
   scm_c_define_gsubr ("wacs-darrow", 0, 0, 0, gucu_WACS_DARROW);
   scm_c_define_gsubr ("wacs-degree", 0, 0, 0, gucu_WACS_DEGREE);
   scm_c_define_gsubr ("wacs-diamond", 0, 0, 0, gucu_WACS_DIAMOND);
   scm_c_define_gsubr ("wacs-hline", 0, 0, 0, gucu_WACS_HLINE);
   scm_c_define_gsubr ("wacs-lantern", 0, 0, 0, gucu_WACS_LANTERN);
   scm_c_define_gsubr ("wacs-larrow", 0, 0, 0, gucu_WACS_LARROW);
   scm_c_define_gsubr ("wacs-llcorner", 0, 0, 0, gucu_WACS_LLCORNER);
   scm_c_define_gsubr ("wacs-lrcorner", 0, 0, 0, gucu_WACS_LRCORNER);
   scm_c_define_gsubr ("wacs-ltee", 0, 0, 0, gucu_WACS_LTEE);
   scm_c_define_gsubr ("wacs-plminus", 0, 0, 0, gucu_WACS_PLMINUS);
   scm_c_define_gsubr ("wacs-plus", 0, 0, 0, gucu_WACS_PLUS);
   scm_c_define_gsubr ("wacs-rarrow", 0, 0, 0, gucu_WACS_RARROW);
   scm_c_define_gsubr ("wacs-rtee", 0, 0, 0, gucu_WACS_RTEE);
   scm_c_define_gsubr ("wacs-s1", 0, 0, 0, gucu_WACS_S1);
   scm_c_define_gsubr ("wacs-s9", 0, 0, 0, gucu_WACS_S9);
   scm_c_define_gsubr ("wacs-ttee", 0, 0, 0, gucu_WACS_TTEE);
   scm_c_define_gsubr ("wacs-uarrow", 0, 0, 0, gucu_WACS_UARROW);
   scm_c_define_gsubr ("wacs-ulcorner", 0, 0, 0, gucu_WACS_ULCORNER);
   scm_c_define_gsubr ("wacs-urcorner", 0, 0, 0, gucu_WACS_URCORNER);
   scm_c_define_gsubr ("wacs-vline", 0, 0, 0, gucu_WACS_VLINE);
}

