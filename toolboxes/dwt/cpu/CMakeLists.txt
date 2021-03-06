if (WIN32)
    ADD_DEFINITIONS(-D__BUILD_GADGETRON_CPUDWT__)
endif (WIN32)

include_directories(
    ${Boost_INCLUDE_DIR}
    ${CMAKE_SOURCE_DIR}/toolboxes/core
    ${CMAKE_SOURCE_DIR}/toolboxes/core/cpu
    ${CMAKE_SOURCE_DIR}/toolboxes/core/cpu/image
    ${CMAKE_SOURCE_DIR}/toolboxes/core/cpu/math
    )

add_library(gadgetron_toolbox_cpudwt SHARED 
    cpudwt_export.h 
    hoNDWavelet.h
    hoNDWavelet.cpp
    hoNDHarrWavelet.h
    hoNDHarrWavelet.cpp
    hoNDRedundantWavelet.h
    hoNDRedundantWavelet.cpp
    )

set_target_properties(gadgetron_toolbox_cpudwt PROPERTIES VERSION ${GADGETRON_VERSION_STRING} SOVERSION ${GADGETRON_SOVERSION})

target_link_libraries(gadgetron_toolbox_cpudwt
                    gadgetron_toolbox_cpucore
                    gadgetron_toolbox_log
                    gadgetron_toolbox_cpucore_math
                    )

install(TARGETS gadgetron_toolbox_cpudwt DESTINATION lib COMPONENT main)

install(FILES
    cpudwt_export.h 
    hoNDWavelet.h
    hoNDHarrWavelet.h
    hoNDRedundantWavelet.h
    DESTINATION ${GADGETRON_INSTALL_INCLUDE_PATH} COMPONENT main)
