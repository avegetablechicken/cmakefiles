function(check_cxx_compiler_modules RESULT)
    if(${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang")
        message(STATUS "Modules are not yet support by clang-cl.exe")
        set(${RESULT} FALSE PARENT_SCOPE)
        return()
    endif()
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("/experimental:module" COMPILER_SUPPORTS_MODULES)
    if(COMPILER_SUPPORTS_MODULES)
        set(${RESULT} TRUE PARENT_SCOPE)
    else()
        message(STATUS "Modules are not yet support by current version")
        set(${RESULT} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(get_module_compile_flag MODULE_FLAG)
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("/experimental:module" COMPILER_SUPPORTS_MODULES)
    if(COMPILER_SUPPORTS_MODULES)
        set(${MODULE_FLAG} "/experimental:module" PARENT_SCOPE)
    else()
        message(FATAL "Modules are not yet support by current version")
    endif()
endfunction()

set(PREBUILT_MODULE_PATH ${CMAKE_BINARY_DIR}/ifc.cache)
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
    get_module_compile_flag(MODULE_FLAG)
    set(STDIFC_BASE_DIR
            "${CMAKE_CXX_COMPILER}/../../../../ifc/x64")
    cmake_path(ABSOLUTE_PATH STDIFC_BASE_DIR NORMALIZE)

    if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
        set(LINK_MODE_FLAG /MDd)
        set(STDIFC_DIR "${STDIFC_BASE_DIR}/Debug")
    else()
        set(LINK_MODE_FLAG /MD)
        set(STDIFC_DIR "${STDIFC_BASE_DIR}/Release")
    endif()

    set(SRCS "")
    set(FRAGMENT_SRCS "")
    set(_IS_FRAGMENT FALSE)
    foreach(src ${ARGN})
        if(${src} STREQUAL "FRAGMENTS")
            set(_IS_FRAGMENT TRUE)
            continue()
        endif()

        cmake_path(ABSOLUTE_PATH src)
        if(_IS_FRAGMENT)
            list(APPEND FRAGMENT_SRCS ${src})
        else()
            list(APPEND SRCS ${src})
        endif()
    endforeach()
    file(MAKE_DIRECTORY ${PREBUILT_MODULE_PATH})

    set(MODULE_OBJECT_OUTPUT_DIR ${CMAKE_BINARY_DIR}/CMakeFiles/${name}.dir)
    set(MODULE_PCM_FILES "")
    set(MODULE_OBJ_FILES "")
    set(MODULE_FRAGMENT_REFERENCES "")

    foreach(src ${SRCS})
        get_filename_component(SRC_STEM ${src} NAME_WLE)
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})

        if(IS_MODULE_INTERFACE)
            if(FRAGMENT_SRCS AND ${src} IN_LIST FRAGMENT_SRCS)
                string(REPLACE "." "-" fragment_file_stem ${SRC_STEM})
                set(CUR_MODULE_PRECOMPILE ${PREBUILT_MODULE_PATH}/${fragment_file_stem}.ifc)
            else()
                set(CUR_MODULE_PRECOMPILE ${PREBUILT_MODULE_PATH}/${SRC_STEM}.ifc)
            endif()

            get_filename_component(SRC_FILENAME ${src} NAME)
            set(CUR_MODULE_OBJECT ${MODULE_OBJECT_OUTPUT_DIR}/${SRC_FILENAME}.obj)
            add_custom_command(
                    OUTPUT ${CUR_MODULE_PRECOMPILE} ${CUR_MODULE_OBJECT}
                    DEPENDS ${src} ${MODULE_PCM_FILES}
                    #COMMAND
                    #if not exist ${PREBUILT_MODULE_PATH} md ${PREBUILT_MODULE_PATH}
                    COMMAND
                    ${CMAKE_CXX_COMPILER}
                    ${MODULE_FLAG}
                    /stdIfcDir${STDIFC_DIR}
                    /ifcSearchDir${PREBUILT_MODULE_PATH}
                    ${MODULE_FRAGMENT_REFERENCES}
                    /interface
                    /TP
                    /std:c++latest
                    /EHsc /nologo
                    ${LINK_MODE_FLAG}
                    /ifcOutput${CUR_MODULE_PRECOMPILE}
                    /c /Fo${CUR_MODULE_OBJECT}
                    ${src})
            list(APPEND MODULE_PCM_FILES ${CUR_MODULE_PRECOMPILE})
            list(APPEND MODULE_OBJ_FILES ${CUR_MODULE_OBJECT})

            if(FRAGMENT_SRCS AND ${src} IN_LIST FRAGMENT_SRCS)
                string(REPLACE "." ":" fragment_name ${SRC_STEM})
                list(APPEND MODULE_FRAGMENT_REFERENCES
                        /reference${fragment_name}=${CUR_MODULE_PRECOMPILE})
            endif()
        endif()
    endforeach()

    foreach(src ${SRCS})
        get_filename_component(SRC_STEM ${src} NAME_WLE)
        check_accepted_module_interface(IS_MODULE_INTERFACE ${src})
        if(IS_MODULE_INTERFACE)
            continue()
        endif()

        get_filename_component(SRC_FILENAME ${src} NAME)
        set(CUR_MODULE_OBJECT ${MODULE_OBJECT_OUTPUT_DIR}/${SRC_FILENAME}.obj)
        add_custom_command(
                OUTPUT ${CUR_MODULE_OBJECT}
                DEPENDS ${src} ${MODULE_PCM_FILES}
                #COMMAND
                #if not exist ${PREBUILT_MODULE_PATH} md ${PREBUILT_MODULE_PATH}
                COMMAND
                ${CMAKE_CXX_COMPILER}
                ${MODULE_FLAG}
                /stdIfcDir${STDIFC_DIR}
                /ifcSearchDir${PREBUILT_MODULE_PATH}
                ${MODULE_FRAGMENT_REFERENCES}
                /TP
                /std:c++latest
                /EHsc /nologo
                ${LINK_MODE_FLAG}
                /c /Fo${CUR_MODULE_OBJECT}
                ${src}
        )
        list(APPEND MODULE_OBJ_FILES ${CUR_MODULE_OBJECT})

    endforeach()

    #add_library(${name} ${MODULE_OBJ_FILES})
    #set_target_properties(${name} PROPERTIES
    #        LINKER_LANGUAGE CXX
    #        MODULE_FRAGMENT_REFERENCES "${MODULE_FRAGMENT_REFERENCES}")

    add_custom_target(${name}
            DEPENDS ${MODULE_OBJ_FILES})
    set_target_properties(${name} PROPERTIES
            OBJECTS "${MODULE_OBJ_FILES}"
            MODULE_FRAGMENT_REFERENCES "${MODULE_FRAGMENT_REFERENCES}")

endfunction()

function(target_link_module target)
    get_module_compile_flag(MODULE_FLAG)
    target_compile_options(${target} PRIVATE
            ${MODULE_FLAG}
            /ifcSearchDir${PREBUILT_MODULE_PATH})

    foreach(name ${ARGN})
        add_dependencies(${target} ${name})

        #target_link_libraries(${target} PUBLIC ${name})
        get_target_property(objects ${name} OBJECTS)
        target_link_libraries(${target} PUBLIC ${objects})

        get_target_property(options ${name} MODULE_FRAGMENT_REFERENCES)
        foreach(opt ${options})
            target_compile_options(${target} PRIVATE ${opt})
        endforeach()
    endforeach()
endfunction()