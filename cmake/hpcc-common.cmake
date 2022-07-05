cmake_minimum_required(VERSION 3.14)

if(__hpcc_common_INCLUDED__)
    return()
else()
    set(__hpcc_common_INCLUDED__ TRUE)
endif()

if(NOT HPCC_DEPS_DIR)
    set(HPCC_DEPS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps)
endif()

set(CMAKE_OBJECT_PATH_MAX 4096)

enable_language(C CXX ASM)

set(CMAKE_POSITION_INDEPENDENT_CODE ON) # enable PIC

macro(hpcc_append_cxx_compiler_flags flags)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flags}")
endmacro()

macro(hpcc_append_compiler_flags flags)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${flags}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flags}")
endmacro()

if(MSVC)
    hpcc_append_compiler_flags("/MP /openmp")
    hpcc_append_compiler_flags("/wd4244 /wd4251 /wd4267 /wd4305 /wd4503 /wd4819 /wd4800 /wd4996 /wd4828")

    set(SSE_ENABLED_FLAGS "")
    set(FMA_ENABLED_FLAGS "/arch:AVX2")
    set(AVX_ENABLED_FLAGS "/arch:AVX")
    set(AVX512_ENABLED_FLAGS "/arch:AVX512")
else()
    hpcc_append_compiler_flags("-fvisibility=hidden")
    hpcc_append_compiler_flags("-Wall -Wno-array-bounds -Werror=return-type")

    hpcc_append_compiler_flags("-ffunction-sections -fdata-sections -fno-common -fno-strict-aliasing")
    add_link_options("-Wl,--gc-sections")

    hpcc_append_cxx_compiler_flags("-ftemplate-depth=2014")

    # forces to define a virtual destructor in a class when having virtual functions, though it is not necessary for all cases
    hpcc_append_cxx_compiler_flags("-Werror=non-virtual-dtor")

    set(FMA_ENABLED_FLAGS "-mfma -mavx2")
    set(AVX_ENABLED_FLAGS "-mavx")
    set(SSE_ENABLED_FLAGS "-msse -msse2 -msse3 -msse4.1")
    set(AVX512_ENABLED_FLAGS "-mavx512f")
endif()

# --------------------------------------------------------------------------- #

macro(hpcc_declare_git_dep dep_name git_url git_commit)
    FetchContent_Declare(${dep_name}
        GIT_REPOSITORY ${git_url}
        GIT_TAG ${git_commit} # only branch or tag can be used if shallow is enabled
        #GIT_SHALLOW TRUE
        SOURCE_DIR ${HPCC_DEPS_DIR}/${dep_name}
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${dep_name}-build
        SUBBUILD_DIR ${HPCC_DEPS_DIR}/${dep_name}-subbuild)
endmacro()

macro(hpcc_declare_pkg_dep dep_name pkg_url)
    FetchContent_Declare(${dep_name}
        URL ${pkg_url}
        #URL_HASH MD5=${pkg_md5}
        SOURCE_DIR ${HPCC_DEPS_DIR}/${dep_name}
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${dep_name}-build
        SUBBUILD_DIR ${HPCC_DEPS_DIR}/${dep_name}-subbuild)
endmacro()

macro(hpcc_populate_dep dep_name)
    FetchContent_MakeAvailable(${dep_name})
endmacro()

# --------------------------------------------------------------------------- #

# msvc utils

macro(hpcc_use_msvc_dynamic_runtime)
    # for cmake version >= 3.15
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endmacro()

macro(hpcc_use_msvc_static_runtime)
    # for cmake version < 3.15
    foreach(lang C CXX)
        string(REPLACE /MD /MT CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
        string(REPLACE /MD /MT CMAKE_${lang}_FLAGS_RELEASE "${CMAKE_${lang}_FLAGS_RELEASE}")
    endforeach()
    # for cmake version >= 3.15
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endmacro()

# --------------------------------------------------------------------------- #

# git utils

find_package(Git QUIET)
if(GIT_FOUND)
    # usage: hpcc_get_git_info(GIT_HASH_OUTPUT hash_value GIT_TAG_OUTPUT tag_value)
    #        if current commit has a tag, `tag_value` is the tag string, otherwise `tag_value` is empty.
    function(hpcc_get_git_info)
        set(prefix "hpcc")
        set(flags)
        set(single_values GIT_HASH_OUTPUT GIT_TAG_OUTPUT)
        set(multi_values)
        cmake_parse_arguments(${prefix} "${flags}" "${single_values}" "${multi_values}" ${ARGN})

        execute_process(
            COMMAND ${GIT_EXECUTABLE} diff-index --name-only HEAD --
            OUTPUT_VARIABLE git_repo_is_dirty
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)

        # get git hash string
        execute_process(
            COMMAND ${GIT_EXECUTABLE} log -1 --pretty=format:%H
            OUTPUT_VARIABLE git_hash_string
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)

        # get git tag string
        execute_process(
            COMMAND ${GIT_EXECUTABLE} tag --points-at ${git_hash_string}
            OUTPUT_VARIABLE git_tag_string
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)

        if(git_repo_is_dirty)
            if(git_hash_string)
                set(${hpcc_GIT_HASH_OUTPUT} "${git_hash_string}-dirty" PARENT_SCOPE)
                if(git_tag_string)
                    set(${hpcc_GIT_TAG_OUTPUT} "${git_tag_string}-dirty" PARENT_SCOPE)
                endif()
            endif()
        else()
            set(${hpcc_GIT_HASH_OUTPUT} "${git_hash_string}" PARENT_SCOPE)
            set(${hpcc_GIT_TAG_OUTPUT} "${git_tag_string}" PARENT_SCOPE)
        endif()
    endfunction()
else()
    function(hpcc_get_git_info)
        set(prefix "hpcc")
        set(flags)
        set(single_values GIT_HASH_OUTPUT GIT_TAG_OUTPUT)
        set(multi_values)
        cmake_parse_arguments(${prefix} "${flags}" "${single_values}" "${multi_values}" ${ARGN})

        set(${hpcc_GIT_HASH_OUTPUT} "" PARENT_SCOPE)
        set(${hpcc_GIT_TAG_OUTPUT} "" PARENT_SCOPE)
    endfunction()
endif()
