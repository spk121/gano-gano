/* The implementation of the NCurses Guile input and output ports */
#include <libguile.h>
#include <curses.h>

scm_t_bits curs_input_port;


// Open a port to operate on the window WIN.  It will read characters
// from the keyboard using wgetch and print to the screen using wputch.
// It is unbuffered.
SCM
scm_open_curses_port (SCM win)
{
  SCM_ASSERT (_scm_is_window (win), win, SCM_ARG1, "open-curses-port");



#define CURSES_INPUT_PORT_NAME "curses input"

/* fill a port's read-buffer with a single read.  returns the first
   char or EOF if end of file.  */
static int
curses_port_fill_input (SCM port)
{
  long count;
  scm_t_port *pt = SCM_PTAB_ENTRY (port);
  scm_t_bits st = SCM_STREAM (port);
  WINDOW *win = (WINDOW *)st;
  int ch;

  assert (win != NULL);
  ch = wgetch (win);
  if (ch == ERR)
    return EOF;
  else
    {
      /* Keypad values won't work downstream, so either converted to control
	 characters or ignored */
      
      if (ch > 255)
	{
	  if (ch == KEY_BACKSPACE)
	    ch = '\b';
	  if (ch == KEY_DC)
	    ch = 127;
	  else if (ch == KEY_ENTER)
	    ch = '\r';
	  else if (ch == KEY_CANCEL)
	    ch = '\x';
	  else
	    ch == EOF;
	}
	  
      pt->shortbuf = ch;
    }

  return ch;
}

static scm_t_bits
scm_make_curses_input_ptob ()
{
  scm_t_bits tc;

  tc = scm_make_port_type (CURSES_INPUT_PORT_NAME,
			   curses_input_port_fill_input,
			   curses_input_port_write);
		   
  return tc;
}
