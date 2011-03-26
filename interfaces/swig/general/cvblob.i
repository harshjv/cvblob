%ignore operator<<;
 
%module cvblob
%{
#include "cvblob.h"
%}
 
%include "cvblob.h"

// ---- Instantiate CvBlobs template

%include "std_map.i"
%template(CvBlobs) std::map<cvb::CvLabel, cvb::CvBlob* >;

// The following is a workaround for an apparent bug in how SWIG instantiates "%template() std::map<>" when using pointers as map values.
//
// Without this workaround, gcc will complain with the following:
// 
//      error: ‘type_name’ is not a member of ‘swig::traits<cvb::CvBlob>’
//
// In appears that SWIG is looking for a swig::traits<cvb::CvBlob> definition, whereas it should be looking for swig::traits<cvb::CvBlob *>,
// which SWIG does actually define.
// 
// The easiest workaround is to just provide the definition that the compiler is looking for. I dont think this will cause any side effects,
// as from what i can tell, swig::traits<>::type_name is only used as diagnostic message when generating a SWIG_Error.
//
// For a discussion this see: http://blog.gmane.org/gmane.comp.programming.swig/month=20061201/page=6
%{
namespace swig {
    template <>  struct traits<cvb::CvBlob > {
      typedef pointer_category category;
      static const char* type_name() { return"cvb::CvBlob"; }
    };
  }
%}

