all: cvblob_obj swig swig_obj ext 

cvblob_obj:
	g++ -c -arch i386 -arch x86_64 -I../../../opencv-2.1.0/include/opencv ../cvBlob/cvaux.cpp ../cvBlob/cvblob.cpp ../cvBlob/cvcolor.cpp ../cvBlob/cvcontour.cpp ../cvBlob/cvlabel.cpp ../cvBlob/cvtrack.cpp

swig:
	swig -Wall -I../cvBlob -c++ -o ./cvblob_wrap.cxx -python ../interfaces/swig/python/cvblob.i

swig_obj:
	g++ -c -arch i386 -arch x86_64 -I../../../opencv-2.1.0/include -I../../../opencv-2.1.0/include/opencv -I../cvBlob -I /Library/Frameworks/Python.framework/Versions/2.7/include/python2.7/ cvblob_wrap.cxx

ext:
	g++ -arch i386 -arch x86_64 -L../../../opencv-2.1.0/lib -lcv -lcvaux -lcxcore -lpython  -arch i386  -dynamiclib -flat_namespace *.o -o _cvblob.so

clean:
	@echo "Cleaning..."
	@\rm -f *.o
	@\rm -f *.so
	@\rm -f cvblob_wrap.cxx
	@\rm -f cvblob.py


