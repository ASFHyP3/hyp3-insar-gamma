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
import commands
import glob
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
    os.chdir(mydir)
    burst_tab1 = "%s_burst_tab" % master
    f1 = open(burst_tab1,"w")
    burst_tab2 = "%s_burst_tab" % slave
    f2 = open(burst_tab2,"w")    
    for name in ['001.xml','002.xml','003.xml']:
        time1 = []
        time2 = []
        for myfile in os.listdir("."):
            if ".SAFE" in myfile and master in myfile:
                os.chdir(myfile)
                os.chdir("annotation")
                for myfile2 in os.listdir("."):
                    if name in myfile2:
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
                    if name in myfile2:
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
            if (abs(x-y) < 0.20):
                print "Found burst match at 1 %s" % cnt
                found = 1
                start1 = 1
                start2 = cnt
            cnt += 1

        if found == 0:
            y = time2[0]
            cnt = 1
            for x in time1:
                if (abs(x-y) < 0.20):
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
        
        f1.write("%s %s\n" % (start1, start1+size-1))
        f2.write("%s %s\n" % (start2, start2+size-1))
        
    f1.close()
    f2.close()
    return(burst_tab1,burst_tab2)

def gammaProcess(mydir,dem,alooks,rlooks,inc_flag):
    cmd = 'cd %s; ' % mydir 
    (burst_tab1,burst_tab2) = getBurstOverlaps(mydir)
    if inc_flag:
        cmd = cmd + 'ifm_sentinel.pl -i -d=%s IFM %s %s %s %s ' % (dem,alooks,rlooks,burst_tab1,burst_tab2)
    else:
        cmd = cmd + 'ifm_sentinel.pl -d=%s IFM %s %s %s %s ' % (dem,alooks,rlooks,burst_tab1,burst_tab2)
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

def makeParameterFile(mydir,alooks,rlooks):
    res = 20 * int(rlooks)        
    
    if os.path.isdir("DEM"):
        string = commands.getstatusoutput('gdalinfo %s' % glob.glob("DEM/*.tif")[0])
        lst = string[1].split("\n")
        for item in lst:
            if "GEOGCS" in item:
                if "WGS 84" in item:
                    demtype = 'SRTMGL'
                else:
                    demtype = 'NED'
        for item in lst:
            if "Pixel Size" in item:
                if demtype == 'SRTMGL':
                    if "0.000277777777780" in item:
                        number = '1'
                    else:
                        number = '3'
                else:
                    if "0.000092592592" in item:
                        number = '13'
                    elif "0.00027777777" in item:
                        number = '1'
                    else:
                        number = '2'
        demtype = demtype + number
    else:
        demtype = "Unknown"

    os.chdir("%s" % mydir)
    master_date = mydir[:15]
    slave_date = mydir[17:]
    
    master_file = glob.glob("*%s*.SAFE" % master_date)[0]
    slave_file = glob.glob("*%s*.SAFE" % slave_date)[0]
    master_file = master_file.replace(".SAFE","")
    slave_file = slave_file.replace(".SAFE","")

    f = open("IFM/baseline.log","r")
    for line in f:
        if "estimated baseline perpendicular component" in line:
            t = re.split(":",line)
            s = re.split("\s+",t[1])
            baseline = float(s[1])
    f.close
    
    f = open("IFM.log","r")
    for line in f:
        if "SLC image first line UTC time stamp" in line:
            t = re.split(":",line)
            utctime = float(t[2])
    f.close
    
    name = "IFM/" + master_date[:8] + ".mli.par"
    f = open(name,"r")
    for line in f:
        if "heading" in line:
            t = re.split(":",line)
            s = re.split("\s+",t[1])
            heading = float(s[1])
    f.close
    
    os.chdir("PRODUCT")
    name = "%s.txt" % mydir
    f = open(name,'w')
    f.write('Master Granule: %s\n' % master_file)
    f.write('Slave Granule: %s\n' % slave_file)
    f.write('Baseline: %s\n' % baseline)
    f.write('UTCtime: %s\n' % utctime)
    f.write('Heading: %s\n' % heading)
    f.write('Range looks: %s\n' % rlooks)
    f.write('Azimuth looks: %s\n' % alooks)
    f.write('INSAR phase filter:  adf\n')
    f.write('Phase filter parameter: 0.6\n')
    f.write('Resolution of output (m): %s\n' % res)
    f.write('Range bandpass filter: no\n')
    f.write('Azimuth bandpass filter: no\n')
    f.write('DEM source: %s\n' % demtype)
    f.write('DEM resolution (m): %s\n' % (res*2))
    f.write('Unwrapping type: mcf\n')
    f.write('Unwrapping threshold: none\n')
    f.write('Speckle filtering: off\n')
    f.close()
    os.chdir("../..")  
    

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
def procS1StackGAMMA(alooks=20,rlooks=4,csvFile=None,dem=None,use_opentopo=None,inc_flag=None):

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
            if len(mydir) == 31 and os.path.isdir(mydir) and "_20" in mydir:
                print "Processing directory %s" % mydir
                gammaProcess(mydir,dem,alooks,rlooks,inc_flag)
                makeParameterFile(mydir,alooks,rlooks)

    # Clip results to same bounding box
    if (length > 2):
        prepGamma()


###########################################################################

if __name__ == '__main__':

  parser = argparse.ArgumentParser(prog='procS1StackGAMMA',
    description='Process a stack of Sentinel-1 data into interferograms using GAMMA software')
  parser.add_argument("-f","--file",help="Read image names from CSV file, otherwise will automatically process all SAFE files in your current directory")
  parser.add_argument("-d","--dem",help="Input DEM file to use, otherwise will calculate a bounding box and use get_dem")
  parser.add_argument("-i",action="store_true",help="Create incidence angle file")
  parser.add_argument("-o",action="store_true",help="Use opentopo to get the DEM file instead of get_dem")
  parser.add_argument("-r","--rlooks",default=4,help="Number of range looks (def=4)")
  parser.add_argument("-a","--alooks",default=20,help="Number of azimuth looks (def=20)")
  args = parser.parse_args()

  procS1StackGAMMA(alooks=args.alooks,rlooks=args.rlooks,csvFile=args.file,dem=args.dem,use_opentopo=args.o,inc_flag=args.i)

