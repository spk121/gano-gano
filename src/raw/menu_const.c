
#include <curses.h>
#include <libguile.h>
#include <menu.h>
#include <wchar.h>
#include "menu_const.h"
#include "type.h"
#include "menu_type.h"
#define _GNU_SOURCE
SCM gucu_E_OK;
SCM gucu_E_BAD_ARGUMENT;
SCM gucu_E_BAD_STATE;
SCM gucu_E_CONNECTED;
SCM gucu_E_NOT_CONNECTED;
SCM gucu_E_NOT_POSTED;
SCM gucu_E_POSTED;
SCM gucu_E_REQUEST_DENIED;
SCM gucu_E_SYSTEM_ERROR;
SCM gucu_E_UNKNOWN_COMMAND;
SCM gucu_MAX_COMMAND;
SCM gucu_REQ_SCR_ULINE;
SCM gucu_REQ_SCR_DLINE;
SCM gucu_REQ_SCR_UPAGE;
SCM gucu_REQ_SCR_DPAGE;
SCM gucu_REQ_LEFT_ITEM;
SCM gucu_REQ_RIGHT_ITEM;
SCM gucu_REQ_NEXT_ITEM;
SCM gucu_REQ_PREV_ITEM;
SCM gucu_REQ_TOGGLE_ITEM;
SCM gucu_REQ_FIRST_ITEM;
SCM gucu_REQ_LAST_ITEM;
SCM gucu_O_ONEVALUE;

void 
gucu_menu_init_constant ()
{
	gucu_E_OK = scm_permanent_object (scm_c_define ("E_OK", scm_from_int (E_OK)));
	gucu_E_BAD_ARGUMENT = scm_permanent_object (scm_c_define ("E_BAD_ARGUMENT", scm_from_int (E_BAD_ARGUMENT)));
	gucu_E_BAD_STATE = scm_permanent_object (scm_c_define ("E_BAD_STATE", scm_from_int (E_BAD_STATE)));
	gucu_E_CONNECTED = scm_permanent_object (scm_c_define ("E_CONNECTED", scm_from_int (E_CONNECTED)));
	gucu_E_NOT_CONNECTED = scm_permanent_object (scm_c_define ("E_NOT_CONNECTED", scm_from_int (E_NOT_CONNECTED)));
	gucu_E_NOT_POSTED = scm_permanent_object (scm_c_define ("E_NOT_POSTED", scm_from_int (E_NOT_POSTED)));
	gucu_E_POSTED = scm_permanent_object (scm_c_define ("E_POSTED", scm_from_int (E_POSTED)));
	gucu_E_REQUEST_DENIED = scm_permanent_object (scm_c_define ("E_REQUEST_DENIED", scm_from_int (E_REQUEST_DENIED)));
	gucu_E_SYSTEM_ERROR = scm_permanent_object (scm_c_define ("E_SYSTEM_ERROR", scm_from_int (E_SYSTEM_ERROR)));
	gucu_E_UNKNOWN_COMMAND = scm_permanent_object (scm_c_define ("E_UNKNOWN_COMMAND", scm_from_int (E_UNKNOWN_COMMAND)));
	gucu_MAX_COMMAND = scm_permanent_object (scm_c_define ("MAX_COMMAND", scm_from_int (MAX_COMMAND)));
	gucu_REQ_SCR_ULINE = scm_permanent_object (scm_c_define ("REQ_SCR_ULINE", scm_from_int (REQ_SCR_ULINE)));
	gucu_REQ_SCR_DLINE = scm_permanent_object (scm_c_define ("REQ_SCR_DLINE", scm_from_int (REQ_SCR_DLINE)));
	gucu_REQ_SCR_UPAGE = scm_permanent_object (scm_c_define ("REQ_SCR_UPAGE", scm_from_int (REQ_SCR_UPAGE)));
	gucu_REQ_SCR_DPAGE = scm_permanent_object (scm_c_define ("REQ_SCR_DPAGE", scm_from_int (REQ_SCR_DPAGE)));
	gucu_REQ_LEFT_ITEM = scm_permanent_object (scm_c_define ("REQ_LEFT_ITEM", scm_from_int (REQ_LEFT_ITEM)));
	gucu_REQ_RIGHT_ITEM = scm_permanent_object (scm_c_define ("REQ_RIGHT_ITEM", scm_from_int (REQ_RIGHT_ITEM)));
	gucu_REQ_NEXT_ITEM = scm_permanent_object (scm_c_define ("REQ_NEXT_ITEM", scm_from_int (REQ_NEXT_ITEM)));
	gucu_REQ_PREV_ITEM = scm_permanent_object (scm_c_define ("REQ_PREV_ITEM", scm_from_int (REQ_PREV_ITEM)));
	gucu_REQ_TOGGLE_ITEM = scm_permanent_object (scm_c_define ("REQ_TOGGLE_ITEM", scm_from_int (REQ_TOGGLE_ITEM)));
	gucu_REQ_FIRST_ITEM = scm_permanent_object (scm_c_define ("REQ_FIRST_ITEM", scm_from_int (REQ_FIRST_ITEM)));
	gucu_REQ_LAST_ITEM = scm_permanent_object (scm_c_define ("REQ_LAST_ITEM", scm_from_int (REQ_LAST_ITEM)));
	gucu_O_ONEVALUE = scm_permanent_object (scm_c_define ("O_ONEVALUE", scm_from_int (O_ONEVALUE)));
}
