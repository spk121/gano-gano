m4_dnl This is the configuration file 
m4_changequote(`{',`}')
m4_changecom()

m4_dnl INCLUDES
m4_define({LOCALEDIR},{"/usr/local/share/locale"})
m4_define({SYSCONFDIR},{"/usr/local/etc"})

m4_dnl Define this to enable debug messages and assert warnings. 
m4_define({DEBUG},{1})
m4_dnl Define this to disable the built-in file browser. 
m4_define({DISABLE_BROWSER},{1})
m4_dnl Define this to disable the help text display. 
m4_define({DISABLE_HELP},{1})
m4_dnl Define this to disable the justify routines. 
m4_define({DISABLE_JUSTIFY},{1})
m4_dnl Define this to disable the mouse support. 
m4_define({DISABLE_MOUSE},{1})
m4_dnl Define this to disable the setting of the operating directory (chroot of
m4_dnl sorts).
m4_define({DISABLE_OPERATINGDIR},{1})
m4_dnl Define this to disable text wrapping as root by default. 
m4_dnl m4_define({DISABLE_ROOTWRAPPING},{1})
m4_dnl Define this to disable the spell checker functions. 
m4_define({DISABLE_SPELLER},{1})
m4_dnl Define to disable the tab completion functions for files and search
m4_dnl strings. 
m4_define({DISABLE_TABCOMP},{1})
m4_dnl Define this to disable all text wrapping. 
m4_define({DISABLE_WRAPPING},{1})
m4_dnl Define this to have syntax highlighting, requires regex.h and ENABLE_NANORC
m4_dnl too! 
m4_dnl m4_define({ENABLE_COLOR},{1})
m4_dnl Define this to enable multiple file buffers. 
m4_dnl m4_define({ENABLE_MULTIBUFFER},{1}) 
m4_dnl Define this to use .nanorc files. 
m4_dnl m4_define({ENABLE_NANORC},{1})
m4_dnl Define to 1 if translation of program messages to the user's native
m4_dnl language is requested. 
m4_define({ENABLE_NLS},{1})
m4_dnl Define this if your system has sufficient UTF-8 support (a wide curses
m4_dnl library, iswalnum(), iswpunct(), iswblank() or iswspace(), nl_langinfo,
m4_dnl mblen(), mbstowcs(), mbtowc(), wctomb(), and wcwidth()). 
m4_define({ENABLE_UTF8},{1})
m4_dnl Define if the system supports GNU-style word boundaries in regexes. 
m4_dnl m4_define({GNU_WORDBOUNDS},{1})
m4_dnl Define to 1 if you have the <curses.h> header file. 
m4_dnl m4_define({HAVE_CURSES_H},{1})
m4_dnl Define if the GNU dcgettext() function is already present or preinstalled.
m4_define({HAVE_DCGETTEXT},{1})
m4_dnl Define to 1 if you don't have `vprintf' but do have `_doprnt.' 
m4_dnl m4_define({HAVE_DOPRNT},{1})
m4_dnl Define to 1 if you have the `getdelim' function. 
m4_define({HAVE_GETDELIM},{1})
m4_dnl Define to 1 if you have the `getline' function. 
m4_define({HAVE_GETLINE},{1})
m4_dnl Define to 1 if you have the <getopt.h> header file. 
m4_define({HAVE_GETOPT_H},{1})
m4_dnl Define to 1 if you have the `getopt_long' function. 
m4_define({HAVE_GETOPT_LONG},{1})
m4_dnl Define if the GNU gettext() function is already present or preinstalled. 
m4_define({HAVE_GETTEXT},{1})
m4_dnl Define if you have the iconv() function. 
m4_dnl m4_define({HAVE_ICONV},{1})
m4_dnl Define to 1 if you have the <inttypes.h> header file. 
m4_define({HAVE_INTTYPES_H},{1})
m4_dnl Define to 1 if you have the `isblank' function. 
m4_dnl m4_define({HAVE_ISBLANK},{1})
m4_dnl Define to 1 if you have the `iswalnum' function. 
m4_define({HAVE_ISWALNUM},{1})
m4_dnl Define to 1 if you have the `iswblank' function. 
m4_dnl m4_define({HAVE_ISWBLANK},{1})
m4_dnl Define to 1 if you have the `iswpunct' function. 
m4_define({HAVE_ISWPUNCT},{1})
m4_dnl Define to 1 if you have the `iswspace' function. 
m4_define({HAVE_ISWSPACE},{1})
m4_dnl Define to 1 if you have the <libintl.h> header file. 
m4_define({HAVE_LIBINTL_H},{1})
m4_dnl Define to 1 if you have the <limits.h> header file. 
m4_define({HAVE_LIMITS_H},{1})
m4_dnl Define to 1 if you have the `mblen' function. 
m4_define({HAVE_MBLEN},{1})
m4_dnl Define to 1 if you have the `mbstowcs' function. 
m4_define({HAVE_MBSTOWCS},{1})
m4_dnl Define to 1 if you have the `mbtowc' function. 
m4_define({HAVE_MBTOWC,}{1})
m4_dnl Define to 1 if you have the <memory.h> header file. 
m4_define({HAVE_MEMORY_H},{1})
m4_dnl Define to 1 if you have the <ncurses.h> header file. 
m4_define({HAVE_NCURSES_H},{1})
m4_dnl Define to 1 if you have the `nl_langinfo' function. 
m4_define({HAVE_NL_LANGINFO},{1})
m4_dnl Define to 1 if you have the <regex.h> header file. 
m4_define({HAVE_REGEX_H},{1})
m4_dnl Define to 1 if you have the <stdarg.h> header file. 
m4_define({HAVE_STDARG_H},{1})
m4_dnl Define to 1 if you have the <stdint.h> header file. 
m4_define({HAVE_STDINT_H},{1})
m4_dnl Define to 1 if you have the <stdlib.h> header file. 
m4_define({HAVE_STDLIB_H},{1})
m4_dnl Define to 1 if you have the `strcasecmp' function. 
m4_define({HAVE_STRCASECMP},{1})
m4_dnl Define to 1 if you have the `strcasestr' function. 
m4_define({HAVE_STRCASESTR},{1})
m4_dnl Define to 1 if you have the <strings.h> header file. 
m4_define({HAVE_STRINGS_H},{1})
m4_dnl Define to 1 if you have the <string.h> header file. 
m4_define({HAVE_STRING_H},{1})
m4_dnl Define to 1 if you have the `strncasecmp' function. 
m4_define({HAVE_STRNCASECMP},{1})
m4_dnl Define to 1 if you have the `strnlen' function. 
m4_define({HAVE_STRNLEN},{1})
m4_dnl Define to 1 if you have the <sys/param.h> header file. 
m4_define({HAVE_SYS_PARAM_H},{1})
m4_dnl Define to 1 if you have the <sys/stat.h> header file. 
m4_define({HAVE_SYS_STAT_H},{1})
m4_dnl Define to 1 if you have the <sys/types.h> header file. 
m4_define({HAVE_SYS_TYPES_H},{1})
m4_dnl Define to 1 if you have the <unistd.h> header file. 
m4_define({HAVE_UNISTD_H},{1})
m4_dnl Define this if your curses library has the use_default_colors() command. 
m4_define({HAVE_USE_DEFAULT_COLORS},{1})
m4_dnl Define to 1 if you have the `vprintf' function. 
m4_define({HAVE_VPRINTF},{1})
m4_dnl Define to 1 if you have the `vsnprintf' function. 
m4_define({HAVE_VSNPRINTF},{1})
m4_dnl Define to 1 if you have the <wchar.h> header file. 
m4_define({HAVE_WCHAR_H},{1})
m4_dnl Define to 1 if you have the `wctomb' function. 
m4_define({HAVE_WCTOMB},{1})
m4_dnl Define to 1 if you have the <wctype.h> header file. 
m4_define({HAVE_WCTYPE_H},{1})
m4_dnl Define to 1 if you have the `wcwidth' function. 
m4_define({HAVE_WCWIDTH},{1})
m4_dnl Define this to enable extra stuff. 
m4_dnl m4_define({NANO_EXTRA},{1})
m4_dnl Define this to make the nano executable as small as possible. 
m4_define({NANO_TINY},{1})
m4_dnl Shut up assert warnings :-) 
m4_define({NDEBUG},{1})
m4_dnl Define this if you need the _XOPEN_SOURCE_EXTENDED macro for color support
m4_dnl m4_define({NEED_XOPEN_SOURCE_EXTENDED,{1})
m4_dnl Name of package 
m4_define({PACKAGE},{"nano"})
m4_dnl Define to the address where bug reports for this package should be sent. 
m4_define({PACKAGE_BUGREPORT},{"nano-devel@gnu.org"})
m4_dnl Define to the full name of this package. 
m4_define({PACKAGE_NAME},{"GNU nano"})
m4_dnl Define to the full name and version of this package. 
m4_define({PACKAGE_STRING},{"GNU nano 2.2.5"})
m4_dnl Define to the one symbol short name of this package. 
m4_define({PACKAGE_TARNAME},{"nano"})
m4_dnl Define to the home page for this package. 
m4_define({PACKAGE_URL},{"http://www.gnu.org/software/nano/"})
m4_dnl Define to the version of this package. 
m4_define({PACKAGE_VERSION},{"2.2.5"})
m4_dnl Where data are placed to. 
m4_define({PKGDATADIR},{"/usr/local/share/nano"})
m4_dnl Specify alternate rcfile name (default: .nanorc) 
m4_dnl m4_define({RCFILE_NAME},{".nanorc"})
m4_dnl Define this if you know your curses library allows LINES and COLS to be
m4_dnl redefined to deal with a resizing bug 
m4_define({REDEFINIG_MACROS_OK},{1})
m4_dnl Define as the return type of signal handlers (`int' or `void'). 
m4_define({RETSIGTYPE},{void})
m4_dnl Define to 1 if you have the ANSI C header files. 
m4_define({STDC_HEADERS},{1})
m4_dnl Define to use the slang wrappers for curses instead of native curses. 
m4_dnl m4_define({USE_SLANG},{1})
m4_dnl Enable extensions on AIX 3, Interix.  
m4_ifdef({_ALL_SOURCE},{},{
  m4_define({_ALL_SOURCE},{1})
})
m4_dnl Enable GNU extensions on systems that have them.  
m4_ifdef({_GNU_SOURCE},{},{
  m4_define({_GNU_SOURCE},{1})
})
m4_dnl Enable threading extensions on Solaris.
m4_ifdef({_POSIX_PTHREAD_SEMANTICS},{},
  m4_define({_POSIX_PTHREAD_SEMANTICS},{1})
})
m4_dnl Enable extensions on HP NonStop.
m4_ifdef({_TANDEM_SOURCE},{},{
  m4_define({_TANDEM_SOURCE},{1})
})
m4_dnl Enable general extensions on Solaris.
m4_ifdef({__EXTENSIONS__},{},{
  m4_define({__EXTENSIONS__},{1})
})
m4_dnl Version number of package 
m4_define({VERSION},{"2.2.5"})
m4_dnl Number of bits in a file offset, on hosts where this is settable. 
m4_define({_FILE_OFFSET_BITS},{64})
m4_dnl Define for large files, on AIX-style hosts. 
m4_dnl m4_define({_LARGE_FILES},{1})
m4_dnl Define to 1 if on MINIX. 
m4_dnl m4_define({_MINIX},{1})
m4_dnl Define to 2 if the system does not provide POSIX.1 features except with
m4_dnl this defined. 
m4_dnl m4_define({_POSIX_1_SOURCE},{1})
m4_dnl Define to 1 if you need to in order for `stat' and other things to work. 
m4_dnl m4_define({_POSIX_SOURCE},{1})
