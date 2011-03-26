/* swig/python/cvblob.i

   Python SWIG interface file for cvBlob library.
*/

// Declare the module
%module cvblob

%{
    #include "cvblob.h"
%}

// Have SWIG generate python docstrings
%feature("autodoc", 1);


// Import the cvBlob C++ <--> python SWIG typemaps
%include "./cvblob_pytypemaps.i"

// Import the language independent SWIG interface
%include "../general/cvblob.i"

// Add module docstring
%pythoncode 
%{

__doc__ = """
cvBlob is a computer vision library designed to detect connected
regions in binary digital images. cvBlob performs connected
component analysis (also known as labeling) and features extraction.

This wrapper was automatically created from the C/C++ headers
using SWIG, and therefore contains little Python documentation.
All identifiers are identical or similar to their C/C++
counterparts, so please refer to the cvBlob C/C++
documentation for details."""

%}
