cmake_minimum_required(VERSION 3.14)

if(__hpcc_common_INCLUDED)
    return()
else()
    set(__hpcc_common_INCLUDED TRUE)
endif()

if(NOT HPCC_DEPS_DIR)
    set(HPCC_DEPS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/deps)
endif()

set(CMAKE_OBJECT_PATH_MAX 4096)

enable_language(C CXX ASM)

include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)
function(_mangle_flags lang FLAG OUTPUT)
    string(TOUPPER "HAVE_${lang}_FLAG_${FLAG}" SANITIZED_FLAG)
    string(REPLACE "+" "X" SANITIZED_FLAG ${SANITIZED_FLAG})
    string(REGEX REPLACE "[^A-Za-z_0-9]" "_" SANITIZED_FLAG ${SANITIZED_FLAG})
    string(REGEX REPLACE "_+" "_" SANITIZED_FLAG ${SANITIZED_FLAG})
    set(${OUTPUT} "${SANITIZED_FLAG}" PARENT_SCOPE)
endfunction()
function(append_compiler_flag lang FLAG)
    _mangle_flags(${lang} ${FLAG} MANGLED_FLAG)
    set(OLD_CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS}")
    set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} ${FLAG}")
    if (lang STREQUAL "CXX")
        check_cxx_compiler_flag("${FLAG}" ${MANGLED_FLAG})
    elseif(lang STREQUAL "C" OR lang STREQUAL "ASM")
        check_c_compiler_flag("${FLAG}" ${MANGLED_FLAG})
    else()
        message(FATAL_ERROR "Unknown language: ${lang}")
    endif()
    set(CMAKE_REQUIRED_FLAGS "${OLD_CMAKE_REQUIRED_FLAGS}")
    if(${MANGLED_FLAG})
        set(VARIANT ${ARGV2})
        if(ARGV2)
            string(TOUPPER "_${VARIANT}" VARIANT)
        endif()
        set(CMAKE_${lang}_FLAGS${VARIANT} "${CMAKE_${lang}_FLAGS${VARIANT}} ${FLAG}" PARENT_SCOPE)
    endif()
endfunction()
macro(append_cxx_compiler_flag FLAG)
    append_compiler_flag(CXX ${FLAG} ${ARGV1})
endmacro()
macro(append_asm_compiler_flag FLAG)
    append_compiler_flag(ASM ${FLAG} ${ARGV1})
endmacro()
macro(append_c_compiler_flag FLAG)
    append_compiler_flag(C ${FLAG} ${ARGV1})
endmacro()

# compiler features for VC++
# We use multi-thread static library, so use /MT instead of /MD
#/arch:AVX2 use Advanced Vector Extensions2
#/MP enable multi-processor compilation
#/Gm enable minimal rebuild
#/openmp enable openmp support
#/Oi enable intrinsic functions
#/Qpar enable parallel code generation
#/GF enable string pooling
#/Ot prefer speed to size
#The other optimization options are set by CMake Visual Studio Generator.
#Set compiler flags
if(MSVC)
    if(NOT HPCC_MSVC_MD)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
        foreach(lang C CXX)
            string(REPLACE /MD /MT CMAKE_${lang}_FLAGS_DEBUG "${CMAKE_${lang}_FLAGS_DEBUG}")
            string(REPLACE /MD /MT CMAKE_${lang}_FLAGS_RELEASE "${CMAKE_${lang}_FLAGS_RELEASE}")
        endforeach()
    else()
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()
    append_c_compiler_flag("/MP")
    append_c_compiler_flag("/openmp")
    append_cxx_compiler_flag("/MP")
    append_cxx_compiler_flag("/openmp")
    append_cxx_compiler_flag("/wd4819")
    append_cxx_compiler_flag("/wd4800")
    append_cxx_compiler_flag("/wd4996")
    append_cxx_compiler_flag("/wd4828")
    append_cxx_compiler_flag("/utf-8")
    set(SSE_ENABLED_FLAGS "")
    set(FMA_ENABLED_FLAGS "/arch:AVX2")
    set(AVX_ENABLED_FLAGS "/arch:AVX")
    set(AVX512_ENABLED_FLAGS "/arch:AVX512")
else()
    set(FMA_ENABLED_FLAGS "-mfma -mavx2")
    set(AVX_ENABLED_FLAGS "-mavx")
    set(SSE_ENABLED_FLAGS "-msse -msse2 -msse3 -msse4.1")
    set(AVX512_ENABLED_FLAGS "-mavx512f")
    foreach(lang C CXX ASM)
        append_compiler_flag(${lang} "-fPIC")
        append_compiler_flag(${lang} "-fvisibility=hidden")
        append_compiler_flag(${lang} "-Wall -Wno-array-bounds")
    endforeach()
    if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
        set(gnuc_options "-ffunction-sections -fdata-sections -fno-common")
        add_link_options("-Wl,--gc-sections")
        append_compiler_flag(C ${gnuc_options})
        append_compiler_flag(CXX ${gnuc_options})
    endif()
    append_cxx_compiler_flag("-ftemplate-depth=2014")
endif()

if(HPCC_USE_CUDA)
    find_package(CUDA REQUIRED)
    set(CUDA_PROPAGATE_HOST_FLAGS OFF)
    if(MSVC)
        set(CMAKE_CUDA_COMPILER ${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc.exe)
        enable_language(CUDA)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler=/wd4819,/wd4828")
        if(HAVE_CXX_FLAG_UTF_8)
            set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler=/utf-8")
        endif()
        set(CUDA_NVCC_FLAGS_DEBUG "-g -O0")
        set(CUDA_NVCC_FLAGS_RELEASE "-O3")
        #CMake with version greater than or equal to 3.15 use CMAKE_MSVC_RUNTIME_LIBRARY
        #This variable is set above
        if(NOT HPCC_MSVC_MD)
            string(REPLACE -MD -MT CMAKE_CUDA_FLAGS_DEBUG "${CMAKE_CUDA_FLAGS_DEBUG}")
            string(REPLACE -MD -MT CMAKE_CUDA_FLAGS_RELEASE "${CMAKE_CUDA_FLAGS_RELEASE}")
        endif()
    else()
        set(CMAKE_CUDA_COMPILER ${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc)
        # Explicitly set the cuda host compiler.
        # Because the default host compiler selected by cmake maybe wrong.
        set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
        enable_language(CUDA)
        set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler=-fPIC,-Wall,-fvisibility=hidden")
        set(CUDA_NVCC_FLAGS_DEBUG "-g")
        set(CUDA_NVCC_FLAGS_RELEASE "-O3")
    endif()
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} ${CUDA_NVCC_FLAGS}")
    set(CMAKE_CUDA_STANDARD 11)
endif()

# --------------------------------------------------------------------------- #

macro(hpcc_declare_git_dep dep_name git_url git_tag)
    FetchContent_Declare(${dep_name}
        GIT_REPOSITORY ${git_url}
        GIT_TAG ${git_tag}
        #GIT_SHALLOW TRUE
        SOURCE_DIR ${HPCC_DEPS_DIR}/${dep_name}
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${dep_name}-build
        SUBBUILD_DIR ${HPCC_DEPS_DIR}/${dep_name}-subbuild
        UPDATE_DISCONNECTED True)
endmacro()

macro(hpcc_declare_pkg_dep dep_name pkg_url pkg_md5)
    FetchContent_Declare(${dep_name}
        URL ${pkg_url}
        URL_HASH MD5=${pkg_md5}
        SOURCE_DIR ${HPCC_DEPS_DIR}/${dep_name}
        BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${dep_name}-build
        SUBBUILD_DIR ${HPCC_DEPS_DIR}/${dep_name}-subbuild
        UPDATE_DISCONNECTED True)
endmacro()

macro(hpcc_populate_dep dep_name)
    FetchContent_MakeAvailable(${dep_name})
endmacro()

# --------------------------------------------------------------------------- #

find_package(Git QUIET)
if(GIT_FOUND)
    # usage: hpcc_get_git_info(GIT_HASH_OUTPUT hash_value GIT_TAG_OUTPUT tag_value)
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
