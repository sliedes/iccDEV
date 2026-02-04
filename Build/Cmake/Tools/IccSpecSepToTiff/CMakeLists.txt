set(SRC_PATH ../../../..)
set(SOURCES
    ${SRC_PATH}/Tools/CmdLine/IccSpecSepToTiff/iccSpecSepToTiff.cpp
    ${SRC_PATH}/Tools/CmdLine/IccApplyProfiles/TiffImg.cpp
)

set(TARGET_NAME iccSpecSepToTiff)
include_directories(${SRC_PATH}/Tools/CmdLine/IccApplyProfiles)

add_executable(${TARGET_NAME} ${SOURCES})

# Add dependency include directories
if(TIFF_INCLUDE_DIR)
  target_include_directories(${TARGET_NAME} PRIVATE ${TIFF_INCLUDE_DIR})
endif()
if(JPEG_INCLUDE_DIR)
  target_include_directories(${TARGET_NAME} PRIVATE ${JPEG_INCLUDE_DIR})
endif()
if(ZLIB_INCLUDE_DIR)
  target_include_directories(${TARGET_NAME} PRIVATE ${ZLIB_INCLUDE_DIR})
endif()

target_link_libraries(${TARGET_NAME}
    ${TARGET_LIB_ICCPROFLIB}
    ${TIFF_LIBRARY}
    ${JPEG_LIBRARY}
    ${ZLIB_LIBRARY}
)

if(ENABLE_INSTALL_RIM)
    install(TARGETS ${TARGET_NAME} DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
