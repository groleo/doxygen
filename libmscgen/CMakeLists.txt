include_directories(
    ${CMAKE_SOURCE_DIR}/liblodepng
    ${CMAKE_SOURCE_DIR}/libmscgen
    ${GENERATED_SRC}
)

add_library(mscgen
gd.c
gd_security.c
gdfontt.c
gdtables.c
gd_color.c
gdfonts.c
gdhelpers.c
gd_lodepng.c
mscgen_adraw.c
mscgen_gd_out.c
mscgen_ps_out.c
mscgen_null_out.c
${GENERATED_SRC}/mscgen_language.cpp
${GENERATED_SRC}/mscgen_lexer.cpp
mscgen_api.c
mscgen_msc.c
mscgen_safe.c
mscgen_svg_out.c
mscgen_usage.c
mscgen_utf8.c
)


FLEX_TARGET(mscgen_lexer
            mscgen_lexer.l
            ${GENERATED_SRC}/mscgen_lexer.cpp
            COMPILE_FLAGS "${LEX_FLAGS}")
BISON_TARGET(mscgen_language
             mscgen_language.y
             ${GENERATED_SRC}/mscgen_language.cpp
             COMPILE_FLAGS "${YACC_FLAGS}")
