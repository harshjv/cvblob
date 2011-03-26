/* swig/python/cvblob_pytypemaps.i

   Helper file which implements cvBlob C/C++ <---> Python SWIG typemaps .
*/

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

/* Typecheck typemap: check whether the Python input object is an IplImage* or not

    Note:
    - This is required when defining a typemap for types that are used in overloaded functions, or functions
    which use default arguments (which are treated by SWIG as overloaded functions).
    - Without this you will experience slightly cryptic runtime errors such as
    "NotImplementedError: Wrong number or type of arguments for overloaded function 'cvRenderBlobs'."
*/
%typemap(typecheck) IplImage * {
   $1 = is_iplimage($input) ? 1 : 0;
}


// --- Input typemap: Python tuple to CvScalar

%{

    #include <opencv/cv.h>
    #include <Python.h>

    /* is_tuple(): return non-zero int if the supplied PyObject* is a tuple */
    static int is_tuple(PyObject *o)
    {
        // See PyTypeObject, defined in object.h of Python include directory
        return (strcmp(o->ob_type->tp_name,"tuple") == 0);
    }

    /* convert_to_CvScalar: convert a PyObject to a CvScalar*

       NOTE:
       - CvScalar is a C array of doubles, of size 4
       - To be flexible, this function converts any tuple of size 1 through 4. If tuple size < 4, then all other entries in 
         the destination CvScalar are initialized to zero
       - upon completion, the (**dst) argument will point to a new CvScalar that has been created on the heap. This 
         requires us to also declare a %typemap(freearg) for CvScalar, see below.
    */
    static int convert_to_CvScalar(PyObject * obj, CvScalar** dst) {

        /* NOTE: we have no option but to create a new CvScalar on the heap here.
           This obliges us to also write a %typemap(freearg) for CvScalar */ 
        (*dst) = new CvScalar;
    
        // Initialize all CvScalar elements to zero 
        (*dst)->val[0] = (*dst)->val[1] = (*dst)->val[2] = (*dst)->val[3] = 0.0;
        int retval = 1;

        /* Parse the tuple. 
            
           Note the meaning of "d|ddd":
            - convert the parsed tuple to C doubles
            - parse tuples of at least size 1, and optionally upto size 4
        */
        if (PyArg_ParseTuple(obj, "d|ddd", &((*dst)->val[0]), &((*dst)->val[1]), &((*dst)->val[2]),&((*dst)->val[3])))
        {
            retval = 1;
        }
        else
        {
            retval =  failmsg("%%typemap: could not convert input argument to a CvScalar");
        }
        /*std::cout << "convert_to_CvScalar: " << (*dst)->val[0]  << " "
                    <<  (*dst)->val[1] << " " <<  (*dst)->val[2] << " " <<  (*dst)->val[3] << std::endl;*/

        return retval;
    }
%}


/* Input typemap: convert from Python input object to C/C++ CvScalar

NOTE: Python OpenCV treats CvScalar objects has 4-tuples, and this typemap lets us do the same thing. 
I.e when a function (e.g cvb::cvRenderContourPolygon) is expecting a CvScalar object in C++, the
corresponding python wrapper will accept a tuple.
*/
%typemap(in) (CvScalar&) 
{
    /* From reading the SWIG doco, i would have thought $1 would be of type (CvScalar&), as 
       declared by the typemap signature. However the SWIG generated code requires that i
       treat $1 here as being of type (CvScalar*) */
    if (!convert_to_CvScalar($input, &($1))) 
    {
        SWIG_exception( SWIG_TypeError, "%%typemap: could not convert input argument to a CvScalar");
    }
}

/* Typecheck typemap: check whether the Python input object is a CvScalar or not

    Note:
    - This is required when defining a typemap for types that are used in overloaded functions, or functions
    which use default arguments (which are treated by SWIG as overloaded functions).
    - Without this you will experience slightly cryptic runtime errors such as
    "NotImplementedError: Wrong number or type of arguments for overloaded function 'cvRenderContourPolygon'."
*/
%typemap(typecheck) (CvScalar&)  {
   $1 = is_tuple($input) ? 1 : 0;
}

/* Freearg typemap for CvScalar

   NOTE: 
    - this typemap is required because the input typemap (above) creates the converted CvScalar on the heap. Without
      this the relevant SWIG generated wrapper functions would have a memory leak.
    - SWIG inserts this code at the end of relevant wrapper functions.
*/
%typemap(freearg) (CvScalar&) {
   delete $1;
}

// --- Input typemap: Python tuple to CvPoint2D64f

%{
    #include <opencv/cv.h>
    #include <Python.h>

    static int convert_to_CvPoint2D64f(PyObject * obj, CvPoint2D64f& dst) {

        // Initialize to zero 
        (dst).x = (dst).y = 0.0;
        int retval = 1;

        if (PyArg_ParseTuple(obj, "dd", &((dst).x), &((dst).y)))
        {
            retval = 1;
        }
        else
        {
            retval =  failmsg("%%typemap: could not convert input argument to a CvPoint2D64f");
        }
      
        return retval;
    }
%}

/* Input typemap: convert from Python input object to a C/C++ CvPoint2D64f object

NOTE:
    - This allows us to assign python 2-tuples to CvBlob.centroid 
*/
%typemap(in) CvPoint2D64f
{
    if (!convert_to_CvPoint2D64f($input, ($1))) 
    {
        SWIG_exception( SWIG_TypeError, "%%typemap: could not convert input argument to a CvPoint type");
    }
}

// --- Output typemap: CvPoint2D64f to Python tuple

/* NOTE:
    - This typemap means that CvBlob.centroid will return a python 2-tuple
*/
%typemap(out) CvPoint2D64f
{
   $result =  Py_BuildValue("(dd)", $1.x, $1.y);
}


// --- Input typemap: Python tuple to CvPoint


%{
    #include <opencv/cv.h>
    #include <Python.h>


    // convert_to_CvPoint: convert a PyObject to a CvPoint object
    static int convert_to_CvPoint(PyObject * obj, CvPoint& dst) {

        // Initialize to zero 
        (dst).x = (dst).y = 0;
        int retval = 1;

        /* Parse the tuple. */
        if (PyArg_ParseTuple(obj, "ii", &((dst).x), &((dst).y)))
        {
            retval = 1;
        }
        else
        {
            retval =  failmsg("%%typemap: could not convert input argument to a CvPoint");
        }
      
        return retval;
    }

    // convert_to_NewCvPoint: same as convert_to_CvPoint, except the destination CvPoint object is created on the heap.
    static int convert_to_NewCvPoint(PyObject * obj, CvPoint** dst) {

        (*dst) = new CvPoint;
   
        return convert_to_CvPoint(obj, **dst);
    }

%}


/* Input typemap: convert from Python input object to C/C++ CvPoint objects

NOTE:
    - This allows us to assign python 2-tuples to CvContourChainCode.startingPoint
*/
%typemap(in) CvPoint 
{
    if (!convert_to_CvPoint($input, ($1))) 
    {
        SWIG_exception( SWIG_TypeError, "%%typemap: could not convert input argument to a CvPoint type");
    }
}

/*
NOTE:
    - This typemap means we can pass 2-tuples to CvContourPolygon.append() etc
    - It also means we can pass 2-tuples  to the various "Point" functions (e.g cvDistancePointPoint)
*/
%typemap(in) (CvPoint const &)
{
    // Note that even though the destination type is a const reference, SWIG will declare the CvPoint as a pointer,
    // and we have to instantiate it on the heap
    if (!convert_to_NewCvPoint($input, &($1))) 
    {
        SWIG_exception( SWIG_TypeError, "%%typemap: could not convert input argument to a CvPoint");
    }
}

%typemap(freearg) (CvPoint const &) {
   delete $1;
}


// --- Output typemap: CvPoint to Python tuple

/* NOTE:
    - This typemap means that CvContourChainCode.startingPoint  will return a python 2-tuple
*/
%typemap(out) CvPoint
{
   $result =  Py_BuildValue("(ii)", $1.x, $1.y);
}

/* NOTE:
    - This typemap means that CvContourPolygon.front() etc. will return a python 2-tuple
*/
%typemap(out) (CvPoint const &)
{
    // Note that even though the return type is a const reference, SWIG will declare the CvPoint as a pointer
    $result = Py_BuildValue("(ii)", $1->x, $1->y);

}


// --- Output typemap: CvScalar to Python tuple

/* Python OpenCV treats CvScalar objects has 4-tuples, so for consistency lets do the same thing
here: when a function (e.g cvb::cvBlobMeanColor) returns a CvScalar object in C++, lets have the
python wrapper just return a 4-tuple.*/
%typemap(out) CvScalar 
{
   $result =  Py_BuildValue("(dddd)", $1.val[0], $1.val[1], $1.val[2], $1.val[3]);
}


