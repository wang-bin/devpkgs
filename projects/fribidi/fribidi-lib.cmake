aux_source_directory(${SRC_DIR}/lib FRIBIDI_SRC)
list(APPEND FRIBIDI_SRC
    ${SRC_DIR}/lib/arabic-misc.tab.i
)

file(READ ${SRC_DIR}/lib/fribidi.def DEF_CONTENT)
file(WRITE "${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def" "EXPORTS\n${DEF_CONTENT}")
add_library(fribidi_static STATIC ${FRIBIDI_SRC})
target_compile_definitions(fribidi_static PRIVATE FRIBIDI_LIB_STATIC)
set(FRIBIDI_TARGETS fribidi_static)
# TODO:
file(GLOB HEADERS "fribidi*.h" "${PROJECT_SOURCE_DIR}/gen.tab/fribidi-*.h" "${PROJECT_BINARY_DIR}/fribidi-*.h")

if(FRIBIDI_SHARED)
    add_library(fribidi_shared SHARED ${FRIBIDI_SRC} ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def)
    set_target_properties(fribidi_shared PROPERTIES
        VERSION ${PROJECT_VERSION}
        SOVERSION ${SO_VERSION}
        OUTPUT_NAME "fribidi"
        CLEAN_DIRECT_OUTPUT 1
        PUBLIC_HEADER "${HEADERS}"
        #LINK_DEF_FILE_FLAG ${SRC_DIR}/lib/fribidi.def # TODO:
        )
    list(APPEND FRIBIDI_TARGETS fribidi_shared)
endif()

#static lib use name libxxx.lib, shared lib use xxx.lib, like ucrt does
if(MSVC)
  set_target_properties(fribidi_static PROPERTIES OUTPUT_NAME "lib${PROJECT_NAME}")
else()
  set_target_properties(fribidi_static PROPERTIES OUTPUT_NAME "${PROJECT_NAME}")
endif()
set_target_properties(fribidi_static PROPERTIES CLEAN_DIRECT_OUTPUT 1)

if(WIN32)
  install(FILES ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.def DESTINATION lib)
endif()
install(TARGETS ${FRIBIDI_TARGETS}
  EXPORT ${PROJECT_NAME}
  RUNTIME DESTINATION bin # *.dll COMPONENT bin
  LIBRARY DESTINATION lib COMPONENT shlib
  ARCHIVE DESTINATION lib COMPONENT dev
  PUBLIC_HEADER DESTINATION include/${PROJECT_NAME} COMPONENT dev
)
