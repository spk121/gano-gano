#include <curses.h>
#include <libguile.h>
#include <config.h>
#include <menu.h>
#include "type.h"
#include "menu_type.h"
#include "menu_spec.h"

// Create a new menu given a list of text labels LABELS
SCM
gucu_new_menu (SCM labels)
{
  SCM_ASSERT (scm_is_true (scm_list_p (labels)), labels, SCM_ARG1, "new-menu");

  size_t len = scm_to_size_t (scm_length (labels));
  ITEM **items = (ITEM **) malloc (sizeof (ITEM *) * (len + 1));

  char *label, *descr;

  for (int i=0; i < len; i++)
    {
      SCM entry = scm_list_ref (labels, scm_from_int (i));
      if (scm_is_pair (entry))
	{
	  label = scm_to_locale_string (scm_car (scm_list_ref (labels, 
							       scm_from_int (i))));
	  descr = scm_to_locale_string (scm_cdr (scm_list_ref (labels, 
							       scm_from_int (i))));
	  items[i] = new_item(label, descr);
	}
      else
	{
	  label = scm_to_locale_string (scm_list_ref (labels, scm_from_int (i)));
	  items[i] = new_item(label, "");
	}
    }
  items[len] = (ITEM *) 0;

  MENU *result = new_menu (items);
  // printf("%p\r\n", result);
  if (result == NULL)
    scm_syserror ("new-menu");
  else
    return _scm_from_menu (result);
}

// Free the memory association with MENU
SCM
gucu_free_menu (SCM menu)
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "free-menu");

  MENU *m = _scm_to_menu (menu);
  ITEM **ip;
  int count;
  
  if (m != 0) 
    {
      delwin(menu_sub(m));
      delwin(menu_win(m));
      
      ip = menu_items(m);
      count = item_count(m);
      
      free_menu(m);
#if 0
      if (count > 0) 
	{
	  while (*ip) 
	    {
	      _tracef("freeing item %d:%d", ip - menu_items(m), count);
	      free_item(*ip++);
	    }
	}
#endif
    }
  SCM_NEWSMOB (menu, menu_tag, NULL);

  return SCM_UNSPECIFIED;
}


// Return the minimum size of a window necessary to contain the MENU
SCM
gucu_scale_menu (SCM menu)
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "scale-menu");

  MENU *m = _scm_to_menu (menu);
  int rows, columns, ret_val;
  
  ret_val = scale_menu(m, &rows, &columns);
  // printf("%p %d %d", m, rows, columns);
  if (ret_val == E_OK)
    {
      return scm_list_2 (scm_from_int (rows), scm_from_int (columns));
    }
  else
    return SCM_BOOL_F;
}


SCM
gucu_item_index (SCM menu)
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "item-index");

  MENU *m = _scm_to_menu (menu);
  
  return scm_from_int (item_index (current_item (m)));
}

/* returns a list of 3 elements: 
1. num spaces between item name and description
2. num rows
3. num cols
or #f on failure.
*/
SCM
gucu_menu_spacing (SCM menu)
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "item-index");

  MENU *m = _scm_to_menu (menu);
  
  int spc_description;
  int spc_rows;
  int spc_columns;
  int ret_val;
  
  ret_val = menu_spacing (m, &spc_description, &spc_rows, &spc_columns);

  if (ret_val == E_OK)
    return scm_list_3 (scm_from_int (spc_description), 
		       scm_from_int (spc_rows),
		       scm_from_int (spc_columns));
  else
    return SCM_BOOL_F;
}

/* return the width of the menu */
SCM
gucu_menu_itemlen (SCM menu)  
{
  SCM_ASSERT (_scm_is_menu (menu), menu, SCM_ARG1, "item-index");

  MENU *m = _scm_to_menu (menu);

  return scm_from_short (m->itemlen);
}

void
gucu_menu_init_special ()
{
   scm_c_define_gsubr ("new-menu", 1, 0, 0, gucu_new_menu);
   scm_c_define_gsubr ("free-menu", 1, 0, 0, gucu_free_menu);
   scm_c_define_gsubr ("scale-menu", 1, 0, 0, gucu_scale_menu);
   scm_c_define_gsubr ("item-index", 1, 0, 0, gucu_item_index);
   scm_c_define_gsubr ("menu-spacing", 1, 0, 0, gucu_menu_spacing);
   scm_c_define_gsubr ("menu-itemlen", 1, 0, 0, gucu_menu_itemlen);
}
