#include <libguile.h>

scm_t_bits port_fp;

void
scm_init_port (void)
{
  port_fp = scm_make_port_type ("fp", fp_fill_input, fp_write));
}



int
fp_fill_input (SCM port)
{

}

void
fp_write (SCM port, const void *data, size_t size)
{

}
