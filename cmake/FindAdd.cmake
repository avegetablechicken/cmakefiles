set(INSTALL_PREFIX /Users/xuyiwen/CLionProjects/tester/external/macos)
set(INCLUDE_INSTALL_DIR ${INSTALL_PREFIX}/include)
set(LIB_INSTALL_DIR ${INSTALL_PREFIX}/lib)

find_path(Add_INCLUDE_DIRS add.h ${INCLUDE_INSTALL_DIR} NO_DEFAULT_PATH)
find_library(Add_LIBRARIES add ${LIB_INSTALL_DIR} NO_DEFAULT_PATH)

unset(INSTALL_PREFIX)
unset(INCLUDE_INSTALL_DIR)
unset(LIB_INSTALL_DIR)

if (Add_INCLUDE_DIRS AND Add_LIBRARIES)
    set(Add_FOUND TRUE)
endif()

if (Add_FOUND)
    if (NOT Add_FIND_QUIETLY)
        message(STATUS "Found Add: ${Add_LIBRARIES}")
    endif()
else()
    if (Add_FIND_REQUIRED)
        message(FATAL_ERROR "Could not find library Add")
    endif()
endif()
