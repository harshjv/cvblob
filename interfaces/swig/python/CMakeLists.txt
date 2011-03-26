# ----------------------------------------------------------------------------
#  CMake file for python support
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


