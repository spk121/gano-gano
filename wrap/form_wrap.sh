#!/bin/sh

# form_wrap.sh -- generate scheme wrapper functions for wide curses

# $Id: form_wrap.sh,v 1.1 2008/08/01 16:09:48 spike_gran Exp $

# Put together a mostly complete wrapset from the files form_func.txt
# and form_const.txt. 

#########
# form_func.c

echo "
#include <libguile.h>
#include <curses.h>
#include <form.h>
#include <config.h>
#include \"form_func.h\"
#include \"type.h\"
#include \"form_type.h\"
#define _GNU_SOURCE
#define cstring_t cchar_t" > form_func.c

awk --file="func_def.awk" < form_func.txt >> form_func.c

echo "
void 
gucu_form_init_function ()
{" >> form_func.c

awk --file="func_init.awk" < form_func.txt >> form_func.c

echo "}" >> form_func.c

########
# form_func.h

echo "
#ifndef FORM_FUNC_H
#define FORM_FUNC_H

#include <libguile.h>
#include <config.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif
#define cstring_t cchar_t" > form_func.h

awk --file="func_head.awk" < form_func.txt >> form_func.h

echo "
void gucu_form_init_function (void) API;
#endif
" >> form_func.h

########
# form_const.c

echo "
#include <curses.h>
#include <libguile.h>
#include <form.h>
#include <wchar.h>
#include \"form_const.h\"
#include \"type.h\"
#include \"form_type.h\"
#define _GNU_SOURCE" > form_const.c

awk --file="const_def.awk" < form_const.txt >> form_const.c

echo "
void 
gucu_form_init_constant ()
{" >> form_const.c

awk --file="const_init.awk" < form_const.txt >> form_const.c

echo "}" >> form_const.c

##########
# form_const.h

echo "
#ifndef FORM_CONST_H
#define FORM_CONST_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > form_const.h

awk --file="const_head.awk" < form_const.txt >> form_const.h

echo "
void gucu_form_init_constant (void) API;
#endif /* not CONSTANT_H */" >> form_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX form)
        #:use-module (XXpackageXX eti)
	#:export ( " > form.scm.in

awk --file="func_scm.awk" < form_func.txt >> form.scm.in
awk --file="const_scm.awk" < form_const.txt >> form.scm.in
awk --file="special_scm.awk" < form_spec.txt >> form.scm.in
echo "
        )
        #:re-export (
" >> form.scm.in
awk --file="const_scm.awk" < eti_const.txt >> form.scm.in
echo "
        ))
" >> form.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_form_init\")" >> form.scm.in
