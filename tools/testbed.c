
#include <libguile.h>
#include <curses.h>

#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif



static void inner_main (void *data, int argc, char **argv);

extern void gucu_init (void) API;

int 
main(int argc, char **argv)
{
  scm_boot_guile (argc, argv, inner_main, 0);
  return 0;			/* never reached */
}

static void
inner_main (void *data, int argc, char **argv)
{
  gucu_init ();
  scm_shell (argc, argv);
}

