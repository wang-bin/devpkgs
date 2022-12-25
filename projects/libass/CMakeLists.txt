cmake_minimum_required(VERSION 3.0)

# https://github.com/hozuki/libass-cmake/blob/master/cmake/libass.cmake

PROJECT(libass)
set(CMAKE_C_VISIBILITY_PRESET default) # hidden symbols can not be exported
include(CheckCCompilerFlag)
include(CheckIncludeFile)
include(CheckTypeSize)


set(VERSION_MAJOR 0)
set(VERSION_MINOR 17)
set(VERSION_MICRO 0)
set(PROJECT_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO})
set(SO_VERSION 9) #FIXME:

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
#list(APPEND CMAKE_FIND_ROOT_PATH ${CMAKE_INSTALL_PREFIX}) # affect yasm probe

if(NOT SRC_DIR)
  set(SRC_DIR ${PROJECT_SOURCE_DIR})
endif()

find_package(Git QUIET)
if(GIT_FOUND)
  execute_process(
      COMMAND "${GIT_EXECUTABLE}" describe --tags --long --always --dirty --abbrev=40
      WORKING_DIRECTORY "${SRC_DIR}"
      RESULT_VARIABLE RET
      OUTPUT_VARIABLE GIT_COMMIT
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  add_definitions(-DCONFIG_SOURCEVERSION="commit: ${GIT_COMMIT}")
else()
  add_definitions(-DCONFIG_SOURCEVERSION="commit: unknown. ${PROJECT_VERSION}")
endif()

enable_language(ASM)
enable_language(C)

if(POLICY CMP0069) # lto
  cmake_policy(SET CMP0069 NEW)
endif()
set(EXTRA_LIBS "")

option(ENABLE_LARGE_TILES "" OFF)
option(NO_ASM "Disable use of assembly coded primitives (default: auto detect)" OFF)

set(CONFIG_ASM 0) # used by ass_bitmao_engine.c
set(CONFIG_FREETYPE 1) #required
set(CONFIG_FRIBIDI 1) #required
set(CONFIG_ICONV 0)

set(ARCH_AARCH64 0)
set(ARCH_X86 0) # x86 32/64 bit
set(ARCH_X86_64 0)

# System architecture detection
if(APPLE AND CMAKE_OSX_ARCHITECTURES)
  string(TOLOWER "${CMAKE_OSX_ARCHITECTURES}" ARCH)
elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID) # msvc
  string(TOLOWER "${CMAKE_C_COMPILER_ARCHITECTURE_ID}" ARCH)
else()
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" ARCH)
endif()
if(ARCH MATCHES "ar.*64")
  set(ARCH_AARCH64 1)
elseif(ARCH MATCHES "arm")
elseif(ARCH MATCHES "64")
endif()

set(X86_ALIASES x86 i386 i686 x86_64 amd64 x64)
list(FIND X86_ALIASES "${ARCH}" X86MATCH)
if(NOT NO_ASM AND X86MATCH GREATER "-1")
    enable_language(ASM_NASM)
    set(ARCH_X86 1)
    if(CMAKE_SIZEOF_VOID_P MATCHES 8)
        set(ARCH_X86_64 1)
        set(BITS 64)
    else()
        set(BITS 32)
    endif()
endif()
message("ARCH:${ARCH}, ARCH_X86: ${ARCH_X86}, ARCH_AARCH64:${ARCH_AARCH64}, ARCH_X86_64:${ARCH_X86_64}")

if(APPLE)
  set(ASM_PREFIX_FLAG -DPREFIX) # ass_.* => _ass_.*
elseif(WIN32 AND BITS STREQUAL 32)
  set(ASM_PREFIX_FLAG -DPREFIX)
endif()
# https://metricpanda.com/using-nasm-with-cmake-and-clang
if (CMAKE_ASM_NASM_COMPILER_LOADED)
#    set(INTEL 1)
    if (APPLE)
        set(ASM_FLAGS "${ASM_FLAGS} -f macho${BITS} -DHAVE_ALIGNED_STACK=1") # TODO: -f elf/macho/win${BITTYPE} is cross build only?
    elseif (UNIX)
        set(ASM_FLAGS "${ASM_FLAGS} -f elf${BITS} -DHAVE_ALIGNED_STACK=1")
    elseif (WIN32)
        set(ASM_FLAGS "${ASM_FLAGS} -f win${BITS}")
        if (BITS STREQUAL 64)
            set(ASM_FLAGS "${ASM_FLAGS} -DHAVE_ALIGNED_STACK=1")
        else ()
            set(ASM_FLAGS "${ASM_FLAGS} -DHAVE_ALIGNED_STACK=0 -DPIC")
        endif ()
    endif ()
    set(ASM_FLAGS "${ASM_FLAGS} ${ASM_PREFIX_FLAG} -DHAVE_CPUNOP=0 -Dprivate_prefix=ass") #  private_prefix: x86inc.asm, from Makefile_library.am
endif ()
set(CMAKE_ASM_NASM_FLAGS ${ASM_FLAGS})

if(NOT NO_ASM)
  if(ARCH_X86)
      set(CONFIG_ASM 1)
      file(GLOB SRC_LIST_ASM "${SRC_DIR}/libass/x86/*.asm")
      if(NOT ARCH_X86_64)
#        list(APPEND ASM_NAMES be_blur.asm) # TODO:
      endif()
  endif()
  if(ARCH_AARCH64)
    set(CONFIG_ASM 1)
    file(GLOB SRC_LIST_ASM "${SRC_DIR}/libass/aarch64/*.S")
    add_compile_options(${ASM_PREFIX_FLAG})
  endif()
endif()

aux_source_directory(${SRC_DIR}/libass SRC_LIST)
aux_source_directory(${SRC_DIR}/libass/c SRC_LIST_C)
list(APPEND SRC_LIST ${SRC_LIST_C})


if(WIN32)
  set(CONFIG_DIRECTWRITE 1)
endif()
if(APPLE)
  set(CONFIG_CORETEXT 1)
endif()
if(ENABLE_LARGE_TILES)
  set(CONFIG_LARGE_TILES 1)
else()
  set(CONFIG_LARGE_TILES 0)
endif()

if(CONFIG_CORETEXT)
  list(APPEND EXTRA_LIBS "-framework CoreText" "-framework CoreFoundation" "-framework CoreGraphics")
else()
  list(REMOVE_ITEM SRC_LIST "libass/ass_coretext.c")
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_coretext.c$")
endif()
if(NOT CONFIG_DIRECTWRITE)
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_directwrite.c$")
endif()

# TODO: android
if(UNIX AND NOT APPLE)
  include(FindFontconfig)
endif()
if(NOT Fontconfig_FOUND)
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_fontconfig.c$")
endif()

add_library(ass SHARED ${SRC_LIST})
if(SRC_LIST_ASM)
  add_library(ass_asm OBJECT ${SRC_LIST_ASM}) # DO NOT be ass's source, will include all ass flags, which may be not supported by nasm(-pthread from harfbuzz)
  target_sources(ass PRIVATE $<TARGET_OBJECTS:ass_asm>)
else()
  message(WARNING "libass will not built with asm")
endif()

if(MSVC)
  set(RUNTIME_NAME libass)
else() # mingw
  set(RUNTIME_NAME ass)
endif()
if(MINGW)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic") # or -l:libwinpthread.a will looks up the given name regardless dynamic/static
endif()
set_target_properties(ass PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${SO_VERSION}
  OUTPUT_NAME ass
  RUNTIME_OUTPUT_NAME ${RUNTIME_NAME} # windows msvc, mingw
  CLEAN_DIRECT_OUTPUT 1
  #LINK_SEARCH_START_STATIC 1
  #INTERPROCEDURAL_OPTIMIZATION 1 # android: cmake will force gold linker if CMAKE_ANDROID_NDK_VERSION is not set(e.g. use ndk's cmake toolchain file) or less than 22
  LINK_DEF_FILE_FLAG libass/libass.sym # win def only? no effect?
)

include_directories(
  ${SRC_DIR}/libass
  ${PROJECT_BINARY_DIR}
  ${CMAKE_INSTALL_PREFIX}/include
  ${CMAKE_INSTALL_PREFIX}/include/fribidi
)

check_include_file(dirent.h HAVE_DIRENT_H)
if(NOT HAVE_DIRENT_H)
  include_directories(compat)
endif()

if(TARGET fribidi_static)
    list(APPEND EXTRA_LIBS fribidi_static)
else()
    find_file(FRIBIDI_CMAKE fribidi.cmake HINTS ${CMAKE_INSTALL_PREFIX}/lib/cmake)
    message("FRIBIDI_CMAKE: ${FRIBIDI_CMAKE}")
    find_path(FRIBIDI_INCLUDE_DIR
              NAMES fribidi.h
              HINTS ${CMAKE_INSTALL_PREFIX}
              PATH_SUFFIXES fribidi)
    include_directories(${FRIBIDI_INCLUDE_DIR})
    if(EXISTS ${FRIBIDI_CMAKE})
      include(${FRIBIDI_CMAKE})
      set(FRIBIDI_LIB fribidi_static)
    endif()
    list(APPEND EXTRA_LIBS "${FRIBIDI_LIB}")
endif()
if(TARGET freetype)
    list(APPEND EXTRA_LIBS freetype)
else()
    find_library(FREETYPE_LIBRARIES freetype HINTS "${CMAKE_INSTALL_PREFIX}/lib")
    if(FREETYPE_LIBRARIES)
      include_directories(${CMAKE_INSTALL_PREFIX}/include/freetype2)
    else()
      find_package(freetype)
      message(STATUS "freetype: ${FREETYPE_LIBRARIES}")
      include_directories(${FREETYPE_INCLUDE_DIRS})
    endif()
    list(APPEND EXTRA_LIBS "${FREETYPE_LIBRARIES}")
endif()
if(TARGET harfbuzz)
    list(APPEND EXTRA_LIBS harfbuzz)
else()
    find_library(HARFBUZZ_LIBRARIES harfbuzz HINTS "${CMAKE_INSTALL_PREFIX}/lib")
    find_path(HARFBUZZ_INCLUDE_DIR
            NAMES hb.h
            HINTS ${CMAKE_INSTALL_PREFIX}
            PATHS ${CMAKE_INSTALL_PREFIX}
            PATH_SUFFIXES harfbuzz)
    if(HARFBUZZ_LIBRARIES)
        include_directories(${HARFBUZZ_INCLUDE_DIR} ${CMAKE_INSTALL_PREFIX}/include/harfbuzz)
    endif()
    list(APPEND EXTRA_LIBS "${HARFBUZZ_LIBRARIES}")
endif()

if(WIN32)
  if(WINDOWS_STORE OR WINDOWS_PHONE)
    list(APPEND EXTRA_LIBS "dwrite")
  else()
    list(APPEND EXTRA_LIBS gdi32 user32)
  endif()
endif()
if(APPLE)
  list(APPEND EXTRA_LIBS bz2)
endif()

file(READ ${SRC_DIR}/libass/libass.sym LIB_SYM)
if(CMAKE_C_COMPILER_ABI MATCHES "ELF")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--exclude-libs,ALL")
  target_link_libraries(ass LINK_PRIVATE  -Wl,--version-script=${CMAKE_BINARY_DIR}/.ass.ver)
  string(REGEX REPLACE "\n|\n\r" ";" LIB_SYM ${LIB_SYM})
  file(WRITE ${CMAKE_BINARY_DIR}/.ass.ver "{global:${LIB_SYM}local:*;};")
endif()
if(APPLE)
  string(REGEX REPLACE "ass_" "_ass_" LIB_SYM ${LIB_SYM})
  file(WRITE ${CMAKE_BINARY_DIR}/.ass.export ${LIB_SYM})
  target_link_libraries(ass PRIVATE -Wl,-exported_symbols_list,${CMAKE_BINARY_DIR}/.ass.export) # excluded by shared lib or executable
endif()
if(WIN32)
  file(WRITE "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def" "EXPORTS\n${LIB_SYM}")
  target_sources(ass PRIVATE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def)
  install(FILES ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def DESTINATION lib)
endif()

link_directories("${CMAKE_INSTALL_PREFIX}/lib")
target_link_libraries(ass LINK_PRIVATE "${EXTRA_LIBS}")
file(GLOB HEADERS "libass/ass.h" "libass/ass_types.h")
install(FILES ${HEADERS} DESTINATION include/ass)
install(TARGETS ass EXPORT ${PROJECT_NAME}
  RUNTIME DESTINATION bin # *.dll
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib)
install(EXPORT ${PROJECT_NAME} DESTINATION lib/cmake)

set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix "\${prefix}")
set(libdir "\${exec_prefix}/lib")
set(bindir "\${exec_prefix}/bin")
set(includedir "\${prefix}/include")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
configure_file(
    "${SRC_DIR}/${PROJECT_NAME}.pc.in"
    "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc"
    @ONLY)


add_definitions(-DPIC=1)
foreach(VAR CONFIG_ASM ARCH_X86 ARCH_AARCH64 ARCH_X86_64)
  add_definitions(-D${VAR}=${${VAR}})
endforeach()

# define if 1
foreach(VAR CONFIG_CORETEXT CONFIG_FONTCONFIG CONFIG_DIRECTWRITE CONFIG_FREETYPE CONFIG_FRIBIDI CONFIG_ICONV CONFIG_LIBPNG CONFIG_RASTERIZER CONFIG_LARGE_TILES)
  if(${VAR})
    set(CONF "${CONF}\n#define ${VAR} ${${VAR}}")
  endif()
endforeach()
file(WRITE "${PROJECT_BINARY_DIR}/config.h" "${CONF}")
