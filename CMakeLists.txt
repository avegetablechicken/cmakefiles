cmake_minimum_required(VERSION 3.16)

# -------------------------------- USER OPTIONS --------------------------------
option(USE_HOMEBREW OFF "")
option(USE_PKGCFG ON "")
option(USE_VCPKG OFF "")

if(WIN32)
    if(MSVC_CL_64)
        set(X86_64 TRUE)
    else()
        set(I386 TRUE)
    endif()
else()
    execute_process(
            COMMAND uname -m COMMAND tr -d '\n'
            OUTPUT_VARIABLE ARCH)
    if(x86_64 MATCHES ${ARCH} OR x64 MATCHES ${ARCH}
            OR amd64 MATCHES ${ARCH})
        set(X86_64 TRUE)
    elseif(i386 MATCHES ${ARCH} OR i686 MATCHES ${ARCH}
            OR x86 MATCHES ${ARCH})
        set(I386 TRUE)
    elseif(arm64 MATCHES ${ARCH})
        set(ARM64 TRUE)
    endif()
    unset(ARCH)
endif()

if(USE_VCPKG)
    if(X86_64)
        set(VCPKG_TARGET_ARCH x64)
    elseif(I386)
        set(VCPKG_TARGET_ARCH x86)
    elseif(ARM64)
        set(VCPKG_TARGET_ARCH arm64)
    endif()

    if(WIN32)
        set(VCPKG_TARGET_TRIPLET "${VCPKG_TARGET_ARCH}-windows" CACHE STRING "")
    elseif(APPLE)
        set(VCPKG_TARGET_TRIPLET "${VCPKG_TARGET_ARCH}-osx-dynamic" CACHE STRING "")
    else()
        set(VCPKG_TARGET_TRIPLET "x${VCPKG_TARGET_ARCH}-linux-dynamic" CACHE STRING "")
    endif()
    set(VCPKG_CRT_LINKAGE dynamic)
    set(VCPKG_LIBRARY_LINKAGE dynamic)

    if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
        set(CMAKE_TOOLCHAIN_FILE
                ${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake)
        if(NOT EXISTS ${CMAKE_TOOLCHAIN_FILE})
            set(CMAKE_TOOLCHAIN_FILE
                    ${VCPKG_ROOT}/libexec/scripts/buildsystems/vcpkg.cmake)
        endif()
    endif()
endif()

## HomeBrew prefix
if(USE_HOMEBREW)
    if(APPLE)
        if(X86_64)
            set(BREW_HOME /usr/local
                    CACHE PATH "HomeBrew's home path")
        else()
            set(BREW_HOME /opt/local
                    CACHE PATH "HomeBrew's home path")
        endif()
    else()
        set(BREW_HOME /home/linuxbrew/.linuxbrew
                CACHE PATH "LinuxBrew's home path")
    endif()
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
    set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${BREW_HOME})
endif()
set(CMAKE_PREFIX_PATH ${THIRD_PARTY_LIB_DIR} ${CMAKE_PREFIX_PATH})

# ----------------------------- PKG-CONFIG MODULES -----------------------------
if(USE_PKGCFG)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        if(USE_HOMEBREW)
            set(ENV{PKG_CONFIG_PATH}
                    ${BREW_HOME}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH})
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
