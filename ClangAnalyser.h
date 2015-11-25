#ifndef __CLANG_ANALYSER_H__
#define __CLANG_ANALYSER_H__

#ifdef __clang_analyzer__

#include <assert.h>

#define analyser_assert(x) assert(x)

#if __has_feature(attribute_analyzer_noreturn)
#define CLANG_ANALYZER_NORETURN __attribute__((analyzer_noreturn))
#else
#define CLANG_ANALYZER_NORETURN
#endif

#else

#define analyser_assert(x)
#define CLANG_ANALYZER_NORETURN

#endif

#endif
