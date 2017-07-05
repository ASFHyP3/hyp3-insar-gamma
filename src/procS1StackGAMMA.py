#!/usr/bin/env python
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
###############################################################################
# procS1StackGAMMA_recipe.py 
#
# Project:   
# Purpose:  Wrapper script for processing a stack of Sentinel-1 with Gamma
#          
# Author:  Tom Logan
#
###############################################################################
# Copyright (c) 2015, Alaska Satellite Facility
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.
###############################################################################

#####################
#
# Import all needed modules right away
#
#####################
import sys
import os
from lxml import etree
import re
import math
from get_dem import get_dem
from getSubSwath import get_bounding_box_file
from prepGamma import prepGamma
from execute import execute
from osgeo import gdal
import zipfile
import argparse
import file_subroutines
from getDemFor import getDemFile

#####################
#
# Define procedures
#
#####################

def getDemFileGamma(filenames,use_opentopo,rlooks):

    getDemFile(filenames[0],"tmpdem.tif",opentopoFlag=use_opentopo,utmFlag=True)

    # If we downsized the SAR image, downsize the DEM file
    # if rlks == 1, then the SAR image is roughly 20 m square -> use native dem res
    # if rlks == 2, then the SAR image is roughly 40 m square -> set dem to 80 meters
    # if rlks == 3, then the SAR image is roughly 60 m square -> set dem to 120 meters 
    # etc.
    #
    # The DEM is set to double the res because it will be 1/2'd by the procedure
    # I.E. if you give a 100 meter DEM as input, the output Igram is 50 meters

    pix_size = 20 * int(rlooks) * 2;
    gdal.Warp("tmpdem2.tif","tmpdem.tif",xRes=pix_size,yRes=pix_size,resampleAlg="average")
    
    if use_opentopo == True:
      cmd = "utm2dem_i2.pl tmpdem2.tif big.dem big.par"
    else:
      cmd = "utm2dem.pl tmpdem2.tif big.dem big.par"
    execute(cmd)
    return("big")

def getBurstOverlaps(mydir):
    t = re.split('_',mydir)
    master = t[0]
    slave = t[1]
    time1 = []
    time2 = []
    os.chdir(mydir) 
    for myfile in os.listdir("."):
        if ".SAFE" in myfile and master in myfile:
            os.chdir(myfile)
            os.chdir("annotation")
            for myfile2 in os.listdir("."):
                if "001.xml" in myfile2:
                    root = etree.parse(myfile2)
                    for coord in root.iter('azimuthAnxTime'):
                        time1.append(float(coord.text))
                    for count in root.iter('burstList'):
                        total_bursts1=int(count.attrib['count'])
            os.chdir("../..")
        elif ".SAFE" in myfile and slave in myfile:
            os.chdir(myfile)
            os.chdir("annotation")
            for myfile2 in os.listdir("."):
                if "001.xml" in myfile2:
                    root = etree.parse(myfile2)
                    for coord in root.iter('azimuthAnxTime'):
                        time2.append(float(coord.text))
                    for count in root.iter('burstList'):
                        total_bursts2=int(count.attrib['count'])
            os.chdir("../..")

    cnt = 1
    found = 0
    x = time1[0]
    for y in time2:
        if (abs(x-y) < 0.05):
            print "Found burst match at 1 %s" % cnt
            found = 1
            start1 = 1
            start2 = cnt
        cnt += 1

    if found == 0:
        y = time2[0]
        cnt = 1
        for x in time1:
            if (abs(x-y) < 0.05):
                print "Found burst match at %s 1" % cnt
                found = 1
                start1 = cnt
                start2 = 1
            cnt += 1

    size1 = total_bursts1 - start1 + 1
    size2 = total_bursts2 - start2 + 1

    if (size1 > size2):
        size = size2
    else:
        size = size1
    return start1, start1+size-1, start2, start2+size-1

def gammaProcess(mydir,dem,alooks,rlooks):
    cmd = 'cd %s; ' % mydir 
    (s1,e1,s2,e2) = getBurstOverlaps(mydir)
    cmd = cmd + 'ifm_sentinel.pl -d=%s IFM %s %s %s %s %s %s ' % (dem,alooks,rlooks,s1,e1,s2,e2)
    execute(cmd)

def makeDirAndLinks(name1,name2,file1,file2,dem):
    dirname = '%s_%s' % (name1,name2)
    if not os.path.exists(dirname):
        os.mkdir(dirname)
    os.chdir(dirname)
    os.symlink("../%s" % file1,"%s" % file1)
    os.symlink("../%s" % file2,"%s" % file2)
    os.symlink("../%s.dem" % dem,"%s.dem" % dem)
    os.symlink("../%s.par" % dem,"%s.par" % dem)
    os.chdir('..')

###########################################################################
#  Main entry point --
#
# 	alooks = azimuth looks
#	rlooks = range looks
#	file = name of CSV file use to for get_asf.py
#	dem = name of external DEM file 
#	use_opentopo = flag for using opentopo instead of get_dem
#
###########################################################################
def procS1StackGAMMA(alooks=20,rlooks=4,csvFile=None,dem=None,use_opentopo=None):

    # If file list is given, download the files
    if csvFile is not None:
        file_subroutines.prepare_files(csvFile)
  
    (filenames,filedates) = file_subroutines.get_file_list()
    
    print filenames
    print filedates

    # If no DEM is given, determine one from first file
    if dem is None:
        dem = getDemFileGamma(filenames,use_opentopo,rlooks)

    length=len(filenames)

    # Make directory and link files for pairs and 2nd pairs
    for x in xrange(length-2):
        makeDirAndLinks(filedates[x],filedates[x+1],filenames[x],filenames[x+1],dem)
        makeDirAndLinks(filedates[x],filedates[x+2],filenames[x],filenames[x+2],dem)

    # If we have anything to process
    if (length > 1) :
        # Make directory and link files for last pair
        makeDirAndLinks(filedates[length-2],filedates[length-1],filenames[length-2],filenames[length-1],dem)

        # Run through directories processing ifgs as we go
        for mydir in os.listdir("."):
            if len(mydir) == 17 and os.path.isdir(mydir) and "_20" in mydir:
                print "Processing directory %s" % mydir
                gammaProcess(mydir,dem,alooks,rlooks)

    # Clip results to same bounding box
    if (length > 2):
        prepGamma()


###########################################################################

if __name__ == '__main__':

  parser = argparse.ArgumentParser(prog='procS1StackGAMMA',
    description='Process a stack of Sentinel-1 data into interferograms using GAMMA software')
  parser.add_argument("-f","--file",help="Read image names from CSV file, otherwise will automatically process all SAFE files in your current directory")
  parser.add_argument("-d","--dem",help="Input DEM file to use, otherwise will calculate a bounding box and use get_dem")
  parser.add_argument("-o",action="store_true",help="Use opentopo to get the DEM file instead of get_dem")
  parser.add_argument("-r","--rlooks",default=4,help="Number of range looks (def=4)")
  parser.add_argument("-a","--alooks",default=20,help="Number of azimuth looks (def=20)")
  args = parser.parse_args()

  procS1StackGAMMA(alooks=args.alooks,rlooks=args.rlooks,csvFile=args.file,dem=args.dem,use_opentopo=args.o)

