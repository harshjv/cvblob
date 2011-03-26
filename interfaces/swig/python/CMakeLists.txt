# ----------------------------------------------------------------------------
#  CMake file for python support
#  (adapted from OpenCV interfaces/swig/python/CMakeLists.txt)
# ----------------------------------------------------------------------------
project(python_support)

find_package(SWIG REQUIRED)
find_package(OpenCV REQUIRED)

include(${SWIG_USE_FILE})

include_directories(${PYTHON_INCLUDE_PATH})
include_directories(${OpenCV_INCLUDE_DIRS})
include_directories("${OpenCV_INCLUDE_DIRS}/..")
include_directories("../../../cvBlob")

# ------------------------------- cvblob module ------------------------------

set(CMAKE_SWIG_FLAGS "")

set_source_files_properties(cvblob.i PROPERTIES
    CPLUSPLUS ON
    SWIG_FLAGS -Wall
    )

SWIG_ADD_MODULE(cvblob python
    ./cvblob.i
    ../../../cvBlob/cvaux.cpp
    ../../../cvBlob/cvblob.cpp
    ../../../cvBlob/cvcolor.cpp
    ../../../cvBlob/cvcontour.cpp
    ../../../cvBlob/cvlabel.cpp
    ../../../cvBlob/cvtrack.cpp)

SWIG_LINK_LIBRARIES(cvblob ${PYTHON_LIBRARIES} ${OpenCV_LIBS})

if(APPLE)
    set(CMAKE_SHARED_MODULE_CREATE_CXX_FLAGS "${CMAKE_SHARED_MODULE_CREATE_CXX_FLAGS} -flat_namespace")
endif(APPLE)

# ------------------------------ installation ----------------------------------


get_target_property(LOC_CVBLOB ${SWIG_MODULE_cvblob_REAL_NAME} LOCATION)
string(REPLACE "\$(OutDir)" "\${CMAKE_INSTALL_CONFIG_NAME}" m1 ${LOC_CVBLOB})

set(pycvblob_files ${LOC_CVBLOB} ${CMAKE_CURRENT_BINARY_DIR}/cvblob.py)


if(WIN32)
    install(FILES ${pycvblob_files} 
            DESTINATION "Python${PYTHON_VERSION_MAJOR_MINOR}/Lib/site-packages/cvblob"
            COMPONENT main)
else()
    install(FILES ${pycvblob_files}
           DESTINATION ${PYTHON_PLUGIN_INSTALL_PATH}
           COMPONENT main)
endif()


