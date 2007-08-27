#!/bin/sh

# wrap.sh -- generate scheme wrapper functions

# $Id: wrap.sh,v 1.1 2007/08/27 13:22:18 spike_gran Exp $

# Put together a mostly complete wrapset from the files func_dir.txt
# and const_dir.txt. 

#########
# function.c

echo "
#include <libguile.h>
#include <curses.h>
#include \"function.h\"
#include \"type.h\"
#define _GNU_SOURCE" > function.c

awk --file="func_def.awk" < function.txt >> function.c

echo "
void 
gucu_init_function ()
{" >> function.c

awk --file="func_init.awk" < function.txt >> function.c

echo "}" >> function.c

########
# function.h

echo "
#ifndef FUNCTION_H
#define FUNCTION_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > function.h

awk --file="func_head.awk" < function.txt >> function.h

echo "
void gucu_init_function (void) API;
#endif /* not FUNCTION_H */" >> function.h

########
# constant.c

echo "
#include <libguile.h>
#include <curses.h>
#include \"constant.h\"
#include \"type.h\"
#define _GNU_SOURCE" > constant.c

awk --file="const_def.awk" < constant.txt >> constant.c

echo "
void 
gucu_init_constant ()
{" >> constant.c

awk --file="const_init.awk" < constant.txt >> constant.c

echo "}" >> constant.c

##########
# constant.h

echo "
#ifndef CONSTANT_H
#define CONSTANT_H

#include <config.h>
#include <libguile.h>
#ifdef DLL_EXPORT
#define API __attribute__ ((dllexport, cdecl))
#else
#define API
#endif" > constant.h

awk --file="const_head.awk" < constant.txt >> constant.h

echo "
void gucu_init_constant (void) API;
#endif /* not CONSTANT_H */" >> constant.h


##########
# SCM file
echo "
(define-module (gucu raw)
	#:export ( " > raw.scm

awk --file="func_scm.awk" < function.txt >> raw.scm
awk --file="const_scm.awk" < constant.txt >> raw.scm
cat special.txt >> raw.scm
echo "))" >> raw.scm

echo "
(load-extension \"libguile-gucu\" \"gucu_init\")" >> raw.scm
