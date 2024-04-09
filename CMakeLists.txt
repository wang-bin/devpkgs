cmake_minimum_required(VERSION 3.15) # 3.15: CMAKE_MSVC_RUNTIME_LIBRARY

project(devpkgs C CXX ASM)

option(WITH_LTO "Build with LTO" ON)
option(WITH_LTO_STATIC "Build static lib with LTO. Worse compiler compatibility" OFF)
option(BUILD_FREETYPE "Build freetype" ON)
option(BUILD_FRIBIDI "Build fribidi" ON)
option(BUILD_HARFBUZZ "Build harfbuzz" ON)
option(BUILD_EXPAT "Build expat" ON)
option(BUILD_LIBASS "Build libass" ON)
option(BUILD_DAV1D "Build dav1d" ON)
option(BUILD_VALD "Build libva loader" ON)
option(BUILD_WOLFSSL "Build wolfssl" OFF)
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

message("CMAKE_SYSTEM_PROCESSOR: ${CMAKE_SYSTEM_PROCESSOR}")

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
  link_directories(BEFORE ${VC_LTL_Library})
endif()

include_directories(dep/include)
set(CMAKE_REQUIRED_INCLUDES ${CMAKE_SOURCE_DIR}/dep/include)

set(FT_DISABLE_BROTLI 1)
set(FT_DISABLE_PNG 1)
if(BUILD_LIBASS OR BUILD_FREETYPE)
  message("Configuring freetype...")
  add_subdirectory(src/freetype)
endif()
set(HB_BUILD_SUBSET 0)
if(IOS OR MACCATALYST OR TVOS)
  set(HB_IOS 1)
endif()
if(BUILD_LIBASS OR BUILD_HARFBUZZ)
  message("Configuring harfbuzz...")
  add_subdirectory(src/harfbuzz)
endif()

# expat options via macro expat_shy_set
set(EXPAT_BUILD_TOOLS 0)
set(EXPAT_BUILD_EXAMPLES 0)
set(EXPAT_BUILD_TESTS 0)
set(EXPAT_SHARED_LIBS 0) #BUILD_SHARED_LIBS
set(EXPAT_BUILD_DOCS 0)
set(EXPAT_MIN_SIZE 1)
if(BUILD_LIBASS OR BUILD_EXPAT)
  message("Configuring expat...")
  add_subdirectory(src/libexpat/expat)
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
  message("Configuring mfx_dispatch...")
  add_subdirectory(src/mfx_dispatch)
  # TODO: libmfx.pc
  set(BUILD_SHARED_LIBS OFF)
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
# macOS x64 build arm64: CMAKE_SYSTEM_PROCESSOR is x86_64 used CMAKE_SYSTEM_PROCESSOR by wolfssl is wrong
  add_subdirectory(src/wolfssl)
endif()

# android INTERPROCEDURAL_OPTIMIZATION: cmake will force gold linker if CMAKE_ANDROID_NDK_VERSION is not set(e.g. use ndk's cmake toolchain file) or less than 22
# TODO: INTERPROCEDURAL_OPTIMIZATION is thin lto, how to enable full lto?
foreach(tgt expat freetype harfbuzz fribidi_shared fribidi_static ass zlib)
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
