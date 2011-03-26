# Copyright (C) 2007 by Cristobal Carnero Linan
# grendel.ccl@gmail.com
#
# This file is part of cvBlob.
#
# cvBlob is free software: you can redistribute it and/or modify
# it under the terms of the Lesser GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cvBlob is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# Lesser GNU General Public License for more details.
#
# You should have received a copy of the Lesser GNU General Public License
# along with cvBlob.  If not, see <http://www.gnu.org/licenses/>.
#

# ----------------------------------------------------------------------------------
# NOTE - zorzalzilba  
# This file is a python version of the original C++ test/test.cpp
# ----------------------------------------------------------------------------------

# Import opencv and cvblob python extensions
# Note: these must be findable on PYTHONPATH
import cv
import cvblob as cvb


img = cv.LoadImage("../../../../test/test.png",1)

cv.SetImageROI(img, (100, 100, 800, 500))

grey = cv.CreateImage(cv.GetSize(img), cv.IPL_DEPTH_8U,1)
cv.CvtColor(img, grey, cv.CV_BGR2GRAY)
cv.Threshold(grey, grey, 100, 255, cv.CV_THRESH_BINARY)

IPL_DEPTH_LABEL = 32
labelImg = cv.CreateImage(cv.GetSize(grey), IPL_DEPTH_LABEL, 1)

blobs = cvb.CvBlobs()
result = cvb.cvLabel(grey,labelImg,blobs)

imgOut = cv.CreateImage(cv.GetSize(img), cv.IPL_DEPTH_8U,3)
cv.Zero(imgOut);
cvb.cvRenderBlobs(labelImg, blobs, img, imgOut);

# Render contours:
for label, blob in blobs.iteritems(): 

    meanColor = cvb.cvBlobMeanColor(blob, labelImg, img)
    print "Mean color: r=" + str(meanColor[0]) + ", g=" + str(meanColor[1]) + ", b=" + str(meanColor[2])

    polygon = cvb.cvConvertChainCodesToPolygon(blob.contour)

    sPolygon = cvb.cvSimplifyPolygon(polygon, 10.)
    cPolygon = cvb.cvPolygonContourConvexHull(sPolygon)
     
    cvb.cvRenderContourChainCode(blob.contour, imgOut)
    cvb.cvRenderContourPolygon(sPolygon, imgOut,cv.CV_RGB(0, 0, 255))
    cvb.cvRenderContourPolygon(cPolygon, imgOut,cv.CV_RGB(0, 255, 0))

    # Render internal contours:
    for contour in blob.internalContours: 
        cvb.cvRenderContourChainCode(contour, imgOut)

cv.NamedWindow("test", 1);
cv.ShowImage("test", imgOut)
# cv.ShowImage("grey", grey);
cv.WaitKey(0)
cv.DestroyWindow("test");

