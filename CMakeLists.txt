cmake_minimum_required(VERSION 3.16)

# -------------------------------- USER OPTIONS --------------------------------
option(USE_LINUXBREW OFF "")
option(USE_PKGCFG ON "")
option(USE_VCPKG OFF "")

if(USE_VCPKG)
    if(WIN32) # TODO: shadow WSL
        set(VCPKG_TARGET_TRIPLET "x64-windows" CACHE STRING "" FORCE)
    elseif(APPLE)
        set(VCPKG_TARGET_TRIPLET "x64-osx-dynamic" CACHE STRING "" FORCE)
    else()
        set(VCPKG_TARGET_TRIPLET "x64-linux" CACHE STRING "" FORCE)
    endif()
    set(VCPKG_CRT_LINKAGE dynamic)
    set(VCPKG_LIBRARY_LINKAGE dynamic)

    set(CMAKE_TOOLCHAIN_FILE
            ${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake
            CACHE PATH "" FORCE)
    if(NOT EXISTS ${CMAKE_TOOLCHAIN_FILE})
        set(CMAKE_TOOLCHAIN_FILE
                ${VCPKG_ROOT}/libexec/scripts/buildsystems/vcpkg.cmake
                CACHE PATH "" FORCE)
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
    set(CLANG TRUE)
elseif(${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang")
    set(APPLECLANG TRUE)
endif()

# ------------------------------ GENERAL SETTINGS ------------------------------
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

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
if(CLANG OR APPLECLANG)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/ClangC++20Modules.cmake)
elseif(MSVC)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/MSVCC++20Modules.cmake)
endif()

## avoid using default XCode C++ SDK (which corresponds to `AppleClang`)
if(APPLE AND CLANG)
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

set(THIRD_PARTY_DIR ${PROJECT_SOURCE_DIR}/external)
if(WINDOWS)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/win32)
elseif(MACOS)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/macos)
elseif(LINUX)
    set(THIRD_PARTY_LIB_DIR ${THIRD_PARTY_DIR}/linux)
endif()

# ---------------------------- HEADERS AND LIBRARIES ---------------------------
## POSIX prefix
if(NOT MSVC)
    include_directories(/usr/local/include)
    link_directories(/usr/local/lib)
endif()

## LinuxBrew prefix
if(USE_LINUXBREW)
    set(LINUXBREW_HOME /home/linuxbrew/.linuxbrew
            CACHE PATH "Linuxbrew's home path" FORCE)
    include_directories(${LINUXBREW_HOME}/include)
    link_directories(${LINUXBREW_HOME}/lib)
endif()

# -------------------------------- CMAKE MODULES -------------------------------
set(CMAKE_MODULE_PATH
        ${CMAKE_CURRENT_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})
if(USE_LINUXBREW)
    set(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} ${LINUXBREW_HOME})
endif()
set(CMAKE_PREFIX_PATH ${THIRD_PARTY_LIB_DIR} ${CMAKE_PREFIX_PATH})

find_package(fmt REQUIRED)
#find_package(Add MODULE REQUIRED)

# ----------------------------- PKG-CONFIG MODULES -----------------------------
if(USE_PKGCFG)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        if(USE_LINUXBREW)
            set(ENV{PKG_CONFIG_PATH}
                    ${LINUXBREW_HOME}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH})
        endif()
        set(ENV{PKG_CONFIG_PATH}
                ${THIRD_PARTY_LIB_DIR}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH})

        #pkg_search_module(OpenCV REQUIRED QUIET opencv4)
    endif()
endif()

# ----------------------------------- TARGETS ----------------------------------
## TARGET1: main.cpp
add_executable(tester main.cpp)

# link modules
set(MODULE_SRCS_HELLO
#        test/modules/hello/src/hello.mpp)
        test/modules/impl_unit/src/hello.mpp
        test/modules/impl_unit/src/hello_impl.cpp)
set(MODULE_SRCS_FOO
        test/modules/dependence2/src/zoo.mpp
        test/modules/dependence2/src/cat.mpp
        test/modules/dependence2/src/bar.mpp
        test/modules/dependence2/src/foo.mpp)
set(MODULE_SRCS_MATH
        test/modules/partitions/src/math.math1.mpp
        test/modules/partitions/src/math.math2.mpp
        test/modules/partitions/src/math.mpp)
set(MODULE_SRCS_MATH_FRAGMENTS
        test/modules/partitions/src/math.math1.mpp
        test/modules/partitions/src/math.math2.mpp)

if(GNUC)
    get_target_property(all_srcs tester SOURCES)
    list(PREPEND all_srcs
            ${MODULE_SRCS_HELLO} ${MODULE_SRCS_FOO} ${MODULE_SRCS_MATH})
    set_target_properties(tester PROPERTIES SOURCES "${all_srcs}")
    target_compile_options(tester PRIVATE -fmodules-ts -x c++)
elseif(MSVC OR CLANG OR APPLECLANG)
    add_module(hello ${MODULE_SRCS_HELLO})
    add_module(foo ${MODULE_SRCS_FOO})
#    add_module(math ${MODULE_SRCS_MATH}
#            FRAGMENTS ${MODULE_SRCS_MATH_FRAGMENTS})
    target_link_module(tester hello foo)
endif()

# link libraries
target_compile_options(tester PRIVATE ${PKG_CFLAGS})
target_link_libraries(tester PRIVATE ${PKG_LDFLAGS})
target_include_directories(tester PRIVATE ${EIGEN3_INCLUDE_DIR})
target_link_libraries(tester PRIVATE fmt::fmt-header-only)
if (Add_FOUND)
    target_include_directories(tester PRIVATE ${Add_INCLUDE_DIRS})
    target_link_libraries(tester PRIVATE ${Add_LIBRARIES})
    target_compile_definitions(tester PRIVATE -DUSE_ADD)
endif()

## TARGET2: main.c
add_executable(ctester main.c)

# -------------------------------- SUBDIRECTORY --------------------------------
add_subdirectory(examples)
