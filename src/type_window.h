#ifndef TYPE_WINDOW_H
#define TYPE_WINDOW_H 1

#include <libguile.h>

extern scm_t_bits window_tag;

void _gnc_init_type_window (void);
WINDOW *_gnc_window_data (SCM win); 

#endif /* not TYPE_WINDOW_H */
