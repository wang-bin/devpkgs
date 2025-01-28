cmake_minimum_required(VERSION 3.15)

#libshaderc_shared.tbd: too many exported symbols if gen from dylib
project(shaderc_loader VERSION 2024.4.1 DESCRIPTION "shaderc loader" LANGUAGES CXX)
set(PROJECT_VERSION_TWEAK 0)

set(SHADERC_INCLUDE "${CMAKE_CURRENT_SOURCE_DIR}/../shaderc/libshaderc/include" CACHE STRING "shaderc include dir")

include_directories(${SHADERC_INCLUDE})
add_library(${PROJECT_NAME} STATIC shaderc_loader.cpp)

set(LIBS -l${PROJECT_NAME})
if(LINUX)
  set(LIBS "${LIBS} -ldl")
endif()
if(NOT MSVC)
  if(USE_LIBCXX OR APPLE)
    set(LIBS "${LIBS} -lc++")
    if(LINUX)
      set(LIBS "${LIBS} -lcppcompat")
    endif()
  else()
    set(LIBS "${LIBS} -lstdc++")
  endif()
endif()
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/shaderc.pc.in
  ${CMAKE_CURRENT_BINARY_DIR}/shaderc.pc
  @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/shaderc.pc
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} # *.dll
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  FRAMEWORK DESTINATION ${CMAKE_INSTALL_LIBDIR}
  )
install(EXPORT ${PROJECT_NAME} DESTINATION lib/cmake)
install(
  FILES
    ${SHADERC_INCLUDE}/shaderc/env.h
    ${SHADERC_INCLUDE}/shaderc/status.h
    ${SHADERC_INCLUDE}/shaderc/visibility.h
    ${SHADERC_INCLUDE}/shaderc/shaderc.h
    ${SHADERC_INCLUDE}/shaderc/shaderc.hpp
  DESTINATION
    ${CMAKE_INSTALL_INCLUDEDIR}/shaderc)
