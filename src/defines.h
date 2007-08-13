#ifndef DEFINES_H
#define DEFINES_H 1

// This define turns on extra debug info to check when a c file gets called
#define DEBUG_MODULE_INIT (1)
#define TESTBED (0)

// Functions that are going to appear in a Cygwin DLL need special
// attributes so that they can be exported
#if defined (DLL_IMPORT)
#define API __attribute__ ((dllimport, cdecl))
#elif defined (DLL_EXPORT)
#define API __attribute__ ((dllexport, cdecl))
#else 
#define API
#endif

#endif
