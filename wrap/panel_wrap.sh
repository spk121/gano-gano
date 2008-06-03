#!/bin/sh

# panel_wrap.sh -- generate scheme wrapper functions for wide curses

# $Id: panel_wrap.sh,v 1.2 2008/06/03 11:36:45 spike_gran Exp $

# Put together a mostly complete wrapset from the files panel_func.txt
# and panel_const.txt. 

#########
# panel_func.c

echo "
#include <libguile.h>
#include <curses.h>
#include <panel.h>
#include <config.h>
#include \"panel_func.h\"
#include \"type.h\"
#include \"panel_type.h\"
#define _GNU_SOURCE
#define cstring_t cchar_t" > panel_func.c

awk --file="func_def.awk" < panel_func.txt >> panel_func.c

echo "
void 
gucu_panel_init_function ()
{" >> panel_func.c

awk --file="func_init.awk" < panel_func.txt >> panel_func.c

echo "}" >> panel_func.c

########
# panel_func.h

echo "
#ifndef PANEL_FUNC_H
#define PANEL_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t" > panel_func.h

awk --file="func_head.awk" < panel_func.txt >> panel_func.h

echo "
void gucu_panel_init_function (void) API;
#endif
" >> panel_func.h

# ########
# # panel_const.c

# echo "
# #include <curses.h>
# #include <libguile.h>
# #include <panel.h>
# #include <wchar.h>
# #include \"panel_const.h\"
# #include \"type.h\"
# #include \"panel_type.h\"
# #define _GNU_SOURCE" > panel_const.c

# awk --file="const_def.awk" < panel_const.txt >> panel_const.c

# echo "
# void 
# gucu_panel_init_constant ()
# {" >> panel_const.c

# awk --file="const_init.awk" < panel_const.txt >> panel_const.c

# echo "}" >> panel_const.c

# ##########
# # panel_const.h

# echo "
# #ifndef PANEL_CONST_H
# #define PANEL_CONST_H

# #include <config.h>
# #include <libguile.h>
# #ifdef DLL_EXPORT
# #define API __attribute__ ((dllexport, cdecl))
# #else
# #define API
# #endif" > panel_const.h

# awk --file="const_head.awk" < panel_const.txt >> panel_const.h

# echo "
# void gucu_panel_init_constant (void) API;
# #endif /* not CONSTANT_H */" >> panel_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX panel)
	#:export ( " > panel.scm.in

awk --file="func_scm.awk" < panel_func.txt >> panel.scm.in
awk --file="const_scm.awk" < panel_const.txt >> panel.scm.in
awk --file="special_scm.awk" < panel_spec.txt >> panel.scm.in
echo "))" >> panel.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_panel_init\")" >> panel.scm.in
