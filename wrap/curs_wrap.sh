#!/bin/sh

# curs_wrap.sh -- generate scheme wrapper functions for narrow curses

# $Id: curs_wrap.sh,v 1.2 2008/01/14 03:32:54 spike_gran Exp $

# Put together a mostly complete wrapset from the files curs_func.txt
# and curs_const.txt. 

#########
# curs_func.c

echo "
#include <libguile.h>
#include <curses.h>
#include <config.h>
#include \"curs_func.h\"
#include \"type.h\"
#include \"term.h\"
#define _GNU_SOURCE
#define cstring_t cchar_t" > curs_func.c

awk --file="func_def.awk" < curs_func.txt >> curs_func.c

echo "
void 
gucu_init_function ()
{" >> curs_func.c

awk --file="func_init.awk" < curs_func.txt >> curs_func.c

echo "}" >> curs_func.c

########
# curs_func.h

echo "
#ifndef FUNCTION_H
#define FUNCTION_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t" > curs_func.h

awk --file="func_head.awk" < curs_func.txt >> curs_func.h

echo "
void gucu_init_function (void) API;
#endif /* not FUNCTION_H */" >> curs_func.h

########
# curs_const.c

echo "
#include <curses.h>
#include <libguile.h>
#include <wchar.h>
#include \"curs_const.h\"
#include \"type.h\"
#define _GNU_SOURCE" > curs_const.c

awk --file="const_def.awk" < curs_const.txt >> curs_const.c

echo "
void 
gucu_init_constant ()
{" >> curs_const.c

awk --file="const_init.awk" < curs_const.txt >> curs_const.c

echo "}" >> curs_const.c

##########
# curs_const.h

echo "
#ifndef CURS_CONST_H
#define CURS_CONST_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > curs_const.h

awk --file="const_head.awk" < curs_const.txt >> curs_const.h

echo "
void gucu_init_constant (void) API;
#endif /* not CONSTANT_H */" >> curs_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX curses)
	#:export ( " > curses.scm.in

awk --file="func_scm.awk" < curs_func.txt >> curses.scm.in
awk --file="const_scm.awk" < curs_const.txt >> curses.scm.in
awk --file="special_scm.awk" < curs_spec.txt >> curses.scm.in
echo "))" >> curses.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_init\")" >> curses.scm.in
