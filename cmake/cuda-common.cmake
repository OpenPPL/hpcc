if(__hpcc_cuda_common_INCLUDED__)
    return()
else()
    set(__hpcc_cuda_common_INCLUDED__ TRUE)
endif()

if(NOT DEFINED CMAKE_CUDA_STANDARD)
    set(CMAKE_CUDA_STANDARD 11)
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)
endif()

# NOTE: cross compiling requires env `CUDA_TOOLKIT_ROOT`
if(CUDA_TOOLKIT_ROOT_DIR AND NOT DEFINED ENV{CUDA_TOOLKIT_ROOT})
    set(ENV{CUDA_TOOLKIT_ROOT} ${CUDA_TOOLKIT_ROOT_DIR})
elseif(DEFINED ENV{CUDA_TOOLKIT_ROOT} AND NOT CUDA_TOOLKIT_ROOT_DIR)
    set(CUDA_TOOLKIT_ROOT_DIR $ENV{CUDA_TOOLKIT_ROOT})
endif()

# NOTE: find_package should be placed after env settings for cross compiling
set(CUDA_PROPAGATE_HOST_FLAGS OFF)
find_package(CUDA REQUIRED) # required by CUDA_TOOLKIT_ROOT_DIR for cmake < 3.18

# NOTE: `CMAKE_CUDA_COMPILER` and `CMAKE_CUDA_HOST_COMPILER` MUST be placed before enable_language(CUDA)
# in order to recognize arch and os
if(MSVC)
    if(NOT CMAKE_CUDA_COMPILER)
        set(CMAKE_CUDA_COMPILER ${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc.exe)
    endif()
    set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    enable_language(CUDA)

    if(HAVE_CXX_FLAG_UTF_8)
        set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=/utf-8")
    endif()
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=/wd4819,/wd4828")
else()
    if(NOT CMAKE_CUDA_COMPILER)
        set(CMAKE_CUDA_COMPILER ${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc)
    endif()
    set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    enable_language(CUDA)

    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=-fPIC,-Wall,-fvisibility=hidden")
endif()

if(CUDA_VERSION VERSION_GREATER_EQUAL "10.2")
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -forward-unknown-to-host-compiler")
endif()

macro(hpcc_cuda_use_msvc_static_runtime)
    string(REPLACE -MD -MT CMAKE_CUDA_FLAGS_DEBUG "${CMAKE_CUDA_FLAGS_DEBUG}")
    string(REPLACE -MD -MT CMAKE_CUDA_FLAGS_RELEASE "${CMAKE_CUDA_FLAGS_RELEASE}")
endmacro()
