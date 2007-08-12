// inopts.c -- wrap curses input options

// $Id: inopts.c,v 1.1 2007/08/12 23:52:43 spike_gran Exp $ 

#include <curses.h>
#include <libguile.h>
#include <stdio.h>

#include "core.h"
#include "defines.h"
#include "inopts.h"

#include "type_window.h"

// Local Function Definitions

// Tries to disable line buffering and erase / kill characters.
// Returns #t if it could be done.
SCM
gnc_cbreak ()
{
  return _gnc_is_ok (cbreak ());
}

// Tried to enable line buffering and erase/kill characters.
// Return #t if it could be done
SCM
gnc_nocbreak ()
{
  return _gnc_is_ok (nocbreak ());
}

// Try to set that characters are echoed as they are typed.  Return #t
// if it could be done.
SCM
gnc_echo ()
{
  return _gnc_is_ok (echo ());
}

// Try to set that characters are not echoed as they are typed.
// Return #t if it could be done.
SCM
gnc_noecho ()
{
  return _gnc_is_ok (noecho ());
}

// Turns on the halfdelay mode, where after *tenths* of seconds, #f is
// returned if nothing has been typed.  The var tenths has to be
// between 1 and 255.  The function nocbreak exits this mode. Returns
// #t if it could be done.
SCM
gnc_halfdelay (SCM tenths)
{
  SCM_ASSERT (scm_is_unsigned_integer(tenths, 1, 255), 
	      tenths, SCM_ARG1, "halfdelay");

  int ret;

  ret = halfdelay(scm_to_int (tenths));
  return _gnc_is_ok (ret);
}

// Sets the interupt flush mode.  If set to #t, when an interrupt key
// is pressed, all output in the tty queue will be flushed.  If set to
// #f an interrupt key wil not flush all the output.  Returns #t if it
// could be set.
SCM
gnc_intrflush (SCM win_smob, SCM bf)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win_smob), 
	      win_smob, SCM_ARG1, "intrflush");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "intrflush");

  
  int ret = intrflush ( _gnc_window_data (win_smob),
		       scm_to_bool (bf));
  return _gnc_is_ok (ret);
}

// Sets the keypad mode.  If bf is #t, a function key returns a single
// value representing the key.  If bf is #f, a function key will
// return an escape sequence.  Returns #t if it could be set
SCM
gnc_keypad (SCM win, SCM bf)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "keypad");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "keypad");

  
  int ret = keypad ( _gnc_window_data (win), scm_to_bool (bf));

  return _gnc_is_ok (ret);
}

// If bf is #t, 8 bit characters can be returned.  If bf is #f, only 7
// bit characters can be returned.  Returns #t if the mode could be
// set.
SCM
gnc_meta (SCM win, SCM bf)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "meta");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "meta");

  
  int ret = meta ( _gnc_window_data (win), scm_to_bool (bf));

  return _gnc_is_ok (ret);
}

// If bf if #t, the function gnc_getch will return #f if no character
// is ready.  If bf if #f, gnc_getch will wait for a character is one
// isn't ready.
SCM
gnc_nodelay (SCM win, SCM bf)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "nodelay");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "nodelay");

  
  int ret = nodelay (_gnc_window_data (win), scm_to_bool (bf));

  return _gnc_is_ok (ret);
}

// Sets raw mode where all characters are uninterpreted and control
// characters do not generate a signal.  Returns #t if it could be set.
SCM
gnc_raw ()
{
  return _gnc_is_ok (raw ());
}

// Turns of raw mode so that control characters may generate a signal.
// Returns #t if it could be set.
SCM
gnc_noraw ()
{
  return _gnc_is_ok (noraw ());
}

// After noqiflush is called, a flush of input and output queues after
// INTR, QUIT, and SUSP signals will not be done
SCM
gnc_noqiflush ()
{
  noqiflush ();
  
  return SCM_UNSPECIFIED;
}

// After qiflush is called, a flush of input and output queues after
// INTR, QUIT, and SUSP signals will occur.
SCM
gnc_qiflush ()
{
  qiflush ();
  
  return SCM_UNSPECIFIED;
}

// If bf is #t, gnc_wgetch will not set a timer to wait for a
// multi-key sequence.  If bf is #f, it will set the timer.  Returns
// #t if it could be set.
SCM
gnc_notimeout (SCM win, SCM bf)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "notimeout");
  SCM_ASSERT (scm_is_bool (bf), bf, SCM_ARG2, "notimeout");

  
  int ret = notimeout (_gnc_window_data (win), scm_to_bool (bf));

  return _gnc_is_ok (ret);
}  

// If delay is negative, a read will wait indefinitely for input.  If
// delay is zero, read returns immediately with an #f if no char is
// ready.  Otherwise, a read will wait *delay* millisconds for a
// character before returning. Returns unspecified.
SCM
gnc_timeout (SCM delay)
{
  SCM_ASSERT (scm_is_integer (delay), delay, SCM_ARG1, "timeout");

  timeout (scm_to_int (delay));

  return SCM_UNSPECIFIED;
}

// Like gnc_timeout, but for a specific window
SCM
gnc_wtimeout (SCM win, SCM delay)
{
  SCM_ASSERT (SCM_SMOB_PREDICATE (window_tag, win), 
	      win, SCM_ARG1, "wtimeout");
  SCM_ASSERT (scm_is_integer (delay), delay, SCM_ARG2, "wtimeout");

  wtimeout (_gnc_window_data (win), scm_to_int (delay));

  return SCM_UNSPECIFIED;
}

void
_gnc_init_inopts ()
{
  if (DEBUG_MODULE_INIT)
    printf ("Entering %s\n", __func__);
      
  scm_c_define_gsubr ("cbreak", 0, 0, 0, gnc_cbreak);
  scm_c_define_gsubr ("nocbreak", 0, 0, 0, gnc_nocbreak);
  scm_c_define_gsubr ("echo", 0, 0, 0, gnc_echo);
  scm_c_define_gsubr ("noecho", 0, 0, 0, gnc_noecho);
  scm_c_define_gsubr ("halfdelay", 1, 0, 0, gnc_halfdelay);
  scm_c_define_gsubr ("intrflush", 2, 0, 0, gnc_intrflush);
  scm_c_define_gsubr ("keypad", 2, 0, 0, gnc_keypad);
  scm_c_define_gsubr ("meta", 2, 0, 0, gnc_meta);
  scm_c_define_gsubr ("nodelay", 2, 0, 0, gnc_nodelay);
  scm_c_define_gsubr ("raw", 0, 0, 0, gnc_raw);
  scm_c_define_gsubr ("noraw", 0, 0, 0, gnc_noraw);
  scm_c_define_gsubr ("noqiflush", 0, 0, 0, gnc_noqiflush);
  scm_c_define_gsubr ("qiflush", 0, 0, 0, gnc_qiflush);
  scm_c_define_gsubr ("notimeout", 2, 0, 0, gnc_notimeout);
  scm_c_define_gsubr ("timeout", 1, 0, 0, gnc_timeout);
  scm_c_define_gsubr ("wtimeout", 2, 0, 0, gnc_wtimeout);

}
