cmake_minimum_required(VERSION 3.15) # 3.15: CMAKE_MSVC_RUNTIME_LIBRARY

project(devpkgs C CXX ASM)

option(WITH_LTO "Build with LTO" ON)
option(WITH_LTO_STATIC "Build static lib with LTO. Worse compiler compatibility" OFF)
option(BUILD_LIBASS "Build libass" ON)
option(WITH_VC_LTL "Build with VC-LTL crt for windows. Recommend to use with -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded" OFF)
set(VC_LTL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/VC-LTL" CACHE STRING "VC-LTL dir")

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_MODULE_PATH
    ${CMAKE_SOURCE_DIR}/cmake
    ${CMAKE_SOURCE_DIR}/cmake/tools
    #${CMAKE_INSTALL_PREFIX}/lib
    )
include(tools)

if(POLICY CMP0077) # hardcoded option set
  cmake_policy(SET CMP0077 NEW) # won't affect sub projects
  set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
endif()
if(POLICY CMP0063) # visibility. since 3.3
  cmake_policy(SET CMP0063 NEW)
  set(CMAKE_POLICY_DEFAULT_CMP0063 NEW)
endif()
if(POLICY CMP0069) # lto
  cmake_policy(SET CMP0069 NEW)
  set(CMAKE_POLICY_DEFAULT_CMP0069 NEW)
endif()
if(POLICY CMP0091) # CMAKE_MSVC_RUNTIME_LIBRARY. since 3.15
  cmake_policy(SET CMP0091 NEW)
  set(CMAKE_POLICY_DEFAULT_CMP0091 NEW)
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# ignore homebrew. affect find_...()
set(CMAKE_SYSTEM_IGNORE_PREFIX_PATH "/opt/homebrew;/usr/local")
#set(CMAKE_FIND_USE_INSTALL_PREFIX 1) # find_...()
    # Always add debug flags
if(CMAKE_BUILD_TYPE MATCHES MinSizeRel AND WITH_DEB_INFO)
  if(MSVC)
    add_compile_options(/Zi)
    if(NOT CMAKE_CXX_SIMULATE_ID MATCHES MSVC)
      add_compile_options(/FS) # fix vc140.pdb open error
    endif()
    add_link_options(-DEBUG)
  else()
    add_compile_options(-g)
  endif()
endif()

if(WITH_VC_LTL AND EXISTS "${VC_LTL_DIR}")
  include("${VC_LTL_DIR}/VC-LTL helper for cmake.cmake")
endif()


set(FT_DISABLE_BROTLI 1)
set(FT_DISABLE_PNG 1)
if(BUILD_LIBASS)
  add_subdirectory(src/freetype)
endif()
set(HB_BUILD_SUBSET 0)
if(IOS)
  set(HB_IOS 1)
endif()
if(BUILD_LIBASS)
  add_subdirectory(src/harfbuzz)
endif()
add_subdirectory(projects)

set(SNAPPY_BUILD_TESTS 0)
set(SNAPPY_BUILD_BENCHMARKS 0)
add_subdirectory(src/snappy)

if(WIN32)
  add_subdirectory(src/zlib)
endif()

if(WINDOWS_DESKTOP OR (APPLE AND NOT IOS AND NOT MACCATALYST))
  add_subdirectory(src/glfw)
endif()

if((WINDOWS_DESKTOP OR LINUX) AND (ARCH MATCHES "[aA][mM][dD]64" OR ARCH MATCHES "[xX].*64" OR ARCH MATCHES 86))
  add_subdirectory(src/mfx_dispatch)
  # TODO: libmfx.pc
  set(BUILD_SHARED_LIBS OFF)
  #if(CMAKE_CROSSCOMPILING) # onevpl tools does not support c++17, and requires rtti
    set(BUILD_DEV_ONLY ON)
  #endif()
  add_subdirectory(src/oneVPL)
endif()


# android INTERPROCEDURAL_OPTIMIZATION: cmake will force gold linker if CMAKE_ANDROID_NDK_VERSION is not set(e.g. use ndk's cmake toolchain file) or less than 22
foreach(tgt freetype harfbuzz fribidi_shared fribidi_static ass snappy zlib zlibstatic glfw)
  if(TARGET ${tgt})
    set_target_properties(${tgt} PROPERTIES
        INTERPROCEDURAL_OPTIMIZATION ${WITH_LTO})
  endif()
endforeach()

foreach(tgt snappy zlibstatic glfw)
  if(TARGET ${tgt})
    set_target_properties(${tgt} PROPERTIES
        INTERPROCEDURAL_OPTIMIZATION ${WITH_LTO_STATIC})
  endif()
endforeach()
