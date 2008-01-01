#include <libguile.h>

int main(int argc, char **argv)
{
  scm_init_guile ();
  scm_c_eval_string ("(set! %load-path (append %load-path '(\".\")))");
  scm_c_eval_string ("(use-modules (gucu curses))");
  scm_shell (argc, argv);
}
