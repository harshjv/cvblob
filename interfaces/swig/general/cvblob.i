%ignore operator<<;
 
%module cvblob
%{
#include "cvblob.h"
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


// --- Output typemap: CvScalar to Python tuple

/* Python OpenCV treats CvScalar objects has 4-tuples, so for consistency lets do the same thing
here: when a function (e.g cvb::cvBlobMeanColor) returns a CvScalar object in C++, lets have the
python wrapper just return a 4-tuple.*/
%typemap(out) CvScalar 
{
   $result =  Py_BuildValue("(ffff)", $1.val[0], $1.val[1], $1.val[2], $1.val[3]);
}



// --- Declare the cvBlob interface to be wrapped ---


namespace cvb
{

    #define CV_CHAINCODE_UP		0 ///< Up.
    #define CV_CHAINCODE_UP_RIGHT	1 ///< Up and right.
    #define CV_CHAINCODE_RIGHT	2 ///< Right.
    #define CV_CHAINCODE_DOWN_RIGHT	3 ///< Down and right.
    #define CV_CHAINCODE_DOWN	4 ///< Down.
    #define CV_CHAINCODE_DOWN_LEFT	5 ///< Down and left.
    #define CV_CHAINCODE_LEFT	6 ///< Left.
    #define CV_CHAINCODE_UP_LEFT	7 ///< Up and left.

    const char cvChainCodeMoves[8][2] = { { 0, -1},
                                        { 1, -1},
                    { 1,  0},
                    { 1,  1},
                    { 0,  1},
                    {-1,  1},
                    {-1,  0},
                    {-1, -1}
                                        };

    typedef unsigned char CvChainCode;

    typedef std::list<CvChainCode> CvChainCodes;

    struct CvContourChainCode
    {
    CvPoint startingPoint; ///< Point where contour begin.
    CvChainCodes chainCode; ///< Polygon description based on chain codes.
    };

    typedef std::list<CvContourChainCode *> CvContoursChainCode; ///< List of contours (chain codes type).

    typedef std::vector<CvPoint> CvContourPolygon;

    void cvRenderContourChainCode(CvContourChainCode const *contour, IplImage const *img, CvScalar const &color=CV_RGB(255, 255, 255));

    CvContourPolygon *cvConvertChainCodesToPolygon(CvContourChainCode const *cc);

    void cvRenderContourPolygon(CvContourPolygon const *contour, IplImage *img, CvScalar const &color=CV_RGB(255, 255, 255));

    double cvContourPolygonArea(CvContourPolygon const *p);

    double cvContourChainCodePerimeter(CvContourChainCode const *c);

    double cvContourPolygonPerimeter(CvContourPolygon const *p);

    double cvContourPolygonCircularity(const CvContourPolygon *p);

    CvContourPolygon *cvSimplifyPolygon(CvContourPolygon const *p, double const delta=1.);

    CvContourPolygon *cvPolygonContourConvexHull(CvContourPolygon const *p);

    void cvWriteContourPolygonCSV(const CvContourPolygon& p, const std::string& filename);

    void cvWriteContourPolygonSVG(const CvContourPolygon& p, const std::string& filename, const CvScalar& stroke=cvScalar(0,0,0), const CvScalar& fill=cvScalar(255,255,255));

    typedef unsigned int CvLabel;

    #define IPL_DEPTH_LABEL (sizeof(cvb::CvLabel)*8)

    #define CV_BLOB_MAX_LABEL std::numeric_limits<CvLabel>::max()

    typedef unsigned int CvID;

    struct CvBlob
    {
        CvLabel label; ///< Label assigned to the blob.

        union
        {
            unsigned int area; ///< Area (moment 00).
            unsigned int m00; ///< Moment 00 (area).
        };

        unsigned int minx; ///< X min.
        unsigned int maxx; ///< X max.
        unsigned int miny; ///< Y min.
        unsigned int maxy; ///< y max.

        CvPoint2D64f centroid; ///< Centroid.

        double m10; ///< Moment 10.
        double m01; ///< Moment 01.
        double m11; ///< Moment 11.
        double m20; ///< Moment 20.
        double m02; ///< Moment 02.

        double u11; ///< Central moment 11.
        double u20; ///< Central moment 20.
        double u02; ///< Central moment 02.

        double n11; ///< Normalized central moment 11.
        double n20; ///< Normalized central moment 20.
        double n02; ///< Normalized central moment 02.

        double p1; ///< Hu moment 1.
        double p2; ///< Hu moment 2.

        CvContourChainCode contour;           ///< Contour.
        CvContoursChainCode internalContours; ///< Internal contours.
    };

    typedef std::map<CvLabel,CvBlob *> CvBlobs;

    typedef std::pair<CvLabel,CvBlob *> CvLabelBlob;

    unsigned int cvLabel (IplImage const *img, IplImage *imgOut, CvBlobs &blobs);

    void cvFilterLabels(IplImage *imgIn, IplImage *imgOut, const CvBlobs &blobs);

    CvLabel cvGetLabel(IplImage const *img, unsigned int x, unsigned int y);

    void cvReleaseBlob(CvBlob *blob);

    void cvReleaseBlobs(CvBlobs &blobs);

    CvLabel cvGreaterBlob(const CvBlobs &blobs);

    void cvFilterByArea(CvBlobs &blobs, unsigned int minArea, unsigned int maxArea);

    void cvFilterByLabel(CvBlobs &blobs, CvLabel label);

    CvPoint2D64f cvCentroid(CvBlob *blob);

    double cvAngle(CvBlob *blob);

    void cvSaveImageBlob(const char *filename, IplImage *img, CvBlob const *blob);

    #define CV_BLOB_RENDER_COLOR            0x0001 ///< Render each blog with a different color. \see cvRenderBlobs
    #define CV_BLOB_RENDER_CENTROID         0x0002 ///< Render centroid. \see cvRenderBlobs
    #define CV_BLOB_RENDER_BOUNDING_BOX     0x0004 ///< Render bounding box. \see cvRenderBlobs
    #define CV_BLOB_RENDER_ANGLE            0x0008 ///< Render angle. \see cvRenderBlobs
    #define CV_BLOB_RENDER_TO_LOG           0x0010 ///< Print blob data to log out. \see cvRenderBlobs
    #define CV_BLOB_RENDER_TO_STD           0x0020 ///< Print blob data to std out. \see cvRenderBlobs

    void cvRenderBlob(const IplImage *imgLabel, CvBlob *blob, IplImage *imgSource, IplImage *imgDest, unsigned short mode=0x000f, CvScalar const &color=CV_RGB(255, 255, 255), double alpha=1.);

    void cvRenderBlobs(const IplImage *imgLabel, CvBlobs &blobs, IplImage *imgSource, IplImage *imgDest, unsigned short mode=0x000f, double alpha=1.);

    void cvSetImageROItoBlob(IplImage *img, CvBlob const *blob);

    CvScalar cvBlobMeanColor(CvBlob const *blob, IplImage const *imgLabel, IplImage const *img);

    double cvDotProductPoints(CvPoint const &a, CvPoint const &b, CvPoint const &c);

    double cvCrossProductPoints(CvPoint const &a, CvPoint const &b, CvPoint const &c);

    double cvDistancePointPoint(CvPoint const &a, CvPoint const &b);

    double cvDistanceLinePoint(CvPoint const &a, CvPoint const &b, CvPoint const &c, bool isSegment=true);

    struct CvTrack
    {
        CvID id; ///< Track identification number.

        CvLabel label; ///< Label assigned to the blob related to this track.

        unsigned int minx; ///< X min.
        unsigned int maxx; ///< X max.
        unsigned int miny; ///< Y min.
        unsigned int maxy; ///< y max.

        CvPoint2D64f centroid; ///< Centroid.

        unsigned int lifetime; ///< Indicates how much frames the object has been in scene.
        unsigned int active; ///< Indicates number of frames that has been active from last inactive period.
        unsigned int inactive; ///< Indicates number of frames that has been missing.
    };

    typedef std::map<CvID, CvTrack *> CvTracks;

    typedef std::pair<CvID, CvTrack *> CvIDTrack;

    void cvReleaseTracks(CvTracks &tracks);

    void cvUpdateTracks(CvBlobs const &b, CvTracks &t, const double thDistance, const unsigned int thInactive, const unsigned int thActive=0);

    #define CV_TRACK_RENDER_ID            0x0001 ///< Print the ID of each track in the image. \see cvRenderTracks
    #define CV_TRACK_RENDER_BOUNDING_BOX  0x0002 ///< Draw bounding box of each track in the image. \see cvRenderTracks
    #define CV_TRACK_RENDER_TO_LOG        0x0010 ///< Print track info to log out. \see cvRenderTracks
    #define CV_TRACK_RENDER_TO_STD        0x0020 ///< Print track info to log out. \see cvRenderTracks

    void cvRenderTracks(CvTracks const tracks, IplImage *imgSource, IplImage *imgDest, unsigned short mode=0x000f, CvFont *font=NULL);

}//namespace cvb




// ---- Instantiate CvBlobs template -----

/* 
Note the following %template must be declared after CvLabel is added to the SWIG interface, otherwise
cryptic memory leaks will result when using CvBlobs.iteritems(), keyitems(), or key_iterator()
*/
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

// ---- Instantiate CvContourPolygon template -----
%include "std_vector.i"
%template(CvContourPolygon) std::vector<CvPoint>;
