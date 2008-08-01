#!/bin/sh

# eti_wrap.sh -- generate scheme wrapper functions for shared
#                form/menu functions

# $Id: eti_wrap.sh,v 1.1 2008/08/01 16:09:48 spike_gran Exp $

# Put together a mostly complete wrapset from the eti_const.txt

########
# eti_const.c

echo "
#include <curses.h>
#include <libguile.h>
#include <form.h>
#include <menu.h>
#define _GNU_SOURCE" > eti_const.c

awk --file="const_def.awk" < eti_const.txt >> eti_const.c

echo "
void 
gucu_eti_init_constant ()
{" >> eti_const.c

awk --file="const_init.awk" < eti_const.txt >> eti_const.c

echo "}" >> eti_const.c

##########
# eti_const.h

echo "
#ifndef ETI_CONST_H
#define ETI_CONST_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > eti_const.h

awk --file="const_head.awk" < eti_const.txt >> eti_const.h

echo "
void gucu_eti_init_constant (void) API;
#endif" >> eti_const.h


##########
# SCM file
echo "
;; -*- Mode: scheme; -*-
(define-module (XXpackageXX eti)
	#:export ( " > eti.scm.in

awk --file="const_scm.awk" < eti_const.txt >> eti.scm.in
echo "))" >> eti.scm.in

echo "
(load-extension \"XXlibnameXX\" \"gucu_eti_init\")" >> eti.scm.in
