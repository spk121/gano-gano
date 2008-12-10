#define _LARGEFILE64_SOURCE
#define _GNU_SOURCE

#include <libguile.h>
#include <curses.h>
#include <stdio.h>
#include <unistd.h>
#include "type.h"

ssize_t port_read (SCM *cookie, char *buf, size_t siz);
ssize_t port_write (SCM *cookie, const char *buf, size_t siz);
int port_seek (SCM *cookie, off64_t *pos, int whence);
int port_close (SCM *cookie);

#define PORT_ERR (-1)
#define PORT_OK (0)

cookie_io_functions_t port_func 
= {port_read, port_write, port_seek, port_close};

/* Given an input port, return a stream pointer */
SCM
port_to_filep (SCM port)
{
  FILE *fp;
  void *cookie;

  fp = fopencookie (&cookie, "r", port_func);
  return _scm_from_file (fp);
}

ssize_t 
port_read (SCM *cookie, char *buf, size_t siz)
{
  size_t bytes_read;
  SCM port = *cookie;

  if (siz > SSIZE_MAX)
    bytes_read = scm_c_read (port, buf, SSIZE_MAX);
  else
    bytes_read = scm_c_read (port, buf, siz);

  return bytes_read;
}

ssize_t 
port_write (SCM *cookie, const char *buf, size_t siz)
{
  SCM port = *cookie;

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
port_seek (SCM *cookie, off64_t *pos, int whence)
{
  SCM port = *cookie;
  SCM new_pos;

  new_pos = scm_seek (port, scm_from_int64 (*pos), scm_from_int (whence));
  *pos = scm_to_int64 (new_pos);

  return PORT_OK;
}

int
port_close (SCM *cookie)
{
  SCM port = *cookie;

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

void
gucu_init_port ()
{
  scm_c_define_gsubr ("newterm", 3, 0, 0, gucu_newterm);
  //scm_c_define_gsubr ("newterm-port", 3, 0, 0, gucu_newterm_port);
}
