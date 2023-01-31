cmake_minimum_required(VERSION 3.10)

project(devpkgs C CXX ASM)

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
endif()
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)


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


set(FT_DISABLE_BROTLI 1)
set(FT_DISABLE_PNG 1)
add_subdirectory(src/freetype)

set(HB_BUILD_SUBSET 0)
add_subdirectory(src/harfbuzz)

add_subdirectory(projects)

set(SNAPPY_BUILD_TESTS 0)
set(SNAPPY_BUILD_BENCHMARKS 0)
add_subdirectory(src/snappy)