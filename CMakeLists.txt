cmake_minimum_required(VERSION 3.15) # 3.15: CMAKE_MSVC_RUNTIME_LIBRARY

project(devpkgs C CXX ASM)

option(WITH_LTO "Build with LTO" ON)
option(WITH_LTO_STATIC "Build static lib with LTO. Worse compiler compatibility" OFF)
option(BUILD_LIBASS "Build libass" ON)
option(BUILD_DAV1D "Build dav1d" ON)
option(BUILD_VALD "Build libva loader" ON)
option(BUILD_WOLFSSL "Build wolfssl" OFF)
option(BUILD_SHADERC "Build shaderc" OFF)
option(BUILD_FT "Build freetype" ON)
option(BUILD_HB "Build harfbuzz" ON) # OFF to build freetype, then ON and BUILD_HB_FT to build hb-ft
option(BUILD_HB_FT "Build harfbuzz with freetype and hb-ft.h" OFF)
option(WITH_VC_LTL "Build with VC-LTL crt for windows. Recommend to use with -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded" OFF)
option(BUILD_LZ4 "Build lz4" ON)
set(VC_LTL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/VC-LTL" CACHE STRING "VC-LTL dir")

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_MODULE_PATH
    ${CMAKE_SOURCE_DIR}/cmake
    ${CMAKE_SOURCE_DIR}/cmake/tools
    #${CMAKE_INSTALL_PREFIX}     # ft, hb.
    )

include(CheckIncludeFile)

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

message("CMake: ${CMAKE_VERSION}. CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")

# ignore homebrew. affect find_...(). not working?
set(CMAKE_IGNORE_PREFIX_PATH /opt/homebrew /usr/local)
#set(CMAKE_FIND_USE_INSTALL_PREFIX 1) # find_...(). default will search if no CMAKE_FIND_NO_INSTALL_PREFIX
# find in install dir. otherwise install dir with sysroot prefix is searched
message("CMAKE_SYSROOT:${CMAKE_SYSROOT}. CMAKE_CROSSCOMPILING:${CMAKE_CROSSCOMPILING},CMAKE_OSX_SYSROOT:${CMAKE_OSX_SYSROOT}")
if(CMAKE_CROSSCOMPILING)
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_INSTALL_PREFIX} ${CMAKE_SYSROOT} ${CMAKE_OSX_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
endif()
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
  link_directories(BEFORE ${VC_LTL_Library})
endif()

include_directories(dep/include)
set(CMAKE_REQUIRED_INCLUDES ${CMAKE_SOURCE_DIR}/dep/include)

set(FT_DISABLE_BROTLI 1)
set(FT_DISABLE_PNG 1)
if((BUILD_LIBASS OR BUILD_FT) AND NOT BUILD_HB_FT)
  message("Configuring freetype...")
  add_subdirectory(src/freetype)
  if(WINRT) # freetype change uwp detection to _WINRT_DLL which is only defined by vs projects
    target_compile_definitions(freetype PRIVATE _WINRT_DLL=1)
  endif()
endif()
set(HB_BUILD_SUBSET 0)
if(IOS OR MACCATALYST OR TVOS)
  set(HB_IOS 1)
endif()
if(BUILD_LIBASS OR BUILD_HB)
  message("Configuring harfbuzz...")
  if(BUILD_HB_FT)
    set(HB_HAVE_FREETYPE 1)
  endif()
  add_subdirectory(src/harfbuzz)
endif()
add_subdirectory(projects)

if(NOT CMAKE_SYSTEM_PROCESSOR MATCHES arm OR CMAKE_SYSTEM_PROCESSOR MATCHES 64) # arm64
  set(SNAPPY_BUILD_TESTS 0)
  set(SNAPPY_BUILD_BENCHMARKS 0)
  message("Configuring snappy...")
  add_subdirectory(src/snappy)
endif()

if(MSVC)
  message("Configuring zlib...")
  add_subdirectory(src/zlib)
endif()

if(WINDOWS_DESKTOP OR (CMAKE_SYSTEM_NAME STREQUAL Darwin AND NOT MACCATALYST)) # win32, macOS
  message("Configuring glfw...")
  add_subdirectory(src/glfw)
endif()

if((WINDOWS_DESKTOP OR LINUX) AND (ARCH MATCHES "[aA][mM][dD]64" OR ARCH MATCHES "[xX].*64" OR ARCH MATCHES 86))
  #message("Configuring mfx_dispatch...")
  #add_subdirectory(src/mfx_dispatch)
  # TODO: libmfx.pc
  set(BUILD_SHARED_LIBS OFF) # TODO: global option in cmake
  #if(CMAKE_CROSSCOMPILING) # onevpl tools does not support c++17, and requires rtti
    set(BUILD_DEV_ONLY ON)
  #endif()
  message("Configuring oneVPL...")
  add_subdirectory(src/oneVPL)
endif()


if(BUILD_VALD AND (LINUX OR WINDOWS_DESKTOP))
  check_include_file(va/va.h HAVE_VA_H)
  if(HAVE_VA_H)
    message("Configuring libva_loader...")
    add_subdirectory(src/libva_loader)
  endif()
endif()

if(BUILD_WOLFSSL)
  message("Configuring wolfssl...")
  set(WOLFSSL_FILESYSTEM no)
  # sni test: https://www.rmp-streaming.com/media/big-buck-bunny-360p.mp4  https://omc3i.codesandbox.io/ts/playlist.m3u8
  set(WOLFSSL_SNI yes)
  add_compile_definitions(NO_WOLFSSL_SERVER=1)
  set(BUILD_SHARED_LIBS 0)
  set(WOLFSSL_CRYPT_TESTS no)
  set(WOLFSSL_FAST_MATH yes)
# macOS x64 build arm64: CMAKE_SYSTEM_PROCESSOR is x86_64 used CMAKE_SYSTEM_PROCESSOR by wolfssl is wrong
  add_subdirectory(src/wolfssl)
endif()
if(LINUX)
  add_subdirectory(src/cppcompat)
endif()

add_subdirectory(src/libshaderc_loader)
if(BUILD_SHADERC)
  message("Configuring shaderc...")
  set(SHADERC_SKIP_TESTS 1)
  set(SHADERC_SKIP_EXAMPLES 1)
  set(SHADERC_ENABLE_SHARED_CRT 1)
  add_subdirectory(src/shaderc)
endif()

if(BUILD_LZ4)
  set(LZ4_BUNDLED_MODE OFF)
  set(LZ4_BUILD_CLI OFF)
  message("Configuring lz4...")
  add_subdirectory(src/lz4/build/cmake)
  message("BUILD_SHARED_LIBS: ${BUILD_SHARED_LIBS}, BUILD_STATIC_LIBS: ${BUILD_STATIC_LIBS}, LZ4_BUNDLED_MODE: ${LZ4_BUNDLED_MODE}")
endif()

# android INTERPROCEDURAL_OPTIMIZATION: cmake will force gold linker if CMAKE_ANDROID_NDK_VERSION is not set(e.g. use ndk's cmake toolchain file) or less than 22
# TODO: INTERPROCEDURAL_OPTIMIZATION is thin lto, how to enable full lto?
foreach(tgt freetype harfbuzz fribidi_shared fribidi_static ass zlib) # TODO: no lto for other projects(ffmpeg)
  if(TARGET ${tgt})
    set_target_properties(${tgt} PROPERTIES
        INTERPROCEDURAL_OPTIMIZATION ${WITH_LTO})
  endif()
endforeach()

foreach(tgt snappy zlibstatic glfw
    va va_win32 va-drm va-x11 vdpau
    wolfssl
    )
  if(TARGET ${tgt})
    set_target_properties(${tgt} PROPERTIES
        INTERPROCEDURAL_OPTIMIZATION ${WITH_LTO_STATIC})
  endif()
endforeach()
