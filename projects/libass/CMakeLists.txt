cmake_minimum_required(VERSION 3.15)

# https://github.com/hozuki/libass-cmake/blob/master/cmake/libass.cmake

PROJECT(libass VERSION 0.17.2) # TODO: read from RELEASEVERSION since 0.17.2
set(CMAKE_C_VISIBILITY_PRESET default) # hidden symbols can not be exported via libass.sym
include(CheckCCompilerFlag)
include(CheckIncludeFile)
include(CheckTypeSize)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
#list(APPEND CMAKE_FIND_ROOT_PATH ${CMAKE_INSTALL_PREFIX}) # affect yasm probe

if(NOT SRC_DIR)
  set(SRC_DIR ${PROJECT_SOURCE_DIR})
endif()

file(STRINGS ${SRC_DIR}/libass/Makefile_library.am VERSION_LINES LIMIT_COUNT 4)
foreach(VLINE ${VERSION_LINES})
  if(VLINE MATCHES "^[\t ]*LIBASS_LT_CURRENT[\t ]*=[\t ]*([0-9]+)")
    set(LT_CURREN "${CMAKE_MATCH_1}")
  elseif(VLINE MATCHES "^[\t ]*LIBASS_LT_REVISION[\t ]*=[\t ]*([0-9]+)")
    set(LT_REVISIO "${CMAKE_MATCH_1}")
  elseif(VLINE MATCHES "^[\t ]*LIBASS_LT_AGE[\t ]*=[\t ]*([0-9]+)")
    set(LT_AGE "${CMAKE_MATCH_1}")
  endif()
endforeach()
math(EXPR SO_VERSION "${LT_CURREN} - ${LT_AGE}")

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
option(LIBASS_MSVC_ARM64_ASM "Enable arm64 asm for msvc. requires clang-cl <= 16." OFF)

set(CONFIG_ASM 0) # used by ass_bitmao_engine.c
set(CONFIG_FREETYPE 1) #required
set(CONFIG_FRIBIDI 1) #required
set(CONFIG_ICONV 0)

set(ARCH_AARCH64 0)
set(ARCH_X86 0) # x86 32/64 bit
set(ARCH_X86_64 0)
math(EXPR BITS "8 * ${CMAKE_SIZEOF_VOID_P}")

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
    if(BITS EQUAL 64)
        set(ARCH_X86_64 1)
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
  set(HAS_ASM_COMPILER TRUE)
  if(ARCH_AARCH64 AND CMAKE_C_COMPILER_ID MATCHES "MSVC")
# clang-cl 17+ with link.exe: blend_bitmaps.S.obj : fatal error LNK1183: invalid or corrupt file: extended relocation count 0 less than 65535
#    enable_language(ASM_MARMASM) and set_source_files_properties(... PROPERTIES LANGUAGE ASM_MARMASM) # requires cmake 3.26 and gas-preprocess.pl -arch aarch64 -as-type armasm -- cl x.S
    execute_process(
        COMMAND clang-cl --version
        ERROR_VARIABLE CLANG_ERROR
        OUTPUT_VARIABLE CLANG_VER_STR
    )
    message("CLANG_VER_STR: ${CLANG_VER_STR}")
    if(NOT CLANG_ERROR AND LIBASS_MSVC_ARM64_ASM)
      set(CMAKE_ASM_COMPILER clang-cl)
      set(CMAKE_ASM_FLAGS "--target=aarch64-pc-windows-msvc ${CMAKE_ASM_FLAGS}")
      message("using clang-cl as arm64 asm compiler... CMAKE_ASM_FLAGS:${CMAKE_ASM_FLAGS}")
      # clang-18: warning LNK4108: /ALIGN specified without /DRIVER; image may not run. blend_bitmaps.S.obj : fatal error LNK1183: invalid or corrupt file: extended relocation count 0 less than 65535
      #add_link_options(-ALIGN:8192) # clang-16 blend_bitmaps.S.obj : fatal error LNK1164: section 0x4 alignment (8192) greater than /ALIGN value
# Fix:  MSVC_RUNTIME_LIBRARY value 'MultiThreadedDLL' not known for this ASM
      set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreaded         "-MT"  CACHE STRING "clang-cl arm64 asm MSVC_RUNTIME_LIBRARY flags")
      set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL      "-MD"  CACHE STRING "clang-cl arm64 asm MSVC_RUNTIME_LIBRARY flags")
      set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDebug    "-MTd" CACHE STRING "clang-cl arm64 asm MSVC_RUNTIME_LIBRARY flags")
      set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDebugDLL "-MDd" CACHE STRING "clang-cl arm64 asm MSVC_RUNTIME_LIBRARY flags")
    else()
      set(HAS_ASM_COMPILER FALSE)
    endif()
  endif()
  if(ARCH_AARCH64 AND HAS_ASM_COMPILER)
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
if(ANDROID)
  set(CONFIG_ANDROID 1)
endif()
if(ENABLE_LARGE_TILES)
  set(CONFIG_LARGE_TILES 1)
else()
  set(CONFIG_LARGE_TILES 0)
endif()

if(CONFIG_CORETEXT)
  list(APPEND EXTRA_LIBS "-framework CoreText" "-framework CoreFoundation" "-framework CoreGraphics")
else()
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_coretext.c$")
endif()
if(NOT CONFIG_DIRECTWRITE)
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_directwrite.c$")
endif()
if(CONFIG_ANDROID)
  list(APPEND EXTRA_LIBS log)
else()
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_androidfonts.c$")
endif()

# TODO: android
if(UNIX AND NOT APPLE)
  include(FindFontconfig)
endif()
if(NOT Fontconfig_FOUND)
  list(FILTER SRC_LIST EXCLUDE REGEX ".*ass_fontconfig.c$")
endif()

add_library(ass-objs OBJECT ${SRC_LIST})
add_library(ass SHARED $<TARGET_OBJECTS:ass-objs>)
add_library(libass STATIC $<TARGET_OBJECTS:ass-objs>)

if(SRC_LIST_ASM)
  # FIXME: why -MT is used?
  add_library(ass_asm OBJECT ${SRC_LIST_ASM}) # DO NOT be ass's source, will include all ass flags, which may be not supported by nasm(-pthread from harfbuzz)
  target_sources(ass PUBLIC $<TARGET_OBJECTS:ass_asm>)
  target_sources(libass PUBLIC $<TARGET_OBJECTS:ass_asm>)
else()
  message(WARNING "libass will not built with asm")
endif()

set(PUBLIC_HEADERS
  ${SRC_DIR}/libass/ass.h
  ${SRC_DIR}/libass/ass_types.h
  )
if(MSVC)
  set(RUNTIME_NAME libass)
else() # mingw
  set(RUNTIME_NAME ass)
  set_target_properties(libass PROPERTIES OUTPUT_NAME ass) # libass.lib is static for msvc
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
  LINK_DEF_FILE_FLAG libass/libass.sym # win def only? no effect?
)

if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  set_target_properties(ass PROPERTIES
    MACOSX_RPATH ON
    FRAMEWORK ON
    MACOSX_FRAMEWORK_IDENTIFIER com.mediadevkit.${PROJECT_NAME}
    MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    #MACOSX_FRAMEWORK_INFO_PLIST
    #XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY
    FRAMEWORK_VERSION A # codesign assumes framework version is A
    PUBLIC_HEADER "${PUBLIC_HEADERS}"
  )
endif()

include_directories(
  ${SRC_DIR}/libass
  ${PROJECT_BINARY_DIR}
)

check_include_file(dirent.h HAVE_DIRENT_H)
if(NOT HAVE_DIRENT_H)
  include_directories(compat)
endif()
if(MSVC)
  set(HAVE_STRDUP 0)
else()
  set(HAVE_STRDUP 1)
endif()
#HAVE_AS_FUNC
#HAVE_C11_GENERIC

if(TARGET fribidi_static)
    list(APPEND EXTRA_LIBS fribidi_static)
else()
    find_package(fribidi REQUIRED)
    target_link_libraries(ass-objs PUBLIC fribidi_static)
endif()
if(TARGET freetype)
    list(APPEND EXTRA_LIBS freetype)
else()
    find_package(Freetype REQUIRED)
    target_link_libraries(ass-objs PUBLIC Freetype::Freetype)
    find_package(ZLIB)
    if(ZLIB_FOUND)
        target_link_libraries(ass PUBLIC ZLIB::ZLIB)
    endif()
endif()
if(TARGET harfbuzz)
    list(APPEND EXTRA_LIBS harfbuzz)
else()
    find_package(harfbuzz REQUIRED)
    target_link_libraries(ass-objs PUBLIC harfbuzz::harfbuzz)
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
# '\n' after global:is required, otherwise global:ass_library_init is treated as a symbol
  file(WRITE ${CMAKE_BINARY_DIR}/.ass.ver "{global:\n${LIB_SYM}\nlocal:\n*;};")
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

target_link_libraries(ass-objs LINK_PUBLIC "${EXTRA_LIBS}")
target_link_libraries(ass LINK_PRIVATE "${EXTRA_LIBS}")
target_link_libraries(libass LINK_PRIVATE "${EXTRA_LIBS}")
install(FILES
    ${SRC_DIR}/libass/ass.h
    ${SRC_DIR}/libass/ass_types.h
    DESTINATION include/ass)
install(TARGETS ass libass EXPORT ${PROJECT_NAME}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} # *.dll
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  FRAMEWORK DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
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
foreach(VAR
    HAVE_STRDUP
    CONFIG_ANDROID
    CONFIG_CORETEXT CONFIG_FONTCONFIG CONFIG_DIRECTWRITE CONFIG_FREETYPE CONFIG_FRIBIDI CONFIG_ICONV CONFIG_LIBPNG CONFIG_RASTERIZER CONFIG_LARGE_TILES)
  if(${VAR})
    set(CONF "${CONF}\n#define ${VAR} ${${VAR}}")
  endif()
endforeach()
file(GENERATE OUTPUT "${PROJECT_BINARY_DIR}/config.h" CONTENT "${CONF}")
