/*
 * XADTypes.h
 *
 * Copyright (c) 2018-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 *
 * This file contains compatibility wrappers for non-Apple architectures.
 */

#ifndef XADTypes_h
#define XADTypes_h

#import <Foundation/Foundation.h>

#ifndef XADEXPORT
# if defined(__WIN32__) || defined(__WINRT__)
#  ifdef __BORLANDC__
#   ifdef BUILD_XADMASTER
#    define XADEXPORT
#   else
#    define XADEXPORT	__declspec(dllimport)
#   endif
#  else
#   define XADEXPORT __declspec(dllexport)
#  endif
# else
#  if defined(__GNUC__) && __GNUC__ >= 4
#   define XADEXPORT __attribute__ ((visibility("default")))
#  else
#   define XADEXPORT
#  endif
# endif
#endif

#ifdef __cplusplus
#define XADEXTERN extern "C" XADEXPORT
#else
#define XADEXTERN extern XADEXPORT
#endif

#ifndef NS_TYPED_ENUM
#define NS_TYPED_ENUM
#endif

#ifndef NS_TYPED_EXTENSIBLE_ENUM
#define NS_TYPED_EXTENSIBLE_ENUM
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(...)
#endif

#ifndef NS_REFINED_FOR_SWIFT
#define NS_REFINED_FOR_SWIFT
#endif

#ifndef NS_SWIFT_UNAVAILABLE
#define NS_SWIFT_UNAVAILABLE(...)
#endif

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

#ifndef NS_RETURNS_INNER_POINTER
#define NS_RETURNS_INNER_POINTER
#endif

// To make other compilers happy
#ifndef __has_attribute
#define __has_attribute(...) 0
#endif
#ifndef __has_extension
#define __has_extension(...) 0
#endif

#if !defined(NS_REQUIRES_NIL_TERMINATION)
	#if __has_attribute(attribute_sentinel)
		#if defined(__APPLE_CC__) && (__APPLE_CC__ >= 5549)
			#define NS_REQUIRES_NIL_TERMINATION __attribute__((sentinel(0,1)))
		#else
			#define NS_REQUIRES_NIL_TERMINATION __attribute__((sentinel))
		#endif
	#else
		#define NS_REQUIRES_NIL_TERMINATION
	#endif
#endif

#ifndef NS_ENUM
#if __has_attribute(enum_extensibility)
#define __XAD_ENUM_ATTRIBUTES __attribute__((enum_extensibility(open)))
#define __XAD_CLOSED_ENUM_ATTRIBUTES __attribute__((enum_extensibility(closed)))
#define __XAD_OPTIONS_ATTRIBUTES __attribute__((flag_enum,enum_extensibility(open)))
#else
#define __XAD_ENUM_ATTRIBUTES
#define __XAD_CLOSED_ENUM_ATTRIBUTES
#define __XAD_OPTIONS_ATTRIBUTES
#endif

#define __XAD_ENUM_GET_MACRO(_1, _2, NAME, ...) NAME
#define __XAD_ENUM_FIXED_IS_AVAILABLE (__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))

#if __XAD_ENUM_FIXED_IS_AVAILABLE
#define __XAD_NAMED_ENUM(_type, _name)     enum __XAD_ENUM_ATTRIBUTES _name : _type _name; enum _name : _type
#define __XAD_ANON_ENUM(_type)             enum __XAD_ENUM_ATTRIBUTES : _type
#define NS_CLOSED_ENUM(_type, _name)      enum __XAD_CLOSED_ENUM_ATTRIBUTES _name : _type _name; enum _name : _type
#if (__cplusplus)
#define NS_OPTIONS(_type, _name) __attribute__((availability(swift,unavailable))) _type _name; enum __XAD_OPTIONS_ATTRIBUTES : _name
#else
#define NS_OPTIONS(_type, _name) enum __XAD_OPTIONS_ATTRIBUTES _name : _type _name; enum _name : _type
#endif
#else
#define __XAD_NAMED_ENUM(_type, _name) _type _name; enum
#define __XAD_ANON_ENUM(_type) enum
#define NS_CLOSED_ENUM(_type, _name) _type _name; enum
#define NS_OPTIONS(_type, _name) _type _name; enum
#endif

#define NS_ENUM(...) __XAD_ENUM_GET_MACRO(__VA_ARGS__, __XAD_NAMED_ENUM, __XAD_ANON_ENUM, )(__VA_ARGS__)
#endif

#ifndef DEPRECATED_ATTRIBUTE
#if defined(__has_feature) && defined(__has_attribute)
    #if __has_attribute(deprecated)
        #define DEPRECATED_ATTRIBUTE        __attribute__((deprecated))
        #if __has_feature(attribute_deprecated_with_message)
            #define DEPRECATED_MSG_ATTRIBUTE(s) __attribute__((deprecated(s)))
        #else
            #define DEPRECATED_MSG_ATTRIBUTE(s) __attribute__((deprecated))
        #endif
    #else
        #define DEPRECATED_ATTRIBUTE
        #define DEPRECATED_MSG_ATTRIBUTE(s)
    #endif
#elif defined(__GNUC__) && ((__GNUC__ >= 4) || ((__GNUC__ == 3) && (__GNUC_MINOR__ >= 1)))
    #define DEPRECATED_ATTRIBUTE        __attribute__((deprecated))
    #if (__GNUC__ >= 5) || ((__GNUC__ == 4) && (__GNUC_MINOR__ >= 5))
        #define DEPRECATED_MSG_ATTRIBUTE(s) __attribute__((deprecated(s)))
    #else
        #define DEPRECATED_MSG_ATTRIBUTE(s) __attribute__((deprecated))
    #endif
#else
    #define DEPRECATED_ATTRIBUTE
    #define DEPRECATED_MSG_ATTRIBUTE(s)
#endif
#endif

#ifndef API_DEPRECATED_WITH_REPLACEMENT
#if __has_attribute(attribute_deprecated_with_replacement)
#define API_DEPRECATED_WITH_REPLACEMENT(X, ...) __attribute__((deprecated("Use " #X " instead", X)))
#else
#define API_DEPRECATED_WITH_REPLACEMENT(X, ...) DEPRECATED_MSG_ATTRIBUTE("Use " #X " instead")
#endif
#endif

#if !defined(NSFoundationVersionNumber10_11_Max) && !defined(NSFoundationVersionNumber_iOS_9_x_Max)
typedef NSString * NSExceptionName NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString * NSErrorUserInfoKey NS_TYPED_EXTENSIBLE_ENUM;
#endif

#endif /* XADTypes_h */
