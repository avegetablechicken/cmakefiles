include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-fmodules-ts" COMPILER_TEST_MODULES_TS)
if(COMPILER_TEST_MODULES_TS)
    set(MODULE_FLAG "-fmodules-ts")
else()
    check_cxx_compiler_flag("-fmodules" COMPILER_TEST_MODULES)
    if(COMPILER_TEST_MODULES)
        set(MODULE_FLAG "-fmodules")
    else()
        message(FATAL_ERROR "Modules are not yet support by current version")
    endif()
endif()

set(PREBUILT_MODULE_PATH ${CMAKE_BINARY_DIR}/pcm.cache)
if(NOT DEFINED MODULE_INTERFACE_EXTENSION)
    set(MODULE_INTERFACE_EXTENSION ".mpp" ".cppm" ".mxx" ".ixx")
endif()

function(check_accepted_module_interface var src)
    get_filename_component(ext ${src} LAST_EXT)
    if(${ext} IN_LIST MODULE_INTERFACE_EXTENSION)
        set(${var} TRUE PARENT_SCOPE)
    else()
        set(${var} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(add_module name)
    set(ISYSROOT "")
    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang")
        set(ISYSROOT
                -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)
    endif()

    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang"
            AND ${CMAKE_CXX_COMPILER_VERSION} VERSION_GREATER_EQUAL 13
            AND ${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 14)
        # c++2b doesn't support `-fprebuilt-module-path` in clang-13
        set(CXX_STANDARD_OPTION c++2a)
    else()
        if(cxx_std_23 IN_LIST CMAKE_CXX_COMPILE_FEATURES)
            set(CXX_STANDARD_OPTION c++2b)
        else()
            set(CXX_STANDARD_OPTION c++2a)
        endif()
    endif()

    set(SRCS "")
    foreach(src ${ARGN})
        if(${src} STREQUAL "FRAGMENTS")
            message(FATAL_ERROR "Module partitions are not yet supported by Clang")
        endif()

        cmake_path(ABSOLUTE_PATH src)
        list(APPEND SRCS ${src})
    endforeach()

    set(MODULE_OBJECT_OUTPUT_DIR ${CMAKE_BINARY_DIR}/CMakeFiles/${name}.dir)
    set(MODULE_PCM_FILES "")
    set(MODULE_OBJ_FILES "")

    foreach(src ${SRCS})
        get_filename_component(SRC_STEM ${src} NAME_WLE)
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})

        if(IS_MODULE_INTERFACE)
            set(CUR_MODULE_PRECOMPILE ${PREBUILT_MODULE_PATH}/${SRC_STEM}.pcm)
            add_custom_command(
                    OUTPUT ${CUR_MODULE_PRECOMPILE}
                    DEPENDS ${src} ${MODULE_PCM_FILES}
                    COMMAND
                    test -d ${PREBUILT_MODULE_PATH}
                    || mkdir -p ${PREBUILT_MODULE_PATH}
                    COMMAND
                    ${CMAKE_CXX_COMPILER}
                    ${ISYSROOT}
                    ${MODULE_FLAG}
                    #-fimplicit-modules
                    #-fimplicit-module-maps
                    #-fmodules-cache-path=${PREBUILT_MODULE_PATH}
                    -fprebuilt-module-path=${PREBUILT_MODULE_PATH}
                    --precompile
                    -x c++-module
                    -std=${CXX_STANDARD_OPTION}
                    -c -o ${CUR_MODULE_PRECOMPILE}
                    ${src})
            list(APPEND MODULE_PCM_FILES ${CUR_MODULE_PRECOMPILE})
        endif()
    endforeach()

    set(MODULE_FILE_FLAGS "")
    foreach(pcm_file ${MODULE_PCM_FILES})
        list(APPEND MODULE_FILE_FLAGS "-fmodule-file=${pcm_file}")
    endforeach()

    foreach(src ${SRCS})
        get_filename_component(SRC_STEM ${src} NAME_WLE)
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})
        if(IS_MODULE_INTERFACE)
            set(INPUT_FILE ${PREBUILT_MODULE_PATH}/${SRC_STEM}.pcm)
        else()
            set(INPUT_FILE ${src})
        endif()

        get_filename_component(SRC_FILENAME ${src} NAME)
        set(CUR_MODULE_OBJECT ${MODULE_OBJECT_OUTPUT_DIR}/${SRC_FILENAME}.o)
        add_custom_command(
                OUTPUT ${CUR_MODULE_OBJECT}
                DEPENDS ${INPUT_FILE} ${MODULE_PCM_FILES}
                COMMAND
                test -d ${MODULE_OBJECT_OUTPUT_DIR}
                || mkdir -p ${MODULE_OBJECT_OUTPUT_DIR}
                COMMAND
                ${CMAKE_CXX_COMPILER}
                ${ISYSROOT}
                ${MODULE_FLAG}
                #-fimplicit-modules
                #-fimplicit-module-maps
                #-fmodules-cache-path=${PREBUILT_MODULE_PATH}
                ${MODULE_FILE_FLAGS}
                -fprebuilt-module-path=${PREBUILT_MODULE_PATH}
                -std=${CXX_STANDARD_OPTION}
                -c -o ${CUR_MODULE_OBJECT}
                ${INPUT_FILE}
                )
        list(APPEND MODULE_OBJ_FILES ${CUR_MODULE_OBJECT})

    endforeach()

    #add_library(${name} ${MODULE_OBJ_FILES})
    #set_target_properties(${name} PROPERTIES
    #        LINKER_LANGUAGE CXX)

    add_custom_target(${name}
            DEPENDS ${MODULE_OBJ_FILES})
    set_target_properties(${name} PROPERTIES
            OBJECTS "${MODULE_OBJ_FILES}")
endfunction()

function(target_link_module target)
    set_target_properties(${target} PROPERTIES
            CXX_EXTENSIONS OFF)
    get_target_property(cxx_standard ${target} CXX_STANDARD)
    if(${cxx_standard} GREATER 20)
        if(${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang"
                AND ${CMAKE_CXX_COMPILER_VERSION} VERSION_GREATER_EQUAL 13
                AND ${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 14)
            set_target_properties(${target} PROPERTIES
                    CXX_STANDARD 20) # disable c++2b in clang-13
        endif()
    endif()

    target_compile_options(${target} PRIVATE
            ${MODULE_FLAG}
            -fprebuilt-module-path=${PREBUILT_MODULE_PATH})

    foreach(name ${ARGN})
        add_dependencies(${target} ${name})
        #target_link_libraries(${target} PUBLIC ${name})
        get_target_property(objects ${name} OBJECTS)
        target_link_libraries(${target} PUBLIC ${objects})
    endforeach()
endfunction()