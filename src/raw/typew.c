#define _GNU_SOURCE
#include <assert.h>
#include <curses.h>
#include <errno.h>
#include <libguile.h>
#include <stdio.h>
#include <string.h>

#include <config.h>

#include "type.h"
#include "typew.h"



static int wchstrlen(const cchar_t *s);



// wchar --  In C, a wchar_t.  In scheme, an integer.

int
_scm_is_wchar (SCM x)
{
  return scm_is_integer (x);
}

wchar_t
_scm_to_wchar (SCM x)
{
  if (SIZEOF_WCHAR_T == 2)
    return scm_to_uint16 (x);
  else if (SIZEOF_WCHAR_T == 4)
    return scm_to_uint32 (x);
  else
    abort ();
}

SCM
_scm_from_wchar (wchar_t x)
{ 
  if (SIZEOF_WCHAR_T == 2)
    return scm_from_uint16 (x);
  else if (SIZEOF_WCHAR_T == 4)
    return scm_from_uint32 (x);
  else
    abort ();
}

// wchar_string -- in C, a NULL-terminated wchar_t * array.  In
// scheme, a list of integers

int
_scm_is_wchar_string (SCM x)
{
  int i;
  int err = 0;			
  SCM member;			
  
  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      for (i=0; i<len; i++)
	{
	  member = scm_list_ref (x, scm_from_int (i));
	  if (!_scm_is_wchar (member))
	    err ++;
	}
    }
  else
    err ++;
  
  if (err > 0)
    return 0;
  else
    return 1;
}

wchar_t *
_scm_to_wchar_string (SCM x)
{
  int i;
  wchar_t *str;
  SCM member;
  
  int len = scm_to_int (scm_length (x));
  
  str = (wchar_t *) scm_malloc ((len + 1)* sizeof (wchar_t));
  for (i=0; i<len; i++)
    {
      member = scm_list_ref (x, scm_from_int (i));
      str[i] = _scm_to_wchar (member);
    }
  str[len] = (wchar_t) 0;
  
  return str;
}

SCM
_scm_from_wchar_string (wchar_t *x)
{
  int i;
  SCM element;
  SCM element_list;
  SCM total_list = SCM_EOL;

  assert (x != NULL);
  
  /* FIXME: possible infinite loop if X is junk */
  i = 0;
  while (x[i] != 0) 
    {
      element = _scm_from_wchar (x[i]);
      element_list = scm_list_1 (element);
      total_list = scm_append (scm_list_2 (total_list, element_list));
      i ++;
    }
  return (total_list);
}

// wint --  In C, a wint_t.  In scheme, an integer.

int
_scm_is_wint (SCM x)
{
  return scm_is_integer (x);
}

wint_t
_scm_to_wint (SCM x)
{
  if (SIZEOF_WINT_T == 4)
    return scm_to_uint32 (x);
  else
    abort ();
}

SCM
_scm_from_wint (wint_t x)
{ 
  if (SIZEOF_WINT_T == 4)
    return scm_from_uint32 (x);
  else
    abort ();
}

// wint_string -- in C, a null-terminated wint_t * array.  In scheme,
// a list of integers

int
_scm_is_wint_string (SCM x)
{
  int i;
  int err = 0;			
  SCM member;			
  
  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      for (i=0; i<len; i++)
	{
	  member = scm_list_ref (x, scm_from_int (i));
	  if (!_scm_is_wint (member))
	    err ++;
	}
    }
  else
    err ++;
  
  if (err > 0)
    return 0;
  else
    return 1;
}

wint_t *
_scm_to_wint_string (SCM x)
{
  int i;
  wint_t *str;
  SCM member;
  
  int len = scm_to_int (scm_length (x));
  
  str = (wint_t *) scm_malloc ((len + 1)* sizeof (wint_t));
  for (i=0; i<len; i++)
    {
      member = scm_list_ref (x, scm_from_int (i));
      str[i] = _scm_to_wint (member);
    }
  str[len] = (wint_t) 0;
  
  return str;
}

SCM
_scm_from_wint_string (wint_t *x)
{
  int i;
  SCM element;
  SCM element_list;
  SCM total_list = SCM_EOL;

  assert (x != NULL);
  
  /* FIXME: possible infinite loop if X is junk */
  i = 0;
  while (x[i] != 0) 
    {
      element = _scm_from_wint (x[i]);
      element_list = scm_list_1 (element);
      total_list = scm_append (scm_list_2 (total_list, element_list));
      i ++;
    }
  return (total_list);
}


// cchar: a wide character with possible combining characters and its
// associated renditions.  In C, a cchar_t struct.  In scheme, a list
// where element 0 is the attributes, element 1 is the color pair, and
// the rest of the list is the code points of the character and its
// accents

SCM
_scm_from_cchar (cchar_t *x)
{
  int i;
  int len;
  int ret;
  wchar_t wch[10];
  attr_t attr;
  short color_pair;
  SCM element;
  SCM element_list;
  SCM total_list = SCM_EOL;

  len = getcchar(x, 0, 0, 0, 0);
  ret = getcchar(x, wch, &attr, &color_pair, NULL);
  
  assert (ret != ERR);
  
  // Strip the color info from attr
  attr &= A_ATTRIBUTES ^ A_COLOR;

  total_list = scm_list_2 (_scm_from_attr (attr), scm_from_short (color_pair));

  for (i=0; i<len; i++)
    {
      element = scm_from_uint32 (wch[i]);
      element_list = scm_list_1 (element);
      total_list = scm_append (scm_list_2 (total_list, element_list));
    }

  return total_list;
}

static int
wchstrlen(const cchar_t *s)
{
  int i = 0;
  int result = 0;
  while ((s[i]).chars[0] != L'\0')
    {
      i++ ;
      result ++;
    }
  return result;
}

SCM
_scm_from_cstring (cchar_t *x)
{
  int i;
  int len;
  SCM element;
  SCM element_list;
  SCM total_list = SCM_EOL;

  len = wchstrlen(x);
  for (i=0; i<len; i++)
    {
      element = _scm_from_cchar (&(x[i]));
      element_list = scm_list_1 (element);
      total_list = scm_append (scm_list_2 (total_list, element_list));
    }

  return total_list;
}

int
_scm_is_cchar (SCM x)
{
  int i;
  int err = 0;			
  SCM member;			
  
  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      if (len >= 3)
	{
	  member = scm_list_ref (x, scm_from_int (0));
	  if (!_scm_is_attr (member))
	    err ++;
	  member = scm_list_ref (x, scm_from_int (1));
	  if (!scm_is_integer (member))
	    err ++;
	  for (i=2; i<len; i++)
	    {
	      member = scm_list_ref (x, scm_from_int (i));
	      if (!_scm_is_wchar (member))
		err ++;
	    }
	}
      else
	err ++;
    }
  else
    err ++;

  if (err > 0)
    return 0;
  else
    return 1;

}

int
_scm_is_cstring (SCM x)
{
  int i;
  int err = 0;			
  SCM member;			
  
  if (scm_is_true (scm_list_p (x)))
    {
      int len = scm_to_int (scm_length (x));
      for (i=0; i<len; i++)
	{
	  member = scm_list_ref (x, scm_from_int (i));
	  if (!_scm_is_cchar (member))
	    err ++;
	}
    }
  else
    err ++;

  if (err > 0)
    return 0;
  else
    return 1;
}


cchar_t *
_scm_to_cchar (SCM x)
{
  int i;
  SCM member;			
  attr_t attr;
  short color_pair;
  wchar_t *wch;
  cchar_t *cchar;
  
  int len = scm_to_int (scm_length (x));
  wch = (wchar_t *) scm_malloc (sizeof(wchar_t) * (len - 1));
  cchar = (cchar_t *) scm_malloc (sizeof(cchar_t));

  member = scm_list_ref (x, scm_from_int (0));
  attr = _scm_to_attr (member);

  member = scm_list_ref (x, scm_from_int (1));
  color_pair = scm_to_short (member);

  for (i=2; i<len; i++)
    {
      member = scm_list_ref (x, scm_from_int (i));
      wch[i-2] = _scm_to_wchar (member);
    }
  wch[len-2] = L'\0';

  setcchar(cchar, wch, attr, color_pair, NULL);
  
  free (wch);

  return cchar;
}

cchar_t *
_scm_to_cstring (SCM x)
{
  int i;
  SCM member;			
  cchar_t *cstring;
  cchar_t *cchar;
  cchar_t terminator;
  wchar_t wch;
  
  int len = scm_to_int (scm_length (x));
  cstring = (cchar_t *) scm_malloc (sizeof(cchar_t) * (len + 1));


  for (i=0; i<len; i++)
    {
      member = scm_list_ref (x, scm_from_int (i));
      cchar = _scm_to_cchar (member);
      memcpy( &(cstring[i]), cchar, sizeof(cchar_t));
      free(cchar);
    }

  wch = L'\0';

  setcchar(&terminator, &wch, A_NORMAL, 0, NULL);
  memcpy( &(cstring[len]), &terminator, sizeof(cchar_t));
  
  return cstring;
}
