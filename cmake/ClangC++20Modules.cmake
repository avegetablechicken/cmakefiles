function(check_cxx_compiler_modules RESULT)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("-fmodules-ts" COMPILER_TEST_MODULES_TS)
    if(${COMPILER_TEST_MODULES_TS})
        set(${RESULT} TRUE PARENT_SCOPE)
    else()
        check_cxx_compiler_flag("-fmodules" COMPILER_TEST_MODULES)
        if(${COMPILER_TEST_MODULES})
            set(${RESULT} TRUE PARENT_SCOPE)
        else()
            message(STATUS "Modules are not yet support by current version")
            set(${RESULT} FALSE PARENT_SCOPE)
        endif()
    endif()
endfunction()

function(get_module_compile_flag MODULE_FLAG)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("-fmodules-ts" COMPILER_TEST_MODULES_TS)
    if(${COMPILER_TEST_MODULES_TS})
        set(${MODULE_FLAG} "-fmodules-ts" PARENT_SCOPE)
    else()
        check_cxx_compiler_flag("-fmodules" COMPILER_TEST_MODULES)
        if(${COMPILER_TEST_MODULES})
            set(${MODULE_FLAG} "-fmodules" PARENT_SCOPE)
        else()
            message(FATAL_ERROR "Modules are not yet support by current version")
        endif()
    endif()
endfunction()

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
    if(NOT DEFINED CMAKE_CXX_STANDARD)
        string(REGEX MATCHALL "cxx_std_[0-9][0-9]"
                SUPPORTED_CXX_STANDARDS ${CMAKE_CXX_COMPILE_FEATURES})
        list(GET SUPPORTED_CXX_STANDARDS -1 CXX_STANDARD_LATEST)
        string(SUBSTRING ${CXX_STANDARD_LATEST} 8 2 CXX_STANDARD_LATEST_ID)
        set(CXX_STANDARD ${CXX_STANDARD_LATEST_ID})
    else()
        set(CXX_STANDARD ${CMAKE_CXX_STANDARD})
    endif()
    if(${CXX_STANDARD} LESS 20)
        message(FATAL_ERROR "C++ standard must be at least C++20")
    elseif(${CXX_STANDARD} EQUAL 20)
        set(CXX_STANDARD_FLAG "-std=c++2a")
    else()
        include(CheckCXXCompilerFlag)
        check_cxx_compiler_flag("-std=c++2b" COMPILER_TEST_C++2b)
        if(${COMPILER_TEST_C++2b})
            if(${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 15.0.0)
                set(CXX_STANDARD_FLAG "-std=c++2a")
            else()
                set(CXX_STANDARD_FLAG "-std=c++2b")
            endif()
        else()
            set(CXX_STANDARD_FLAG "-std=c++2a")
        endif()
    endif()

    set(ISYSROOT "")
    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang")
        set(ISYSROOT
                -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)
    endif()

    get_module_compile_flag(MODULE_FLAG)

    set(SRCS "")
    foreach(src ${ARGN})
        if(${src} STREQUAL "FRAGMENTS")
            message(FATAL_ERROR "Module partitions are not yet supported by Clang")
        endif()

        cmake_path(ABSOLUTE_PATH src)
        list(APPEND SRCS ${src})
    endforeach()
    file(MAKE_DIRECTORY ${PREBUILT_MODULE_PATH})

    set(MODULE_OBJECT_OUTPUT_DIR ${CMAKE_BINARY_DIR}/CMakeFiles/${name}.dir)
    set(MODULE_PCM_FILES "")
    set(MODULE_OBJ_FILES "")

    foreach(src ${SRCS})
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})
        if(IS_MODULE_INTERFACE)
            get_filename_component(SRC_STEM ${src} NAME_WLE)
            set(CUR_MODULE_PRECOMPILE ${PREBUILT_MODULE_PATH}/${SRC_STEM}.pcm)

            add_custom_command(
                    OUTPUT ${CUR_MODULE_PRECOMPILE}
                    DEPENDS ${src} ${MODULE_PCM_FILES}
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
                    ${CXX_STANDARD_FLAG}
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
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})
        if(IS_MODULE_INTERFACE)
            get_filename_component(SRC_STEM ${src} NAME_WLE)
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
                ${CMAKE_CXX_COMPILER}
                ${ISYSROOT}
                ${MODULE_FLAG}
                #-fimplicit-modules
                #-fimplicit-module-maps
                #-fmodules-cache-path=${PREBUILT_MODULE_PATH}
                ${MODULE_FILE_FLAGS}
                -fprebuilt-module-path=${PREBUILT_MODULE_PATH}
                ${CXX_STANDARD_FLAG}
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

    if(${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 15.0.0)
        set_target_properties(${target} PROPERTIES
                CXX_STANDARD 20)
    endif()

    get_module_compile_flag(MODULE_FLAG)
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