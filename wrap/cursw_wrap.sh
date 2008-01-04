#!/bin/sh

# cursw_wrap.sh -- generate scheme wrapper functions for wide curses

# $Id: cursw_wrap.sh,v 1.2 2008/01/04 08:07:12 spike_gran Exp $

# Put together a mostly complete wrapset from the files cursw_func.txt
# and cursw_const.txt. 

#########
# cursw_func.c

echo "
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include \"cursw_func.h\"
#include \"type.h\"
#include \"typew.h\"
#include \"term.h\"
#define _GNU_SOURCE
#define cstring_t cchar_t" > cursw_func.c

awk --file="func_def.awk" < cursw_func.txt >> cursw_func.c

echo "
void 
gucu_cursw_init_function ()
{" >> cursw_func.c

awk --file="func_init.awk" < cursw_func.txt >> cursw_func.c

echo "}" >> cursw_func.c

########
# cursw_func.h

echo "
#ifndef CURSW_FUNC_H
#define CURSW_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t" > cursw_func.h

awk --file="func_head.awk" < cursw_func.txt >> cursw_func.h

echo "
void gucu_cursw_init_function (void) API;
#endif
" >> cursw_func.h

########
# cursw_const.c

echo "
#include <curses.h>
#include <libguile.h>
#include <wchar.h>
#include \"cursw_const.h\"
#include \"type.h\"
#include \"typew.h\"
#define _GNU_SOURCE" > cursw_const.c

awk --file="const_def.awk" < cursw_const.txt >> cursw_const.c

echo "
void 
gucu_cursw_init_constant ()
{" >> cursw_const.c

awk --file="const_init.awk" < cursw_const.txt >> cursw_const.c

echo "}" >> cursw_const.c

##########
# cursw_const.h

echo "
#ifndef CURSW_CONST_H
#define CURSW_CONST_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > cursw_const.h

awk --file="const_head.awk" < cursw_const.txt >> cursw_const.h

echo "
void gucu_cursw_init_constant (void) API;
#endif /* not CONSTANT_H */" >> cursw_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX curses-wide-raw)
	#:export ( " > curses-wide-raw.scm.in

awk --file="func_scm.awk" < cursw_func.txt >> curses-wide-raw.scm.in
awk --file="const_scm.awk" < cursw_const.txt >> curses-wide-raw.scm.in
awk --file="special_scm.awk" < cursw_spec.txt >> curses-wide-raw.scm.in
echo "))" >> curses-wide-raw.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_cursw_init\")" >> curses-wide-raw.scm.in
