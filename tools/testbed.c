#include <config.h>
#include <libguile.h>
#include <curses.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif

#ifdef HAVE_LIBNCURSESW
const int _HAVE_LIBNCURSESW = TRUE;
#else
const int _HAVE_LIBNCURSESW = FALSE;
#endif



static void inner_main (void *data, int argc, char **argv);

extern void gucu_init (void) API;
#ifdef HAVE_LIBNCURSESW
extern void gucu_cursw_init (void) API;
#endif
extern void gucu_menu_init (void) API;
extern void gucu_panel_init (void) API;
extern void gucu_form_init (void) API;


int 
main(int argc, char **argv)
{
  scm_boot_guile (argc, argv, inner_main, 0);
  return 0;			/* never reached */
}

static void
inner_main (void *data __attribute__ ((unused)), 
	    int argc, 
	    char **argv)
{
  gucu_init ();
  if (_HAVE_LIBNCURSESW)
    {
      gucu_cursw_init ();
    }
  gucu_menu_init ();
  gucu_panel_init ();
  gucu_form_init ();
  scm_c_eval_string ("(initscr)");
  scm_shell (argc, argv);
}

