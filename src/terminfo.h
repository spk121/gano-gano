#ifndef TERMINFO_H
#define TERMINFO_H 1

#include <libguile.h>
#include "defines.h"

SCM gnc_setupterm (SCM term, SCM out_fdes) API;

void gnc_init_terminfo (void) API;


#endif /* not TERMINFO_H */
