# the name of the target operating system
set(CMAKE_SYSTEM_NAME Windows)

set(_PATH_PREFIX x86_64-w64-mingw32)
set(CMAKE_C_COMPILER ${_PATH_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${_PATH_PREFIX}-g++)
set(CMAKE_ADDR2LINE ${_PATH_PREFIX}-addr2line)
set(CMAKE_AR ${_PATH_PREFIX}-ar)
set(CMAKE_RANLIB ${_PATH_PREFIX}-ranlib)
set(CMAKE_CXX_COMPILER_AR ${_PATH_PREFIX}-ar)
set(CMAKE_CXX_COMPILER_RANLIB ${_PATH_PREFIX}-ranlib)
set(CMAKE_C_COMPILER_AR ${_PATH_PREFIX}-ar)
set(CMAKE_C_COMPILER_RANLIB ${_PATH_PREFIX}-ranlib)
set(CMAKE_Fortran_COMPILER ${_PATH_PREFIX}-gfortan)
set(CMAKE_OBJCOPY ${_PATH_PREFIX}-objcopy)
set(CMAKE_OBJDUMP ${_PATH_PREFIX}-objdump)
set(CMAKE_RC_COMPILER ${_PATH_PREFIX}-windres)
set(CMAKE_READELF ${_PATH_PREFIX}-readelf)
set(CMAKE_STRIP ${_PATH_PREFIX}-strip)
set(CMAKE_LINKER ${_PATH_PREFIX}-ld)
unset(_PATH_PREFIX)

# adjust the default behaviour of the FIND_XXX() commands:
# search headers and libraries in the target environment, search
# programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)