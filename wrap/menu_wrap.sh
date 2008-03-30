#!/bin/sh

# menu_wrap.sh -- generate scheme wrapper functions for wide curses

# $Id: menu_wrap.sh,v 1.1 2008/03/30 16:57:05 spike_gran Exp $

# Put together a mostly complete wrapset from the files menu_func.txt
# and menu_const.txt. 

#########
# menu_func.c

echo "
#include <libguile.h>
#include <curses.h>
#include <menu.h>
#include <config.h>
#include \"menu_func.h\"
#include \"type.h\"
#include \"menu_type.h\"
#define _GNU_SOURCE
#define cstring_t cchar_t" > menu_func.c

awk --file="func_def.awk" < menu_func.txt >> menu_func.c

echo "
void 
gucu_menu_init_function ()
{" >> menu_func.c

awk --file="func_init.awk" < menu_func.txt >> menu_func.c

echo "}" >> menu_func.c

########
# menu_func.h

echo "
#ifndef MENU_FUNC_H
#define MENU_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t" > menu_func.h

awk --file="func_head.awk" < menu_func.txt >> menu_func.h

echo "
void gucu_menu_init_function (void) API;
#endif
" >> menu_func.h

########
# menu_const.c

echo "
#include <curses.h>
#include <libguile.h>
#include <menu.h>
#include <wchar.h>
#include \"menu_const.h\"
#include \"type.h\"
#include \"menu_type.h\"
#define _GNU_SOURCE" > menu_const.c

awk --file="const_def.awk" < menu_const.txt >> menu_const.c

echo "
void 
gucu_menu_init_constant ()
{" >> menu_const.c

awk --file="const_init.awk" < menu_const.txt >> menu_const.c

echo "}" >> menu_const.c

##########
# menu_const.h

echo "
#ifndef MENU_CONST_H
#define MENU_CONST_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > menu_const.h

awk --file="const_head.awk" < menu_const.txt >> menu_const.h

echo "
void gucu_menu_init_constant (void) API;
#endif /* not CONSTANT_H */" >> menu_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX menu)
	#:export ( " > menu.scm.in

awk --file="func_scm.awk" < menu_func.txt >> menu.scm.in
awk --file="const_scm.awk" < menu_const.txt >> menu.scm.in
awk --file="special_scm.awk" < menu_spec.txt >> menu.scm.in
echo "))" >> menu.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_menu_init\")" >> menu.scm.in
