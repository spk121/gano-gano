AC_INIT([gano],[0.0],[spk121@yahoo.com])

AC_CONFIG_MACRO_DIR([m4])

# from guile.m4
# sets: GUILE_CFLAGS and GUILE_LDFLAGS
GUILE_PROGS
GUILE_SITE_DIR

AC_MSG_CHECKING([if guile can handle UCS4 characters])
GUILE_CHECK([ac_cv_guile_ucs4],
            [(= 32764 (false-if-exception (char->integer (integer->char 32764))))])
if test "$ac_cv_guile_ucs4" = 0
then
  ac_cv_guile_ucs4=#t
else
  ac_cv_guile_ucs4=#f
fi
AC_MSG_RESULT([$ac_cv_guile_ucs4])
AC_SUBST(UCS4,[$ac_cv_guile_ucs4])

GUILE_MODULE_AVAILABLE([ac_cv_rnrs_control],[(rnrs control)])
if test "$ac_cv_rnrs_control" = 0
then
  ac_cv_rnrs_control=#t
else
  ac_cv_rnrs_control=#f
fi

AC_SUBST(RNRS_CONTROL,[$ac_cv_rnrs_control])

AC_CONFIG_FILES([gano/config.scm])
AC_OUTPUT