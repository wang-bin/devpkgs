cmake_minimum_required(VERSION 3.15)

project(fribidi)

set(VERSION_MAJOR 1)
set(VERSION_MINOR 0)
set(VERSION_MICRO 12)
set(PROJECT_VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO})
set(SO_VERSION ${VERSION_MAJOR})

set(PACKAGE "${PROJECT_NAME}")
set(PACKAGE_NAME "GNU Fribidi")
set(PACKAGE_BUGREPORT "https://github.com/fribidi/fribidi/issues/new")
set(FRIBIDI_VERSION "${PROJECT_VERSION}")
set(FRIBIDI_MAJOR_VERSION "${VERSION_MAJOR}")
set(FRIBIDI_MINOR_VERSION "${VERSION_MINOR}")
set(FRIBIDI_MICRO_VERSION "${VERSION_MICRO}")
set(FRIBIDI_INTERFACE_VERSION 4)

option(FRIBIDI_SHARED "build shared lib" OFF) # win: dllimport function are not allowed to have a body (fribidi_shape_arabic)
option(FRIBIDI_GENTAB "build gen tab" OFF)
include(CheckIncludeFile)
include(CheckTypeSize)

if(NOT SRC_DIR)
  set(SRC_DIR ${PROJECT_SOURCE_DIR})
endif()

CONFIGURE_FILE(
    "${SRC_DIR}/lib/fribidi-config.h.in"
    "${PROJECT_BINARY_DIR}/fribidi-config.h")

add_definitions(-DHAVE_CONFIG_H)

include(fribidi-lib.cmake)
message("CMAKE_CROSSCOMPILING: ${CMAKE_CROSSCOMPILING}")
if(FRIBIDI_GENTAB)
  include(fribidi-gen.cmake)
  foreach(tgt ${FRIBIDI_TARGETS})
    add_dependencies(${tgt} gen_tab)
  endforeach()
else()
  if(NOT EXISTS "${SRC_DIR}/gen.tab/fribidi-unicode-version.h")
    MESSAGE(WARNING "Run host build to generate intermedia files first. 'make gen_tab'")
  endif()
endif()

foreach(tgt ${FRIBIDI_TARGETS})
    target_include_directories(${tgt}
        PUBLIC
            $<INSTALL_INTERFACE:include>
            $<INSTALL_INTERFACE:include/fribidi>
            $<BUILD_INTERFACE:${SRC_DIR}/lib>
            $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}> # fribidi-config.h
            $<BUILD_INTERFACE:${SRC_DIR}/gen.tab> # fribidi-unicode-version.h
    )
endforeach()

# Needed for fribidi.pc.in
set(prefix ${CMAKE_INSTALL_PREFIX})
set(exec_prefix "\${prefix}")
set(libdir "\${exec_prefix}/lib${LIB_SUFFIX}")
set(bindir "\${exec_prefix}/bin")
set(includedir "\${prefix}/include")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
set(VERSION "${PROJECT_VERSION}")

CONFIGURE_FILE(
    "${SRC_DIR}/${PROJECT_NAME}.pc.in"
    "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc"
    @ONLY)

CHECK_INCLUDE_FILE(memory.h HAVE_MEMORY_H)
CHECK_INCLUDE_FILE(stdlib.h HAVE_STDLIB_H)
set(HAVE_STRINGIZE 1)
CHECK_INCLUDE_FILE(string.h HAVE_STRING_H)
CHECK_TYPE_SIZE(wchar_t SIZEOF_WCHAR_T)
CHECK_INCLUDE_FILE(stddef.h STDC_HEADERS)
CHECK_INCLUDE_FILE(sys/times.h HAVE_SYS_TIMES_H)

FOREACH(VAR HAVE_MEMORY_H HAVE_STDINT_H HAVE_STDLIB_H HAVE_STRINGIZE HAVE_STRING_H STDC_HEADERS)
  if(${VAR})
    set(CONF "${CONF}\n#define ${VAR} ${${VAR}}")
  endif()
ENDFOREACH()
file(WRITE "${PROJECT_BINARY_DIR}/config.h" "${CONF}")

install(EXPORT ${PROJECT_NAME}
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
    FILE ${PROJECT_NAME}-config.cmake
    )