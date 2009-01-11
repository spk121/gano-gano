#include <libguile.h>
#include <curses.h>
#include <form.h>
#include <config.h>
#include "form_func.h"
#include "type.h"
#include "form_type.h"
#define _GNU_SOURCE
#define cstring_t cchar_t

/* Errors */

static void form_bad_state_error (const char *funcname)
{
  scm_misc_error (funcname, "Bad state", SCM_BOOL_F);
}

static void form_current_field_error (const char *funcname)
{
  scm_misc_error (funcname, "The field is the current field", SCM_BOOL_F);
}

static void form_invalid_field_error (const char *funcname)
{
  scm_misc_error (funcname, "The field is invalid", SCM_BOOL_F);
}

static void form_not_connected_error (const char *funcname)
{
  scm_misc_error (funcname, "The field is not connected to a form", SCM_BOOL_F);
} 

static void form_not_posted_error (const char *funcname)
{
  scm_misc_error (funcname, "The form is not posted", SCM_BOOL_F);
}

/* Tests for off-screen data ahead on the form */
SCM
gucu_data_ahead_p (SCM form)
{
  SCM_ASSERT (_scm_is_form (form), form, SCM_ARG1, "data-ahead?");

  const FORM *c_form = _scm_to_form (form);
  
  return scm_from_bool (data_ahead (c_form));
}

/* Tests for off-screen data behind on the form */
SCM
gucu_data_behind_p (SCM form)
{
  SCM_ASSERT (_scm_is_form (form), form, SCM_ARG1, "data-behind?");

  const FORM *c_form = _scm_to_form (form);

  return scm_from_bool (data_behind (c_form));
}

/* Returns the background attribute of FIELD */
SCM
gucu_field_back (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-back");

  const FIELD *c_field = _scm_to_field (field);
  chtype ret = field_back (c_field);
  return _scm_from_chtype (ret);
}

/* Returns the count of fields in FORM */
SCM
gucu_field_count (SCM form)
{
  SCM_ASSERT (_scm_is_form (form), form, SCM_ARG1, "field-count");

  const FORM *c_form = _scm_to_form (form);
  int ret = field_count (c_form);

  return scm_from_int (ret);
}

/* Returns the foreground attribute of FIELD */
SCM
gucu_field_fore (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-fore");

  const FIELD *c_field = _scm_to_field (field);
  chtype ret = field_fore (c_field);

  return _scm_from_chtype (ret);
}

/* Return the index of the field in the field array of the form to
   which it is connected */
SCM
gucu_field_index (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-index");

  const FIELD *c_field = _scm_to_field (field);

  int ret = field_index (c_field);
  if (ret == ERR)
    form_not_connected_error ("field-index");

  SCM s_ret = scm_from_int (ret);

  return s_ret;
}

/* Returns the justification attribute of the field */
SCM
gucu_field_just (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-just");
  
  const FIELD *c_field = _scm_to_field (field);

  int ret = field_just (c_field);
  SCM s_ret = scm_from_int (ret);

  return s_ret;
}

/* Returns the field's current option bits */
SCM
gucu_field_opts (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-opts");

  const FIELD *c_field = _scm_to_field (field);
  
  Field_Options ret = field_opts (c_field);
  SCM s_ret = scm_from_int (ret);
  
  return s_ret;
}

/* Turn off the given option bits, leaving others alone */
SCM
gucu_field_opts_off_x (SCM field, SCM opts)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-opts-off!");
  SCM_ASSERT (scm_is_integer (opts), opts, SCM_ARG2, "field-opts-off!");
  
  FIELD *c_field = _scm_to_field (field);
  Field_Options c_opts = scm_to_int (opts);

  int ret = field_opts_off (c_field, c_opts);

  if (ret == E_BAD_ARGUMENT)
    scm_out_of_range ("field-opts-off!", opts);
  else if (ret == E_SYSTEM_ERROR)
    scm_syserror ("field-opts-off!");
  else if (ret == E_CURRENT)
    form_current_field_error ("field-opts-off!");

  return SCM_UNSPECIFIED;
}

/* Turn on the given option bits, leaving others alone */
SCM
gucu_field_opts_on_x (SCM field, SCM opts)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-opts-on!");
  SCM_ASSERT (scm_is_integer (opts), opts, SCM_ARG2, "field-opts-on!");

  FIELD *c_field = _scm_to_field (field);
  int c_opts = scm_to_int (opts);

  int ret = field_opts_on (c_field, c_opts);

  if (ret == E_BAD_ARGUMENT)
    scm_out_of_range ("field-opts-on!", opts);
  else if (ret == E_SYSTEM_ERROR)
    scm_syserror ("field-opts-on!");
  else if (ret == E_CURRENT)
    form_current_field_error ("field-opts-on!");

  return SCM_UNSPECIFIED;
}

/* Returns the pad character of the form */
SCM
gucu_field_pad (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-pad");

  const FIELD *c_field = _scm_to_field (field);

  int ret = field_pad (c_field);
  SCM s_ret = scm_from_int (ret);

  return s_ret;
}

/* True if the field has changed */
SCM
gucu_field_status_p (SCM field)
{
  SCM_ASSERT (_scm_is_field (field), field, SCM_ARG1, "field-status?");

  const FIELD *c_field = _scm_to_field (field);
  
  bool ret = field_status (c_field);
  SCM s_ret = scm_from_bool (ret);
  
  return s_ret;
}

/* Operate on character or event C */
SCM
gucu_form_driver (SCM form, SCM c)
{
  SCM_ASSERT (_scm_is_form (form), form, SCM_ARG1, "form-driver");
  SCM_ASSERT (scm_is_integer (c), c, SCM_ARG2, "form-driver");

  FORM *c_form = _scm_to_form (form);
  int c_c = scm_to_int (c);

  int ret = form_driver (c_form, c_c);

  if (ret == E_BAD_ARGUMENT)
    scm_out_of_range ("form-driver", c);
  else if (ret == E_BAD_STATE)
    form_bad_state_error ("form-driver");
  else if (ret == E_NOT_POSTED)
    form_not_posted_error ("form-driver");
  else if (ret == E_INVALID_FIELD)
    form_invalid_field_error ("form-driver");
  else if (ret == E_SYSTEM_ERROR)
    scm_syserror ("form-driver");
  else if (ret == E_CURRENT)
    form_current_field_error ("field-opts-off!");

  /* Return E_OK, E_REQUEST_DENIED (mouse error), or
     E_UNKNOWN_COMMAND */
  SCM s_ret = scm_from_int (ret);

  return s_ret;
}

/* Retrieve current form option flags */
SCM
gucu_form_opts (SCM arg1)
{
  SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-opts");

  const FORM *c_arg1 = _scm_to_form (arg1);

  int ret = form_opts (c_arg1);
  SCM s_ret = scm_from_int (ret);

  return s_ret;
}

// 1: int form_opts_on
// 2: const FORM *
// 3:  int
// 4: 
// 5: 
SCM
gucu_form_opts_on (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-opts-on");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "form-opts-on");

	 FORM *c_arg1 = _scm_to_form (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = form_opts_on (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int form_opts_off
// 2: const FORM *
// 3:  int
// 4: 
// 5: 
SCM
gucu_form_opts_off (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-opts-off");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "form-opts-off");

	 FORM *c_arg1 = _scm_to_form (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = form_opts_off (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int form_page
// 2: const FORM *
// 3: 
// 4: 
SCM
gucu_form_page (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-page");

	 FORM *c_arg1 = _scm_to_form (arg1);

	int ret = form_page (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int form_request_by_name
// 2: const char *
// 3: 
// 4: 
SCM
gucu_form_request_by_name (SCM arg1)
{
	SCM_ASSERT (scm_is_string (arg1), arg1, SCM_ARG1, "form-request-by-name");

	 char *c_arg1 = scm_to_locale_string (arg1);

	int ret = form_request_by_name (c_arg1);
	SCM s_ret = scm_from_int (ret);

	free (c_arg1);

	return s_ret;
}

// 1: const char *form_request_name
// 2: int
// 3: 
// 4: 
SCM
gucu_form_request_name (SCM arg1)
{
	SCM_ASSERT (scm_is_integer (arg1), arg1, SCM_ARG1, "form-request-name");

	int c_arg1 = scm_to_int (arg1);

	
	SCM s_ret = scm_from_locale_string (form_request_name (c_arg1));

	return s_ret;
}

// 1: WINDOW *form_sub
// 2: const FORM *
// 3: 
// 4: 
SCM
gucu_form_sub (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-sub");

	 FORM *c_arg1 = _scm_to_form (arg1);

	WINDOW * ret = form_sub (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

// 1: WINDOW *form_win
// 2: const FORM *
// 3: 
// 4: 
SCM
gucu_form_win (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "form-win");

	 FORM *c_arg1 = _scm_to_form (arg1);

	WINDOW * ret = form_win (c_arg1);
	SCM s_ret = _scm_from_window (ret);

	return s_ret;
}

// 1: int free_field
// 2: FIELD *
// 3: 
// 4: 
SCM
gucu_free_field (SCM arg1)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "free-field");

	FIELD *c_arg1 = _scm_to_field (arg1);

	int ret = free_field (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int free_form
// 2: FORM *
// 3: 
// 4: 
SCM
gucu_free_form (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "free-form");

	FORM *c_arg1 = _scm_to_form (arg1);

	int ret = free_form (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int move_field
// 2: FIELD *
// 3:  int
// 4:  int
// 5: 
// 6: 
SCM
gucu_move_field (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "move-field");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "move-field");
	SCM_ASSERT (scm_is_integer (arg3), arg3, SCM_ARG3, "move-field");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);
	int c_arg3 = scm_to_int (arg3);

	int ret = move_field (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: bool new_page
// 2: const FIELD *
// 3: 
// 4: 
SCM
gucu_new_page (SCM arg1)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "new-page");

	 FIELD *c_arg1 = _scm_to_field (arg1);

	bool ret = new_page (c_arg1);
	SCM s_ret = scm_from_bool (ret);

	return s_ret;
}

// 1: int pos_form_cursor
// 2: FORM *
// 3: 
// 4: 
SCM
gucu_pos_form_cursor (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "pos-form-cursor");

	FORM *c_arg1 = _scm_to_form (arg1);

	int ret = pos_form_cursor (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int post_form
// 2: FORM *
// 3: 
// 4: 
SCM
gucu_post_form (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "post-form");

	FORM *c_arg1 = _scm_to_form (arg1);

	int ret = post_form (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_current_field
// 2: FORM *
// 3:  FIELD *
// 4: 
// 5: i
SCM
gucu_set_current_field (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "set-current-field");
	SCM_ASSERT (_scm_is_field (arg2), arg2, SCM_ARG2, "set-current-field");

	FORM *c_arg1 = _scm_to_form (arg1);
	FIELD *c_arg2 = _scm_to_field (arg2);

	int ret = set_current_field (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_back
// 2: FIELD *
// 3:  chtype
// 4: 
// 5: 
SCM
gucu_set_field_back (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-back");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "set-field-back");

	FIELD *c_arg1 = _scm_to_field (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = set_field_back (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_buffer
// 2: FIELD *
// 3:  int
// 4:  const char *
// 5: 
// 6: 
SCM
gucu_set_field_buffer (SCM arg1, SCM arg2, SCM arg3)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-buffer");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-field-buffer");
	SCM_ASSERT (scm_is_string (arg3), arg3, SCM_ARG3, "set-field-buffer");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);
	 char *c_arg3 = scm_to_locale_string (arg3);

	int ret = set_field_buffer (c_arg1, c_arg2, c_arg3);
	SCM s_ret = scm_from_int (ret);

	free (c_arg3);

	return s_ret;
}

// 1: int set_field_fore
// 2: FIELD *
// 3:  chtype
// 4: 
// 5: 
SCM
gucu_set_field_fore (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-fore");
	SCM_ASSERT (_scm_is_chtype (arg2), arg2, SCM_ARG2, "set-field-fore");

	FIELD *c_arg1 = _scm_to_field (arg1);
	chtype c_arg2 = _scm_to_chtype (arg2);

	int ret = set_field_fore (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_just
// 2: FIELD *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_field_just (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-just");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-field-just");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_field_just (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_opts
// 2: FIELD *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_field_opts (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-opts");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-field-opts");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_field_opts (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_pad
// 2: FIELD *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_field_pad (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-pad");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-field-pad");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_field_pad (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_field_status
// 2: FIELD *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_set_field_status (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-field-status");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "set-field-status");

	FIELD *c_arg1 = _scm_to_field (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = set_field_status (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_form_opts
// 2: FORM *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_form_opts (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "set-form-opts");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-form-opts");

	FORM *c_arg1 = _scm_to_form (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_form_opts (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_form_page
// 2: FORM *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_form_page (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "set-form-page");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-form-page");

	FORM *c_arg1 = _scm_to_form (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_form_page (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_form_sub
// 2: FORM *
// 3:  WINDOW *
// 4: 
// 5: 
SCM
gucu_set_form_sub (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "set-form-sub");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "set-form-sub");

	FORM *c_arg1 = _scm_to_form (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = set_form_sub (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_form_win
// 2: FORM *
// 3:  WINDOW *
// 4: 
// 5: 
SCM
gucu_set_form_win (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "set-form-win");
	SCM_ASSERT (_scm_is_window (arg2), arg2, SCM_ARG2, "set-form-win");

	FORM *c_arg1 = _scm_to_form (arg1);
	WINDOW *c_arg2 = _scm_to_window (arg2);

	int ret = set_form_win (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_max_field
// 2: FIELD *
// 3:  int
// 4: 
// 5: 
SCM
gucu_set_max_field (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-max-field");
	SCM_ASSERT (scm_is_integer (arg2), arg2, SCM_ARG2, "set-max-field");

	FIELD *c_arg1 = _scm_to_field (arg1);
	int c_arg2 = scm_to_int (arg2);

	int ret = set_max_field (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int set_new_page
// 2: FIELD *
// 3:  bool
// 4: 
// 5: 
SCM
gucu_set_new_page (SCM arg1, SCM arg2)
{
	SCM_ASSERT (_scm_is_field (arg1), arg1, SCM_ARG1, "set-new-page");
	SCM_ASSERT (scm_is_bool (arg2), arg2, SCM_ARG2, "set-new-page");

	FIELD *c_arg1 = _scm_to_field (arg1);
	bool c_arg2 = scm_to_bool (arg2);

	int ret = set_new_page (c_arg1, c_arg2);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}

// 1: int unpost_form
// 2: FORM *
// 3: 
// 4: 
SCM
gucu_unpost_form (SCM arg1)
{
	SCM_ASSERT (_scm_is_form (arg1), arg1, SCM_ARG1, "unpost-form");

	FORM *c_arg1 = _scm_to_form (arg1);

	int ret = unpost_form (c_arg1);
	SCM s_ret = scm_from_int (ret);

	return s_ret;
}


void 
gucu_form_init_function ()
{
  scm_c_define_gsubr ("data-ahead?", 1, 0, 0, gucu_data_ahead_p);
  scm_c_define_gsubr ("data-behind?", 1, 0, 0, gucu_data_behind_p);
  scm_c_define_gsubr ("field-back", 1, 0, 0, gucu_field_back);
  scm_c_define_gsubr ("field-count", 1, 0, 0, gucu_field_count);
  scm_c_define_gsubr ("field-fore", 1, 0, 0, gucu_field_fore);
  scm_c_define_gsubr ("field-index", 1, 0, 0, gucu_field_index);
  scm_c_define_gsubr ("field-just", 1, 0, 0, gucu_field_just);
  scm_c_define_gsubr ("field-opts", 1, 0, 0, gucu_field_opts);
  scm_c_define_gsubr ("field-opts-off!", 2, 0, 0, gucu_field_opts_off_x);
  scm_c_define_gsubr ("field-opts-on!", 2, 0, 0, gucu_field_opts_on_x);
  scm_c_define_gsubr ("field-pad", 1, 0, 0, gucu_field_pad);
  scm_c_define_gsubr ("field-status?", 1, 0, 0, gucu_field_status_p);
	scm_c_define_gsubr ("form-driver", 2, 0, 0, gucu_form_driver);
	scm_c_define_gsubr ("form-opts", 1, 0, 0, gucu_form_opts);
	scm_c_define_gsubr ("form-opts-on", 2, 0, 0, gucu_form_opts_on);
	scm_c_define_gsubr ("form-opts-off", 2, 0, 0, gucu_form_opts_off);
	scm_c_define_gsubr ("form-page", 1, 0, 0, gucu_form_page);
	scm_c_define_gsubr ("form-request-by-name", 1, 0, 0, gucu_form_request_by_name);
	scm_c_define_gsubr ("form-request-name", 1, 0, 0, gucu_form_request_name);
	scm_c_define_gsubr ("form-sub", 1, 0, 0, gucu_form_sub);
	scm_c_define_gsubr ("form-win", 1, 0, 0, gucu_form_win);
	scm_c_define_gsubr ("free-field", 1, 0, 0, gucu_free_field);
	scm_c_define_gsubr ("free-form", 1, 0, 0, gucu_free_form);
	scm_c_define_gsubr ("move-field", 3, 0, 0, gucu_move_field);
	scm_c_define_gsubr ("new-page", 1, 0, 0, gucu_new_page);
	scm_c_define_gsubr ("pos-form-cursor", 1, 0, 0, gucu_pos_form_cursor);
	scm_c_define_gsubr ("post-form", 1, 0, 0, gucu_post_form);
	scm_c_define_gsubr ("set-current-field", 2, 0, 0, gucu_set_current_field);
	scm_c_define_gsubr ("set-field-back", 2, 0, 0, gucu_set_field_back);
	scm_c_define_gsubr ("set-field-buffer", 3, 0, 0, gucu_set_field_buffer);
	scm_c_define_gsubr ("set-field-fore", 2, 0, 0, gucu_set_field_fore);
	scm_c_define_gsubr ("set-field-just", 2, 0, 0, gucu_set_field_just);
	scm_c_define_gsubr ("set-field-opts", 2, 0, 0, gucu_set_field_opts);
	scm_c_define_gsubr ("set-field-pad", 2, 0, 0, gucu_set_field_pad);
	scm_c_define_gsubr ("set-field-status", 2, 0, 0, gucu_set_field_status);
	scm_c_define_gsubr ("set-form-opts", 2, 0, 0, gucu_set_form_opts);
	scm_c_define_gsubr ("set-form-page", 2, 0, 0, gucu_set_form_page);
	scm_c_define_gsubr ("set-form-sub", 2, 0, 0, gucu_set_form_sub);
	scm_c_define_gsubr ("set-form-win", 2, 0, 0, gucu_set_form_win);
	scm_c_define_gsubr ("set-max-field", 2, 0, 0, gucu_set_max_field);
	scm_c_define_gsubr ("set-new-page", 2, 0, 0, gucu_set_new_page);
	scm_c_define_gsubr ("unpost-form", 1, 0, 0, gucu_unpost_form);
}
