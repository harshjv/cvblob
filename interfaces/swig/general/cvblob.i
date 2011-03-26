%ignore operator<<;
 
%module cvblob
%{
#include "cvblob.h"
%}
 

// ---- Instantiate CvBlobs template -----

%include "std_map.i"
%template(CvBlobs) std::map<cvb::CvLabel, cvb::CvBlob* >;
/*
The following is a workaround for an apparent bug in how SWIG instantiates "%template() std::map<>" when using a pointer
as the map value.

Without this workaround, gcc will complain with the following:
 
      error: ‘type_name’ is not a member of ‘swig::traits<cvb::CvBlob>’

It appears that SWIG is looking for a swig::traits<cvb::CvBlob> definition, whereas it should be looking for
swig::traits<cvb::CvBlob *> (which SWIG does actually define).

The easiest workaround is to just provide the template specialization that the compiler is looking for. I dont think this
will cause any side effects, because from what i can tell, swig::traits<>::type_name is only used as a diagnostic message
when generating a SWIG_Error.

This issue has been reported as a bug to the SWIG sourceforge bugtracker:
- "std::map with class* key not compiling - ID: 1550362"
- http://sourceforge.net/tracker/index.php?func=detail&aid=1550362&group_id=1645&atid=101645
- Status of bug is "open" as of 05/02/2011.

*/
%{
    namespace swig {
        template <>  struct traits<cvb::CvBlob > {
            typedef pointer_category category;
            static const char* type_name() { return"cvb::CvBlob"; }
        };
    }
%}




// ---- Input typemap: PyObject* to IPLImage* conversion

/*
For the cvblob Python extension to be useable, we must be able to pass images returned by the
OpenCV Python extension to the cvblob python function wrappers.

Consider the following example (adapted from cvblob's test/test.cpp):

    // Create 2 images
    grey = cv.CreateImage(cv.GetSize(img),cv.IPL_DEPTH_8U,1)
    labelImg = cv.CreateImage(cv.GetSize(grey),IPL_DEPTH_LABEL,1)

    // Initialize images
    // ....
    // ....

    blobs = cvblob.CvBlobs()

    // Pass in the images to the cvLabel wrapper
    result = cvblob.cvLabel(grey,labelImg,blobs)


To be able to use the cvLabel() Python wrapper, we must tell SWIG how to convert the Python
arguments "grey" and "labelImg" into the  (IplImage *) arguments expected by cvBlob's C++
declaration of cvb::cvLabel().

To do this we define a SWIG input "%typemap". The code in this typemap will be inserted into
the SWIG generated wrapper code for every cvBlob function that accepts an IPLImage* argument. See
SWIG %typemap doco for details.

As for the actual PyObject* --> IplImage* conversion code: fortunately opencv already provides
this for us, with a function called "convert_to_IplImage"  in <opencv_root>/interfaces/python/cv.cpp.
This forms part of the opencv python extension cv.so. 

Unfortunately, "convert_to_IplImage" is not publicly exposed by cv.so, so we must here redefine
the function (and the necessary helper functions it uses).

*/
%{
    #include <opencv/cv.h>
    #include <Python.h>

    /* failmsg(): set the error message to the provide argument

       Note: this has been copied verbatim from <opencv_root>/interfaces/python/cv.cpp
    */
    static int failmsg(const char *fmt, ...)
    {
        char str[1000];

        va_list ap;
        va_start(ap, fmt);
        vsnprintf(str, sizeof(str), fmt, ap);
        va_end(ap);

        PyErr_SetString(PyExc_TypeError, str);
        return 0;
    }

    /* iplimage_t: a python wrapper for IplImage.

       Note: this has been copied verbatim from <opencv_root>/interfaces/python/cv.cpp
    */
    struct iplimage_t {
        PyObject_HEAD
        IplImage *a;
        PyObject *data;
        size_t offset;
    };

    /* is_iplimage(): return non-zero int if the supplied PyObject* is an IplImage
       
       Note:
        - this is a simplified adaptation of the definition of is_iplimage() in
          <opencv_root>/interfaces/python/cv.cpp
        - the opencv implementation uses a PyType_IsSubtype() check, however i couldn't 
          get this working. In anycase it involves porting more code...

    */
    static int is_iplimage(PyObject *o)
    {
        // See PyTypeObject, defined in object.h of Python include directory
        return (strcmp(o->ob_type->tp_name,"cv.iplimage") == 0);
    }


    /* convert_to_IplImage(): convert a PyObject* to IplImage*
      
       Note: this has been copied verbatim from <opencv_root>/interfaces/python/cv.cpp
    */
    static int convert_to_IplImage(PyObject *o, IplImage **dst, const char *name)
    {
        iplimage_t *ipl = (iplimage_t*)o;
        void *buffer;
        Py_ssize_t buffer_len;

        if (!is_iplimage(o)) {
            return failmsg("Argument '%s' must be IplImage", name);
        } else if (PyString_Check(ipl->data)) {
            cvSetData(ipl->a, PyString_AsString(ipl->data) + ipl->offset, ipl->a->widthStep);
            assert(cvGetErrStatus() == 0);
            *dst = ipl->a;
            return 1;
        } else if (ipl->data && PyObject_AsWriteBuffer(ipl->data, &buffer, &buffer_len) == 0) {
            cvSetData(ipl->a, (void*)((char*)buffer + ipl->offset), ipl->a->widthStep);
            assert(cvGetErrStatus() == 0);
            *dst = ipl->a;
            return 1;
        } else {
            return failmsg("IplImage argument '%s' has no data", name);
        }
    }
%}

/* Input typemap: convert from Python input object to C/C++ IplImage
   
   Note:
    - $input corresonds to the input Python object that is to be converted (i.e. PyObject*)
    - $1 refers to the corresponding C/C++ variable, i.e the recipient of the conversion (i.e. IplImage* )
*/
%typemap(in) IplImage *
{
    if (!convert_to_IplImage($input, &($1), "")) 
    {
        SWIG_exception( SWIG_TypeError, "%%typemap: could not convert input argument to an IplImage");
    }
}

// --- Output typemap: CvScalar to Python tuple

/* Python OpenCV treats CvScalar objects has 4-tuples, so for consistency lets do the same thing
here: when a function (e.g cvb::cvBlobMeanColor) returns a CvScalar object in C++, lets have the
python wrapper just return a 4-tuple.*/
%typemap(out) CvScalar 
{
   $result =  Py_BuildValue("(ffff)", $1.val[0], $1.val[1], $1.val[2], $1.val[3]);
}



// --- Declare the cvBlob interface to be wrapped ---

/* Wrap the entire cvblob interface */
%include "cvblob.h"

