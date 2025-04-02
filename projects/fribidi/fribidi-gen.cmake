set(SRC_GEN_DIR ${SRC_DIR}/gen.tab)
add_executable(gen-unicode-version ${SRC_GEN_DIR}/gen-unicode-version.c)
add_executable(gen-bidi-type-tab ${SRC_GEN_DIR}/gen-bidi-type-tab.c ${SRC_GEN_DIR}/packtab.c)
add_executable(gen-brackets-tab ${SRC_GEN_DIR}/gen-brackets-tab.c ${SRC_GEN_DIR}/packtab.c)
add_executable(gen-brackets-type-tab ${SRC_GEN_DIR}/gen-brackets-type-tab.c ${SRC_GEN_DIR}/packtab.c)
add_executable(gen-joining-type-tab ${SRC_GEN_DIR}/gen-joining-type-tab.c ${SRC_GEN_DIR}/packtab.c)
add_executable(gen-arabic-shaping-tab ${SRC_GEN_DIR}/gen-arabic-shaping-tab.c)
add_executable(gen-mirroring-tab ${SRC_GEN_DIR}/gen-mirroring-tab.c ${SRC_GEN_DIR}/packtab.c)

add_dependencies(gen-bidi-type-tab gen-unicode-version)
add_dependencies(gen-brackets-tab gen-unicode-version)
add_dependencies(gen-brackets-type-tab gen-unicode-version)
add_dependencies(gen-joining-type-tab gen-unicode-version)
add_dependencies(gen-arabic-shaping-tab gen-unicode-version)
add_dependencies(gen-mirroring-tab gen-unicode-version)

# TODO: use OUTPUT instead of TARGET
add_custom_command(TARGET gen-unicode-version POST_BUILD
  COMMAND gen-unicode-version unidata/ReadMe.txt unidata/BidiMirroring.txt gen-unicode-version.c >fribidi-unicode-version.h
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-bidi-type-tab POST_BUILD
  #COMMAND gen-bidi-type-tab unidata/DerivedBidiClass.txt fribidi-unicode-version.h gen-bidi-type-tab.c packtab.c packtab.h > derived_bidi-type.tab.i
  COMMAND gen-bidi-type-tab 2 unidata/UnicodeData.txt > bidi-type.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-joining-type-tab POST_BUILD
  COMMAND gen-joining-type-tab 2 unidata/UnicodeData.txt unidata/ArabicShaping.txt >joining-type.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-arabic-shaping-tab POST_BUILD
  COMMAND gen-arabic-shaping-tab 2 unidata/UnicodeData.txt >arabic-shaping.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-mirroring-tab POST_BUILD
  COMMAND gen-mirroring-tab 2 unidata/BidiMirroring.txt >mirroring.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-brackets-tab POST_BUILD
  COMMAND gen-brackets-tab 2 unidata/BidiBrackets.txt unidata/UnicodeData.txt > brackets.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)
add_custom_command(TARGET gen-brackets-type-tab POST_BUILD
  COMMAND gen-brackets-type-tab 2 unidata/BidiBrackets.txt > brackets-type.tab.i
  WORKING_DIRECTORY "${SRC_GEN_DIR}"
)

add_custom_target(gen_tab
  DEPENDS gen-unicode-version gen-bidi-type-tab gen-joining-type-tab gen-arabic-shaping-tab gen-mirroring-tab
    gen-brackets-tab
    gen-brackets-type-tab
)

include_directories(
    ${SRC_DIR}/lib
    ${SRC_GEN_DIR}
    ${PROJECT_BINARY_DIR}
    )