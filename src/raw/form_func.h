
#ifndef FORM_FUNC_H
#define FORM_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t

SCM gucu_data_ahead_p (SCM form) API;
SCM gucu_data_behind_p (SCM form) API;
SCM gucu_field_back (SCM arg1) API;
SCM gucu_field_count (SCM arg1) API;
SCM gucu_field_fore (SCM arg1) API;
SCM gucu_field_index (SCM arg1) API;
SCM gucu_field_just (SCM arg1) API;
SCM gucu_field_opts (SCM arg1) API;
SCM gucu_field_opts_off_x (SCM arg1, SCM arg2) API;
SCM gucu_field_opts_on_x (SCM arg1, SCM arg2) API;
SCM gucu_field_pad (SCM arg1) API;
SCM gucu_field_status_p (SCM arg1) API;
SCM gucu_form_driver (SCM arg1, SCM arg2) API;
SCM gucu_form_opts (SCM arg1) API;
SCM gucu_form_opts_on (SCM arg1, SCM arg2) API;
SCM gucu_form_opts_off (SCM arg1, SCM arg2) API;
SCM gucu_form_page (SCM arg1) API;
SCM gucu_form_request_by_name (SCM arg1) API;
SCM gucu_form_request_name (SCM arg1) API;
SCM gucu_form_sub (SCM arg1) API;
SCM gucu_form_win (SCM arg1) API;
SCM gucu_free_field (SCM arg1) API;
SCM gucu_free_form (SCM arg1) API;
SCM gucu_move_field (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_new_page (SCM arg1) API;
SCM gucu_pos_form_cursor (SCM arg1) API;
SCM gucu_post_form (SCM arg1) API;
SCM gucu_set_current_field (SCM arg1, SCM arg2) API;
SCM gucu_set_field_back (SCM arg1, SCM arg2) API;
SCM gucu_set_field_buffer (SCM arg1, SCM arg2, SCM arg3) API;
SCM gucu_set_field_fore (SCM arg1, SCM arg2) API;
SCM gucu_set_field_just (SCM arg1, SCM arg2) API;
SCM gucu_set_field_opts (SCM arg1, SCM arg2) API;
SCM gucu_set_field_pad (SCM arg1, SCM arg2) API;
SCM gucu_set_field_status (SCM arg1, SCM arg2) API;
SCM gucu_set_form_opts (SCM arg1, SCM arg2) API;
SCM gucu_set_form_page (SCM arg1, SCM arg2) API;
SCM gucu_set_form_sub (SCM arg1, SCM arg2) API;
SCM gucu_set_form_win (SCM arg1, SCM arg2) API;
SCM gucu_set_max_field (SCM arg1, SCM arg2) API;
SCM gucu_set_new_page (SCM arg1, SCM arg2) API;
SCM gucu_unpost_form (SCM arg1) API;

void gucu_form_init_function (void) API;
#endif

