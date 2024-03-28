cmake_minimum_required(VERSION 3.15)

project(dav1d VERSION 1.4.1)
include(CheckLibraryExists)
include(CheckCCompilerFlag)
include(CheckCSourceCompiles)
include(CheckIncludeFile)
include(CheckTypeSize)
include(CheckSymbolExists)

# rc
set(API_VERSION_MAJOR 7)
set(API_VERSION_MINOR 0)
set(API_VERSION_REVISION 0)
set(PROJECT_VERSION_REVISION ${PROJECT_VERSION_PATCH})
# version.h
set(DAV1D_API_VERSION_MAJOR ${API_VERSION_MAJOR})
set(DAV1D_API_VERSION_MINOR ${API_VERSION_MINOR})
set(DAV1D_API_VERSION_PATCH ${API_VERSION_REVISION})
# so
set(SO_VERSION ${API_VERSION_MAJOR})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
#list(APPEND CMAKE_FIND_ROOT_PATH ${CMAKE_INSTALL_PREFIX}) # affect yasm probe

if(NOT SRC_DIR)
  set(SRC_DIR ${PROJECT_SOURCE_DIR})
endif()

enable_language(ASM)
enable_language(C)

if(POLICY CMP0069) # lto
  cmake_policy(SET CMP0069 NEW)
endif()
set(EXTRA_LIBS "")

option(DAV1D_NO_ASM "Disable use of assembly coded primitives (default: auto detect)" OFF)
option(STACK_ALIGNMENT "stack alignment" 0)
option(DAV1D_8BIT "enable 8bit. 0 or 1" 1)
option(DAV1D_16BIT "enable 16bit. 0 or 1" 1)

set(DAV1D_BPC)
if(DAV1D_8BIT)
  list(APPEND DAV1D_BPC 8)
endif()
if(DAV1D_16BIT)
  list(APPEND DAV1D_BPC 16)
endif()

set(CONFIG_8BPC ${DAV1D_8BIT})
set(CONFIG_16BPC ${DAV1D_16BIT})
set(CONFIG_LOG 0)
set(ENDIANNESS_BIG 0)
set(ARCH_PPC64LE 0)

set(HAVE_ASM 0) # used by ass_bitmao_engine.c


set(ARCH_ARM 0)       # arm32
set(ARCH_AARCH64 0)
set(ARCH_X86 0) # x86 32/64 bit
set(ARCH_X86_64 0)
set(ARCH_X86_32 0)
set(ARCH_RISCV 0)  # ARCH_RV32/64
set(ARCH_LOONGARCH 0)
set(ARCH_LOONGARCH64 0)
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
  set(ARCH_ARM 1)
elseif(ARCH MATCHES "64")
endif()

set(X86_ALIASES x86 i386 i686 x86_64 amd64 x64)
list(FIND X86_ALIASES "${ARCH}" X86MATCH)
if(X86MATCH GREATER "-1")
  if(NOT DAV1D_NO_ASM)
    enable_language(ASM_NASM)
  endif()
  set(ARCH_X86 1)
  if(BITS EQUAL 64)
    set(ARCH_X86_64 1)
  else()
    set(ARCH_X86_32 1)
  endif()
endif()
message("BITS:${BITS} ARCH:${ARCH}, ARCH_X86: ${ARCH_X86}, ARCH_AARCH64:${ARCH_AARCH64}, ARCH_ARM:${ARCH_ARM}, ARCH_X86_64:${ARCH_X86_64}, ARCH_RISCV:${ARCH_RISCV}, ARCH_LOONGARCH64:${ARCH_LOONGARCH64}. X86MATCH:${X86MATCH}")

if(APPLE)
  set(ASM_PREFIX_FLAG -DPREFIX) # func_.* => _func_.*
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
    set(ASM_FLAGS "${ASM_FLAGS} -I${PROJECT_BINARY_DIR} -I${SRC_DIR}/src")
    set(ASM_FLAGS "${ASM_FLAGS} ${ASM_PREFIX_FLAG} -DHAVE_CPUNOP=0 -Dprivate_prefix=dav1d") #  private_prefix: x86inc.asm, from Makefile_library.am
endif ()

if(ARCH_X86)
  if(STACK_ALIGNMENT)
  elseif(ARCH_X86_64 OR LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux" OR APPLE)
    set(STACK_ALIGNMENT 16)
  else()
    set(STACK_ALIGNMENT 4)
  endif()
  set(ASM_FLAGS "${ASM_FLAGS} -DSTACK_ALIGNMENT=${STACK_ALIGNMENT}")
  check_symbol_exists(__AVX__ "" FORCE_VEX_ENCODING)
  if(FORCE_VEX_ENCODING)
    set(FORCE_VEX_ENCODING 1)
  else()
    set(FORCE_VEX_ENCODING 0)
  endif()
endif()
set(CMAKE_ASM_NASM_FLAGS ${ASM_FLAGS})

if(NOT DAV1D_NO_ASM)
  if(ARCH_X86)
    set(HAVE_ASM 1)
    set(SRC_LIST_C
      ${SRC_DIR}/src/x86/cpu.c
      )
    set(SRC_LIST_ASM
      ${SRC_DIR}/src/x86/cpuid.asm
      ${SRC_DIR}/src/x86/msac.asm
      ${SRC_DIR}/src/x86/refmvs.asm
      ${SRC_DIR}/src/x86/itx_avx512.asm
      ${SRC_DIR}/src/x86/cdef_avx2.asm
      ${SRC_DIR}/src/x86/itx_avx2.asm
      ${SRC_DIR}/src/x86/looprestoration_avx2.asm
      ${SRC_DIR}/src/x86/cdef_sse.asm
      ${SRC_DIR}/src/x86/itx_sse.asm
    )
    if(EXISTS ${SRC_DIR}/src/x86/pal.asm)
      list(APPEND SRC_LIST_ASM
        ${SRC_DIR}/src/x86/pal.asm
      )
    endif()
    if(DAV1D_8BIT)
      list(APPEND SRC_LIST_ASM
        ${SRC_DIR}/src/x86/cdef_avx512.asm
        ${SRC_DIR}/src/x86/filmgrain_avx512.asm
        ${SRC_DIR}/src/x86/ipred_avx512.asm
        ${SRC_DIR}/src/x86/loopfilter_avx512.asm
        ${SRC_DIR}/src/x86/looprestoration_avx512.asm
        ${SRC_DIR}/src/x86/mc_avx512.asm
        ${SRC_DIR}/src/x86/filmgrain_avx2.asm
        ${SRC_DIR}/src/x86/ipred_avx2.asm
        ${SRC_DIR}/src/x86/loopfilter_avx2.asm
        ${SRC_DIR}/src/x86/mc_avx2.asm
        ${SRC_DIR}/src/x86/filmgrain_sse.asm
        ${SRC_DIR}/src/x86/ipred_sse.asm
        ${SRC_DIR}/src/x86/loopfilter_sse.asm
        ${SRC_DIR}/src/x86/looprestoration_sse.asm
        ${SRC_DIR}/src/x86/mc_sse.asm
      )
    endif()
    if(DAV1D_16BIT)
      list(APPEND SRC_LIST_ASM
        ${SRC_DIR}/src/x86/cdef16_avx512.asm
        ${SRC_DIR}/src/x86/filmgrain16_avx512.asm
        ${SRC_DIR}/src/x86/ipred16_avx512.asm
        ${SRC_DIR}/src/x86/itx16_avx512.asm
        ${SRC_DIR}/src/x86/loopfilter16_avx512.asm
        ${SRC_DIR}/src/x86/looprestoration16_avx512.asm
        ${SRC_DIR}/src/x86/mc16_avx512.asm
        ${SRC_DIR}/src/x86/cdef16_avx2.asm
        ${SRC_DIR}/src/x86/filmgrain16_avx2.asm
        ${SRC_DIR}/src/x86/ipred16_avx2.asm
        ${SRC_DIR}/src/x86/itx16_avx2.asm
        ${SRC_DIR}/src/x86/loopfilter16_avx2.asm
        ${SRC_DIR}/src/x86/looprestoration16_avx2.asm
        ${SRC_DIR}/src/x86/mc16_avx2.asm
        ${SRC_DIR}/src/x86/cdef16_sse.asm
        ${SRC_DIR}/src/x86/filmgrain16_sse.asm
        ${SRC_DIR}/src/x86/ipred16_sse.asm
        ${SRC_DIR}/src/x86/itx16_sse.asm
        ${SRC_DIR}/src/x86/loopfilter16_sse.asm
        ${SRC_DIR}/src/x86/looprestoration16_sse.asm
        ${SRC_DIR}/src/x86/mc16_sse.asm
        )
    endif()
  endif()
  set(HAS_ASM_COMPILER TRUE)
  if(ARCH_AARCH64 AND CMAKE_C_COMPILER_ID MATCHES "MSVC")
    if(0)#CMAKE_VERSION VERSION_GREATER_EQUAL 3.26.0)
        enable_language(ASM_MARMASM)
# TODO: armasm requires gaspp
    else()
        set(ARM64ASM_CLANG_CL 1)
    endif()
# Fix:  MSVC_RUNTIME_LIBRARY value 'MultiThreadedDLL' not known for this ASM
    set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreaded         "-MT"  CACHE STRING "armasm64/clang-cl MSVC_RUNTIME_LIBRARY flags")
    set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDLL      "-MD"  CACHE STRING "armasm64/clang-cl MSVC_RUNTIME_LIBRARY flags")
    set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDebug    "-MTd" CACHE STRING "armasm64/clang-cl MSVC_RUNTIME_LIBRARY flags")
    set(CMAKE_ASM_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_MultiThreadedDebugDLL "-MDd" CACHE STRING "armasm64/clang-cl MSVC_RUNTIME_LIBRARY flags")
  endif()
  if(ARM64ASM_CLANG_CL)
    execute_process(
        COMMAND clang-cl --version
        ERROR_VARIABLE CLANG_ERROR
        OUTPUT_QUIET
    )
    if(NOT CLANG_ERROR)
      set(CMAKE_ASM_COMPILER clang-cl)
      set(CMAKE_ASM_FLAGS "--target=aarch64-pc-windows-msvc ${CMAKE_ASM_FLAGS}")
      message("using clang-cl as arm64 asm compiler... CMAKE_ASM_FLAGS:${CMAKE_ASM_FLAGS}")
      add_link_options(-ALIGN:8192) # blend_bitmaps.S.obj : fatal error LNK1164: section 0x4 alignment (8192) greater than /ALIGN value
    else()
      set(HAS_ASM_COMPILER FALSE)
    endif()
  endif()
  if((ARCH_ARM OR ARCH_AARCH64) AND HAS_ASM_COMPILER)
    set(HAVE_ASM 1)
    add_compile_options(${ASM_PREFIX_FLAG})
    set(SRC_LIST_C
      ${SRC_DIR}/src/arm/cpu.c
      )
    set(SRC_LIST_ASM
      ${SRC_DIR}/src/arm/${BITS}/itx.S
      ${SRC_DIR}/src/arm/${BITS}/looprestoration_common.S
      ${SRC_DIR}/src/arm/${BITS}/msac.S
      ${SRC_DIR}/src/arm/${BITS}/refmvs.S
    )
    if(DAV1D_8BIT)
      list(APPEND SRC_LIST_ASM
        ${SRC_DIR}/src/arm/${BITS}/cdef.S
        ${SRC_DIR}/src/arm/${BITS}/filmgrain.S
        ${SRC_DIR}/src/arm/${BITS}/ipred.S
        ${SRC_DIR}/src/arm/${BITS}/loopfilter.S
        ${SRC_DIR}/src/arm/${BITS}/looprestoration.S
        ${SRC_DIR}/src/arm/${BITS}/mc.S
        )
    endif()
    if(DAV1D_16BIT)
      list(APPEND SRC_LIST_ASM
        ${SRC_DIR}/src/arm/${BITS}/cdef16.S
        ${SRC_DIR}/src/arm/${BITS}/filmgrain16.S
        ${SRC_DIR}/src/arm/${BITS}/ipred16.S
        ${SRC_DIR}/src/arm/${BITS}/itx16.S
        ${SRC_DIR}/src/arm/${BITS}/loopfilter16.S
        ${SRC_DIR}/src/arm/${BITS}/looprestoration16.S
        ${SRC_DIR}/src/arm/${BITS}/mc16.S
        )
    endif()
  endif()
  if(ARCH_ARM OR ARCH_AARCH64)
    check_c_source_compiles("
    __asm__ (
        .func meson_test
        .
        );
    " HAVE_AS_FUNC)
    if(HAVE_AS_FUNC)
      add_compile_options(-DHAVE_AS_FUNC=$<BOOL:HAVE_AS_FUNC>)
    endif()
  endif()
  if(ARCH_RISCV)
    set(HAVE_ASM 1)
    set(ARCH_RV${BITS} 1)
    set(SRC_LIST_C
      ${SRC_DIR}/src/riscv/cpu.c
      )
    set(SRC_LIST_ASM
      ${SRC_DIR}/src/riscv/${BITS}/itx.S
    )
  endif()
  if(ARCH_LOONGARCH)
    set(ARCH_LOONGARCH${BITS} 1)
    set(HAVE_ASM 1)
    set(SRC_LIST_C
      ${SRC_DIR}/src/loongarch/cpu.c
      )
    set(SRC_LIST_ASM
      ${SRC_DIR}/src/loongarch/mc.S
      ${SRC_DIR}/src/loongarch/loopfilter.S
      ${SRC_DIR}/src/loongarch/looprestoration.S
      ${SRC_DIR}/src/loongarch/msac.S
      ${SRC_DIR}/src/loongarch/refmvs.S
      ${SRC_DIR}/src/loongarch/itx.S
    )
    set(SRC_LIST_TMP # TODO: add static/object targets per bit depth: -DBITDEPTH=8/16 + flags
      ${SRC_DIR}/src/loongarch/looprestoration_tmpl.c
    )
  endif()
endif()
add_compile_options(-DTRIM_DSP_FUNCTIONS=1)

aux_source_directory(${SRC_DIR}/src SRC_LIST)
set(SRC_LIST_TMPL ${SRC_LIST})
list(FILTER SRC_LIST EXCLUDE REGEX "_tmpl")
list(FILTER SRC_LIST_TMPL INCLUDE REGEX "_tmpl")

list(APPEND SRC_LIST ${SRC_LIST_C})

if(WIN32)
  if(CMAKE_C_SIMULATE_ID MATCHES MSVC)
    set(CMAKE_RC_FLAGS "-C 1252") # llvm-rc:  Non-ASCII 8-bit codepoint (169) can't occur in a non-Unicode string. "Copyright => L"Copyright
  endif()
  configure_file(${SRC_DIR}/src/dav1d.rc.in ${PROJECT_BINARY_DIR}/dav1d.rc)
  list(APPEND SRC_LIST
    ${SRC_DIR}/src/win32/thread.c
    ${PROJECT_BINARY_DIR}/dav1d.rc
    )
endif()


include_directories(
  ${SRC_DIR}
  ${SRC_DIR}/include
  ${PROJECT_BINARY_DIR}
)

if(WIN32)
  add_compile_definitions(DAV1D_BUILDING_DLL)
  if(MSVC)
    add_compile_options(-D_CRT_DECLARE_NONSTDC_NAMES=1)
    # tools: -Dfseeko=_fseeki64 -Dftello=_ftelli64)
    check_include_file(stdatomic.h HAS_stdatomic.h)
    if(NOT ${HAS_stdatomic.h})
      include_directories(${SRC_DIR}/include/compat/msvc)
    endif()
  endif()
endif()
find_package(Threads)
#link_libraries(Threads::Threads) # will add -pthread in nasm flags. link_libraries() affect targets ONLY add later

if(NOT WIN32)
  add_compile_options(-DHAVE_DLSYM=1 -DHAVE_CLOCK_GETTIME=1 -DHAVE_POSIX_MEMALIGN=1)
  check_symbol_exists(elf_aux_info "sys/auxv.h" HAVE_ELF_AUX_INFO) #arm, ppc
  if(HAVE_ELF_AUX_INFO)
    add_compile_options(-DHAVE_ELF_AUX_INFO=${HAVE_ELF_AUX_INFO})
  endif()
  check_symbol_exists(getauxval "sys/auxv.h" HAVE_GETAUXVAL) #linux arm, ppc
  if(HAVE_GETAUXVAL)
    add_compile_options(-DHAVE_GETAUXVAL=${HAVE_GETAUXVAL}) # arm, android 18+
  endif()
  add_compile_options($<$<COMPILE_LANGUAGE:C>:-D_GNU_SOURCE>)
  link_libraries(dl)
  if(NOT ANDROID)
    link_libraries(pthread)
  endif()
  check_c_source_compiles("int main() { int v = 0; return __atomic_fetch_add(&v, 1, __ATOMIC_SEQ_CST); }"
    HAS_ATOMIC)
  if(${HAS_ATOMIC})
    include_directories(${SRC_DIR}/include/compat/gcc)
  endif()
  check_include_file(pthread_np.h HAS_pthread_np.h)
  if(${HAS_pthread_np.h})
    add_compile_definitions(HAVE_PTHREAD_NP_H)
  endif()
  check_library_exists(pthread pthread_getaffinity_np "" HAVE_PTHREAD_SETAFFINITY_NP) # libc
endif()
if(MSVC)
  add_compile_options(-DHAVE_ALIGNED_MALLOC=1) # GetThreadGroupAffinity: win7
  add_compile_options("$<$<COMPILE_LANGUAGE:C>:-wd4028;-wd4090;-wd4996>")

  add_compile_options_if_supported(-experimental:c11atomics)
else()
  add_compile_options("$<$<COMPILE_LANGUAGE:C>:-ffast-math;-Wundef;-Werror=vla;-Wno-uninitialized;-Wno-missing-field-initializers;-Wno-unused-parameter;-Wstrict-prototypes;-Werror=missing-prototypes>")
  if(ARCH_X86)
    add_compile_options("$<$<COMPILE_LANGUAGE:C>:-msse2;-mfpmath=sse>")
  endif()
endif()


add_library(${PROJECT_NAME} SHARED ${SRC_LIST})

foreach(BPC ${DAV1D_BPC})
  add_library(${PROJECT_NAME}${BPC} OBJECT ${SRC_LIST_TMPL}) # TODO: build dir?
  target_compile_options(${PROJECT_NAME}${BPC} PRIVATE -DBITDEPTH=${BPC})
  target_sources(${PROJECT_NAME} PRIVATE $<TARGET_OBJECTS:${PROJECT_NAME}${BPC}>)
endforeach()

if(SRC_LIST_ASM)
  add_library(${PROJECT_NAME}simd OBJECT ${SRC_LIST_ASM}) # DO NOT be ass's source, will include all ass flags, which may be not supported by nasm(-pthread from harfbuzz)
  target_sources(${PROJECT_NAME} PRIVATE $<TARGET_OBJECTS:${PROJECT_NAME}simd>)
else()
  message(WARNING "${PROJECT_NAME} will not built with simd")
endif()

if(MSVC)
  set(RUNTIME_NAME lib${PROJECT_NAME})
else() # mingw
  set(RUNTIME_NAME ${PROJECT_NAME})
endif()
if(MINGW)
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-Bstatic -lwinpthread -Wl,-Bdynamic") # or -l:libwinpthread.a will looks up the given name regardless dynamic/static
endif()
set_target_properties(${PROJECT_NAME} PROPERTIES
  VERSION ${PROJECT_VERSION}
  SOVERSION ${SO_VERSION}
  OUTPUT_NAME ${PROJECT_NAME}
  RUNTIME_OUTPUT_NAME ${RUNTIME_NAME} # windows msvc, mingw
  CLEAN_DIRECT_OUTPUT 1
  #LINK_SEARCH_START_STATIC 1
  ##LINK_DEF_FILE_FLAG libass/libass.sym # win def only? no effect?
)

if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  set_target_properties(${PROJECT_NAME} PROPERTIES
    MACOSX_RPATH ON
    FRAMEWORK ON
    MACOSX_FRAMEWORK_IDENTIFIER com.mediadevkit.${PROJECT_NAME}
    MACOSX_FRAMEWORK_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    #MACOSX_FRAMEWORK_INFO_PLIST
    #XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY
    FRAMEWORK_VERSION A # codesign assumes framework version is A
  )
endif()

target_link_libraries(${PROJECT_NAME} LINK_PRIVATE "${EXTRA_LIBS}")

configure_file(
    "${SRC_DIR}/include/dav1d/version.h.in"
    "${PROJECT_BINARY_DIR}/version.h"
    @ONLY)
file(GLOB HEADERS "${SRC_DIR}/include/dav1d/*.h")
list(APPEND HEADERS "${PROJECT_BINARY_DIR}/version.h")
install(FILES ${HEADERS} DESTINATION include/${PROJECT_NAME})
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}
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
#configure_file(
#    "${SRC_DIR}/${PROJECT_NAME}.pc.in"
#    "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.pc"
#    @ONLY)


add_definitions(-DPIC=1) # x86 only?
foreach(VAR HAVE_ASM ARCH_X86 ARCH_AARCH64 ARCH_X86_64 ARCH_X86_32 ARCH_ARM ARCH_RISCV ARCH_LOONGARCH ARCH_LOONGARCH64)
  add_definitions(-D${VAR}=${${VAR}})
endforeach()

# define if 1
foreach(VAR CONFIG_8BPC CONFIG_16BPC CONFIG_LOG ENDIANNESS_BIG ARCH_PPC64LE)
  if(${${VAR}}) # ON/OFF => 1/0
    set(${VAR} 1)
  else()
    set(${VAR} 0)
  endif()
  set(CONF "${CONF}\n#define ${VAR} ${${VAR}}")
endforeach()
file(GENERATE OUTPUT "${PROJECT_BINARY_DIR}/config.h" CONTENT "${CONF}")

# private_prefix, PIC, PREFIX
foreach(VAR STACK_ALIGNMENT ARCH_X86_64 ARCH_X86_32 FORCE_VEX_ENCODING)
  set(CONF_ASM "${CONF_ASM}\n%define ${VAR} ${${VAR}}")
endforeach()
file(GENERATE OUTPUT "${PROJECT_BINARY_DIR}/config.asm" CONTENT "${CONF_ASM}")

find_package(Git QUIET)
if(GIT_FOUND)
  execute_process(
      COMMAND "${GIT_EXECUTABLE}" describe --long --always # requires git clone depth > 1
      WORKING_DIRECTORY "${SRC_DIR}"
      RESULT_VARIABLE RET
      OUTPUT_VARIABLE VCS_TAG
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()
configure_file(
    "${SRC_DIR}/include/vcs_version.h.in"
    "${PROJECT_BINARY_DIR}/vcs_version.h"
    @ONLY)
