cmake_minimum_required(VERSION 3.5.0)
project(md4c)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

add_library(md4c SHARED
    napi_init.cpp
    md4c.c
    md4c-html.c
    entity.c
)

target_link_libraries(md4c PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)

set_target_properties(md4c PROPERTIES
    CMAKE_CXX_STANDARD 17
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
