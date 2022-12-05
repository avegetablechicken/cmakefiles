cmake_minimum_required(VERSION 3.16)

# -------------------------------- USER OPTIONS --------------------------------
option(USE_PKGCFG ON "")
option(USE_HOMEBREW OFF "")
option(USE_VCPKG OFF "")
option(CLANG_USE_MINGW OFF "")

set(HOMEBREW_PREFIX "$ENV{HOMEBREW_PREFIX}" CACHE PATH "Homebrew prefix")
set(VCPKG_ROOT "$ENV{VCPKG_ROOT}" CACHE PATH "vcpkg root")
set(VCPKG_TARGET_TRIPLET "$ENV{VCPKG_DEFAULT_TRIPLET}"
        CACHE STRING "vcpkg target triplet")
set(MINGW_BINDIR "" CACHE PATH "MinGW's bindir")

if(USE_VCPKG)
    if(NOT VCPKG_TARGET_TRIPLET)
        if(WIN32)
            execute_process(
                    COMMAND cmd /c "echo %PROCESSOR_ARCHITECTURE%"
                    OUTPUT_VARIABLE _PROCESSOR_ARCHITECTURE
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
        else()
            execute_process(
                    COMMAND uname -m
                    OUTPUT_VARIABLE _PROCESSOR_ARCHITECTURE
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
        endif()
        STRING(TOLOWER ${_PROCESSOR_ARCHITECTURE} _PROCESSOR_ARCHITECTURE)

        if(x86_64 MATCHES ${_PROCESSOR_ARCHITECTURE}
                OR x64 MATCHES ${_PROCESSOR_ARCHITECTURE}
                OR amd64 MATCHES ${_PROCESSOR_ARCHITECTURE})
            set(_VCPKG_TARGET_ARCH x64)
        elseif(i386 MATCHES ${_PROCESSOR_ARCHITECTURE}
                OR i686 MATCHES ${_PROCESSOR_ARCHITECTURE}
                OR x86 MATCHES ${_PROCESSOR_ARCHITECTURE})
            set(_VCPKG_TARGET_ARCH x86)
        elseif(arm64 MATCHES ${_PROCESSOR_ARCHITECTURE})
            set(_VCPKG_TARGET_ARCH arm64)
        elseif(arm MATCHES ${_PROCESSOR_ARCHITECTURE})
            set(_VCPKG_TARGET_ARCH arm)
        else()
            message(FATAL_ERROR "Unknown architecture: ${_PROCESSOR_ARCHITECTURE}")
        endif()
        unset(_PROCESSOR_ARCHITECTURE)

        if(WIN32)
            set(VCPKG_TARGET_TRIPLET "${_VCPKG_TARGET_ARCH}-windows" CACHE STRING "")
        elseif(APPLE)
            set(VCPKG_TARGET_TRIPLET "${_VCPKG_TARGET_ARCH}-osx-dynamic" CACHE STRING "")
        else()
            set(VCPKG_TARGET_TRIPLET "x${_VCPKG_TARGET_ARCH}-linux-dynamic" CACHE STRING "")
        endif()
        unset(_VCPKG_TARGET_ARCH)
    endif()

    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
        if(NOT VCPKG_ROOT)
            find_program(_VCPKG_PROGRAM vcpkg)
            if(_VCPKG_PROGRAM)
                get_filename_component(VCPKG_ROOT ${_VCPKG_PROGRAM} DIRECTORY)
            else()
                message(STATUS "vcpkg not found. vcpkg disabled.")
            endif()
            unset(_VCPKG_PROGRAM)
        endif()

        if(VCPKG_ROOT)
            set(_VCPKG_TOOLCHAIN_FILE
                    ${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)
            if(EXISTS ${_VCPKG_TOOLCHAIN_FILE})
                set(CMAKE_TOOLCHAIN_FILE ${_VCPKG_TOOLCHAIN_FILE})
            else()
                set(_VCPKG_TOOLCHAIN_FILE
                        ${VCPKG_ROOT}/libexec/scripts/buildsystems/vcpkg.cmake)
                if(EXISTS ${_VCPKG_TOOLCHAIN_FILE})
                    set(CMAKE_TOOLCHAIN_FILE ${_VCPKG_TOOLCHAIN_FILE})
                else()
                    message(STATUS "VCPKG_ROOT is invalid. vcpkg disabled.")
                endif()
            endif()
            unset(_VCPKG_TOOLCHAIN_FILE)
        endif()
    endif()
endif()

## HomeBrew prefix
if(USE_HOMEBREW AND NOT HOMEBREW_PREFIX)
    find_program(_HOMEBREW_PROGRAM brew
            PATHS /usr/local/bin /opt/local/bin
            PATHS /home/linuxbrew/.linuxbrew/bin $ENV{HOME}/.linuxbrew/bin)
    if(_HOMEBREW_PROGRAM)
        get_filename_component(_HOMEBREW_PROGRAM_PARENT ${_HOMEBREW_PROGRAM} DIRECTORY)
        get_filename_component(HOMEBREW_PREFIX ${_HOMEBREW_PROGRAM_PARENT} DIRECTORY)
        unset(_HOMEBREW_PROGRAM_PARENT)
    endif()
    unset(_HOMEBREW_PROGRAM)
endif()

## Clang with MinGW toolchain
if(WIN32 AND CLANG_USE_MINGW)
    set(CMAKE_C_COMPILER_TARGET x86_64-pc-mingw32)
    set(CMAKE_CXX_COMPILER_TARGET x86_64-pc-mingw32)
#    if(MINGW_BINDIR)
#        set(ENV{Path} "${MINGW_BINDIR};$ENV{Path}")
#    endif()
endif()

# ---------------------------------- PROJECT -----------------------------------
project(tester)

# ---------------------------- PLATFORM AND COMPILER ---------------------------
if(${CMAKE_SYSTEM_NAME} STREQUAL "Windows")
    set(WINDOWS TRUE)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
    set(MACOS TRUE)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(LINUX TRUE)
endif()

if(${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
    set(GNUC TRUE)
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
    if(MSVC)
        set(CLANG_CL TRUE)
    else()
        set(CLANG TRUE)
    endif()
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang")
    set(APPLECLANG TRUE)
endif()

# ------------------------------ GENERAL SETTINGS ------------------------------
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

if(MSVC)
    add_compile_definitions(/W4)
else()
    add_compile_options(-Wall -Wextra -Wpedantic -Wsign-conversion)
endif()

## enable latest c++ standard
string(REGEX MATCHALL "cxx_std_[0-9][0-9]"
        SUPPORTED_CXX_STANDARDS ${CMAKE_CXX_COMPILE_FEATURES})
list(GET SUPPORTED_CXX_STANDARDS -1 CXX_STANDARD_LATEST)
string(SUBSTRING ${CXX_STANDARD_LATEST} 8 2 CXX_STANDARD_LATEST_ID)
set(CMAKE_CXX_STANDARD ${CXX_STANDARD_LATEST_ID})

## enable latest c standard
string(REGEX MATCHALL "c_std_[0-9][0-9]"
        SUPPORTED_C_STANDARDS ${CMAKE_C_COMPILE_FEATURES})
list(GET SUPPORTED_C_STANDARDS -1 C_STANDARD_LATEST)
string(SUBSTRING ${C_STANDARD_LATEST} 6 2 C_STANDARD_LATEST_ID)
set(CMAKE_C_STANDARD ${C_STANDARD_LATEST_ID})

## enable compiler's support for c++ modules
if(GNUC)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/GccC++20Modules.cmake)
elseif(MSVC) # include clang-cl
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/MSVCC++20Modules.cmake)
elseif(CLANG OR APPLECLANG)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/ClangC++20Modules.cmake)
endif()
check_cxx_compiler_modules(COMPILER_SUPPORTS_MODULES)

## avoid using built-in sdk of Apple (which corresponds to AppleClang)
if(MACOS AND CLANG)
    get_filename_component(LLVM_BINDIR ${CMAKE_CXX_COMPILER} DIRECTORY)
    get_filename_component(LLVM_HOME ${LLVM_BINDIR} DIRECTORY)
    set(STDLIB_LDFLAGS "-L${LLVM_HOME}/lib")
    set(CMAKE_EXE_LINKER_FLAGS
            ${STDLIB_LDFLAGS} ${CMAKE_EXE_LINKER_FLAGS})
    set(CMAKE_MODULE_LINKER_FLAGS
            ${STDLIB_LDFLAGS} ${CMAKE_MODULE_LINKER_FLAGS})
    set(CMAKE_SHARED_LINKER_FLAGS
            ${STDLIB_LDFLAGS} ${CMAKE_SHARED_LINKER_FLAGS})
endif()

if(CLANG_CL)
    add_compile_options(/EHsc)
endif()

set(THIRD_PARTY_DIR ${PROJECT_SOURCE_DIR}/external)
if(MINGW)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/mingw)
elseif(WINDOWS)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/win32)
elseif(MACOS)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/macos)
elseif(LINUX)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/linux)
endif()

# -------------------------------- CMAKE MODULES -------------------------------
set(CMAKE_MODULE_PATH
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})
if(USE_HOMEBREW)
    set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${HOMEBREW_PREFIX})
endif()
set(CMAKE_PREFIX_PATH ${THIRD_PARTY_LIB_DIR} ${CMAKE_PREFIX_PATH})

# ----------------------------- PKG-CONFIG MODULES -----------------------------
if(USE_PKGCFG)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        if(USE_HOMEBREW)
            set(ENV{PKG_CONFIG_PATH}
                    ${HOMEBREW_PREFIX}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH})
        endif()
        set(ENV{PKG_CONFIG_PATH}
                ${THIRD_PARTY_LIB_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH})
    endif()
endif()

# --------------------------------- LIBRARIES ----------------------------------
## search by cmake
find_package(fmt REQUIRED)
#find_package(Add MODULE REQUIRED)

## search by pkg-config
#pkg_search_module(OpenCV REQUIRED QUIET opencv4)

## add c++ modules
if(${COMPILER_SUPPORTS_MODULES})
    set(MODULE_SRCS_HELLO external/src/modules/impl_unit/src/hello.mpp
            external/src/modules/impl_unit/src/hello_impl.cpp)
    set(MODULE_SRCS_FOO
            external/src/modules/dependence2/src/zoo.mpp
            external/src/modules/dependence2/src/cat.mpp
            external/src/modules/dependence2/src/bar.mpp
            external/src/modules/dependence2/src/foo.mpp)
    set(MODULE_SUBMODULES_SRCS_MATH
            external/src/modules/submodules/src/math.math1.mpp
            external/src/modules/submodules/src/math.math2.mpp
            external/src/modules/submodules/src/math.mpp)
    set(MODULE_FRAGMENTS_SRCS_MATH
            external/src/modules/partitions/src/math.math1.mpp
            external/src/modules/partitions/src/math.math2.mpp
            external/src/modules/partitions/src/math.mpp)
    set(MODULE_FRAGMENTS_SRCS_MATH_FRAGMENTS
            external/src/modules/partitions/src/math.math1.mpp
            external/src/modules/partitions/src/math.math2.mpp)

    add_module(hello ${MODULE_SRCS_HELLO})
    add_module(foo ${MODULE_SRCS_FOO})
    if(GNUC OR CLANG OR APPLECLANG)
        add_module(math ${MODULE_SUBMODULES_SRCS_MATH})
    elseif(MSVC)
        add_module(math ${MODULE_FRAGMENTS_SRCS_MATH}
                FRAGMENTS ${MODULE_FRAGMENTS_SRCS_MATH_FRAGMENTS})
    endif()
endif()

# ----------------------------------- TARGETS ----------------------------------
## TARGET1: main.cpp
add_executable(tester main.cpp)

# link c++ modules
if(${COMPILER_SUPPORTS_MODULES})
    target_link_module(tester hello foo math)
endif()

# link libraries
target_compile_options(tester PRIVATE ${PKG_CFLAGS})
target_link_libraries(tester PRIVATE ${PKG_LDFLAGS})
target_include_directories(tester PRIVATE ${EIGEN3_INCLUDE_DIR})
target_link_libraries(tester PRIVATE fmt::fmt)
if (Add_FOUND)
    target_include_directories(tester PRIVATE ${Add_INCLUDE_DIRS})
    target_link_libraries(tester PRIVATE ${Add_LIBRARIES})
    target_compile_definitions(tester PRIVATE -DUSE_ADD)
endif()

## TARGET2: main.c
add_executable(ctester main.c)

# -------------------------------- SUBDIRECTORY --------------------------------
add_subdirectory(examples)
