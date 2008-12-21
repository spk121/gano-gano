#define _LARGEFILE64_SOURCE
#define _GNU_SOURCE

#include <config.h>

#include <libguile.h>
#include <curses.h>
#include <stdio.h>
#include <unistd.h>
#include "type.h"
#include "curs_port.h"

#ifdef HAVE_FOPENCOOKIE

ssize_t port_read (void *cookie, char *buf, size_t siz);
ssize_t port_write (void *cookie, const char *buf, size_t siz);
int port_seek (void *cookie, off64_t *pos, int whence);
int port_close (void *cookie);

#define PORT_ERR (-1)
#define PORT_OK (0)

cookie_io_functions_t port_func 
= {port_read, port_write, port_seek, port_close};

ssize_t 
port_read (void *cookie, char *buf, size_t siz)
{
  size_t bytes_read;
  SCM port = *(SCM *)cookie;

  if (siz > SSIZE_MAX)
    bytes_read = scm_c_read (port, buf, SSIZE_MAX);
  else
    bytes_read = scm_c_read (port, buf, siz);

  return bytes_read;
}

ssize_t 
port_write (void *cookie, const char *buf, size_t siz)
{
  SCM port = *(SCM *)cookie;

  if (siz > SSIZE_MAX)
    {
      scm_c_write (port, buf, SSIZE_MAX);
      return SSIZE_MAX;
    }
  else
    {
      scm_c_write (port, buf, siz);
      return siz;
    }
}

int 
port_seek (void *cookie, off64_t *pos, int whence)
{
  SCM port = *(SCM *)cookie;
  SCM new_pos;

  new_pos = scm_seek (port, scm_from_int64 (*pos), scm_from_int (whence));
  *pos = scm_to_int64 (new_pos);

  return PORT_OK;
}

int
port_close (void *cookie)
{
  SCM port = *(SCM *)cookie;

  scm_close_port (port);

  return PORT_OK;
}


/* Create a new terminal whose inputs and output are Guile ports */
SCM
gucu_newterm (SCM type, SCM inp, SCM outp)
{
  char *c_type;
  FILE *c_inp, *c_outp;
  SCREEN *ret;

  SCM_ASSERT (scm_is_string (type), type, SCM_ARG1, "newterm");
  SCM_ASSERT (scm_is_true (scm_input_port_p (inp)), inp, SCM_ARG2, "newterm");
  SCM_ASSERT (scm_is_true (scm_output_port_p (outp)), outp, SCM_ARG3, 
	      "newterm");

  /* FIXME: what if inp == outp?  Do I open both "rw"? */
  c_type = scm_to_locale_string (type);
  c_inp = fopencookie (&inp, "r", port_func);
  c_outp = fopencookie (&outp, "w", port_func);

  ret = newterm (c_type, c_inp, c_outp);
  if (ret == NULL)
    {
      scm_error_scm (SCM_BOOL_F,
		     scm_from_locale_string("newterm"), 
		     scm_from_locale_string("could not create a terminal"),
		     SCM_BOOL_F,
		     SCM_BOOL_F);
    }

  SCM s_ret = _scm_from_screen (ret);

  return s_ret;
}

#endif

/* Create a window based on data saved by putwin */
SCM
gucu_getwin (SCM port)
{
  FILE *fp;
  WINDOW *c_win;

  SCM_ASSERT (scm_is_true (scm_input_port_p (port)), port, SCM_ARG1, "getwin");

#ifdef HAVE_FOPENCOOKIE  
  fp = fopencookie (&port, "rb", port_func);

  if (fp == NULL)
    return SCM_BOOL_F;

  c_win = getwin (fp);

  fclose (fp);
#else
  /* Read all of the data in the port and cache it as a temp file */
  fp = tmpfile();
  while (scm_is_false (scm_eof_object_p (port)))
    {
      int c;
      c = scm_to_char (scm_read_char (port));
      if (fwrite (&c, sizeof(char), 1, fp) != 1)
	{
	  scm_syserror ("getwin");
	}
    }
  rewind (fp);

  /* Create a window fromt the contents of the port */
  c_win = getwin (fp);
  fclose (fp);      
#endif

  if (c_win == NULL)
    return SCM_BOOL_F;

  return _scm_from_window (c_win);
}


/* Writes all of the data associated with a window to a given port */
SCM
gucu_putwin (SCM win, SCM port)
{
  WINDOW *c_win;
  FILE *fp;
  int ret;
  
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "putwin");
  SCM_ASSERT (scm_is_true (scm_output_port_p (port)), port, SCM_ARG2, 
	      "putwin");

  c_win = _scm_to_window (win);

#ifdef HAVE_FOPENCOOKIE
  fp = fopencookie (&port, "wb", port_func);

  if (fp == NULL)
    return SCM_BOOL_F;

  ret = putwin (c_win, fp);

  fclose (fp);

#else
  fp = tmpfile();
  ret = putwin (c_win, fp);
  if (ret == OK)
    {
      char c;
      rewind (fp);
      while (fread (&c, sizeof(char), 1, fp) == 1)
	{
	  scm_write_char (scm_from_char (c), port);
	}
    }
  fclose (fp);
#endif

  if (ret == ERR)
    return SCM_BOOL_F;

  return SCM_BOOL_T;
}

void
gucu_init_port ()
{
#ifdef HAVE_FOPENCOOKIE
  scm_c_define_gsubr ("newterm", 3, 0, 0, gucu_newterm);
#endif
  scm_c_define_gsubr ("getwin", 1, 0, 0, gucu_getwin);
  scm_c_define_gsubr ("putwin", 2, 0, 0, gucu_putwin);
}
