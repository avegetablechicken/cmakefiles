function(check_cxx_compiler_modules RESULT)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("-fmodules-ts" COMPILER_TEST_MODULES_TS)
    if(COMPILER_TEST_MODULES_TS)
        set(${RESULT} TRUE PARENT_SCOPE)
    else()
        check_cxx_compiler_flag("-fmodules" COMPILER_TEST_MODULES)
        if(COMPILER_TEST_MODULES)
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
    if(COMPILER_TEST_MODULES_TS)
        set(${MODULE_FLAG} "-fmodules-ts" PARENT_SCOPE)
    else()
        check_cxx_compiler_flag("-fmodules" COMPILER_TEST_MODULES)
        if(COMPILER_TEST_MODULES)
            set(${MODULE_FLAG} "-fmodules" PARENT_SCOPE)
        else()
            message(FATAL_ERROR "Modules are not yet support by current version")
        endif()
    endif()
endfunction()

set(PREBUILT_MODULE_PATH ${CMAKE_BINARY_DIR}/gcm.cache)
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
            set(CXX_STANDARD_FLAG "-std=c++2b")
        else()
            set(CXX_STANDARD_FLAG "-std=c++2a")
        endif()
    endif()

    get_module_compile_flag(MODULE_FLAG)

    set(SRCS "")
    foreach(src ${ARGN})
        cmake_path(ABSOLUTE_PATH src)
        list(APPEND SRCS ${src})
    endforeach()

    set(MODULE_OBJECT_OUTPUT_DIR ${CMAKE_BINARY_DIR}/CMakeFiles/${name}.dir)
    set(MODULE_PCM_FILES "")
    set(MODULE_OBJ_FILES "")

    foreach(src ${SRCS})
        get_filename_component(SRC_FILENAME ${src} NAME)
        set(CUR_MODULE_OBJECT ${MODULE_OBJECT_OUTPUT_DIR}/${SRC_FILENAME}.o)
        set(OUTPUT_FILES ${CUR_MODULE_OBJECT})

        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})
        if(IS_MODULE_INTERFACE)
            get_filename_component(SRC_STEM ${src} NAME_WLE)
            set(CUR_MODULE_PRECOMPILE ${PREBUILT_MODULE_PATH}/${SRC_STEM}.gcm)
            list(PREPEND OUTPUT_FILES ${CUR_MODULE_PRECOMPILE})
        endif()

        add_custom_command(
                OUTPUT ${OUTPUT_FILES}
                DEPENDS ${src} ${MODULE_PCM_FILES}
                COMMAND
                ${CMAKE_CXX_COMPILER}
                ${MODULE_FLAG}
                -x c++
                ${CXX_STANDARD_FLAG}
                -c -o ${CUR_MODULE_OBJECT}
                ${src}
        )

        list(APPEND MODULE_OBJ_FILES ${CUR_MODULE_OBJECT})
        if(IS_MODULE_INTERFACE)
            list(APPEND MODULE_PCM_FILES ${CUR_MODULE_PRECOMPILE})
        endif()
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
    get_module_compile_flag(MODULE_FLAG)
    foreach(name ${ARGN})
        target_compile_options(${target} PRIVATE ${MODULE_FLAG})
        add_dependencies(${target} ${name})
        #target_link_libraries(${target} PUBLIC ${name})
        get_target_property(objects ${name} OBJECTS)
        target_link_libraries(${target} PUBLIC ${objects})
    endforeach()
endfunction()