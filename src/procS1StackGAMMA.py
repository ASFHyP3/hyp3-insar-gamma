#!/usr/bin/env python
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
###############################################################################
# procS1StackGAMMA.py 
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
import logging
import sys
import os
from lxml import etree
import re
import math
import zipfile
import argparse
import commands
import glob
import shutil
from getSubSwath import get_bounding_box_file
from ifm_sentinel import gammaProcess
from execute import execute
from osgeo import gdal
from utm2dem import utm2dem
from getDemFor import getDemFile
from apply_wb_mask import apply_wb_mask
import file_subroutines
import saa_func_lib as saa

#####################
#
# Define procedures
#
#####################

def getDemFileGamma(filenames,use_opentopo,alooks,mask):

    if not mask:
        # Make the UTM dem directly
        demfile,demtype = getDemFile(filenames[0],"tmpdem.tif",opentopoFlag=use_opentopo,utmFlag=True)
    else:
        # Make a DEM
	print "Calling getDemFile"
        print "Getting corners for {}".format(filenames[0])
	
        ymax,ymin,xmax,xmin = get_bounding_box_file(filenames[0])
        logging.info("Using corners coordinates: {} {} {} {}".format(xmin,xmax,ymin,ymax))	

        if (xmax >= 177 and xmin <= -177):
            logging.info("Using anti-meridian special code")
        
            demfile,demtype = getDemFile(filenames[0],"tmpdem.tif",opentopoFlag=use_opentopo,utmFlag=True)
            tmpdem = "temp_mask_dem_{}.tif".format(os.getpid())

            # Apply the water body mask
            logging.debug("Applying water body mask")
            apply_wb_mask(demfile,tmpdem,maskval=-32767,gcs=False)
            logging.debug("Done with water body mask")
            shutil.move(tmpdem,demfile)

        else:
            demfile,demtype = getDemFile(filenames[0],"tmpdem.tif",opentopoFlag=use_opentopo)
            tmpdem = "temp_mask_dem_{}.tif".format(os.getpid())

            # Apply the water body mask
            apply_wb_mask(demfile,tmpdem,maskval=-32767,gcs=True)
     
            # Reproject DEM file into UTM coordinates
	    pixsize = 30.0
            if demtype == "SRTMGL3":
                pixsize = 90.
            if demtype == "NED2":
                pixsize = 60.

            saa.reproject_gcs_to_utm(tmpdem,demfile,pixsize)
     

    # If we downsized the SAR image, downsize the DEM file
    # if alks == 1, then the SAR image is roughly 20 m square -> use native dem res
    # if alks == 2, then the SAR image is roughly 40 m square -> set dem to 80 meters
    # if alks == 3, then the SAR image is roughly 60 m square -> set dem to 120 meters 
    # etc.
    #
    # The DEM is set to double the res because it will be 1/2'd by the procedure
    # I.E. if you give a 100 meter DEM as input, the output Igram is 50 meters

    pix_size = 20 * int(alooks) * 2;
    logging.debug("Changing resolution")
    gdal.Warp("tmpdem2.tif",demfile,xRes=pix_size,yRes=pix_size,resampleAlg="cubic",dstNodata=-32767,creationOptions=['COMPRESS=LZW'])
    os.remove(demfile)

    if use_opentopo == True:
      utm2dem("tmpdem2.tif","big.dem","big.par",dataType="int16")
    else:
      utm2dem("tmpdem2.tif","big.dem","big.par")
    return("big",demtype)

def makeDirAndLinks(name1,name2,file1,file2,dem):
    dirname = '%s_%s' % (name1,name2)
    if not os.path.exists(dirname):
        os.mkdir(dirname)
    os.chdir(dirname)
    if not os.path.exists(file1):
        os.symlink("../%s" % file1,"%s" % file1)
    if not os.path.exists(file2):
        os.symlink("../%s" % file2,"%s" % file2)
    if not os.path.exists("%s.dem" % dem):
        os.symlink("../%s.dem" % dem,"%s.dem" % dem)
    if not os.path.exists("%s.par" % dem):
        os.symlink("../%s.par" % dem,"%s.par" % dem)
    os.chdir('..')

def makeParameterFile(mydir,alooks,rlooks,dem_source):
    res = 20 * int(alooks)        
    
    master_date = mydir[:15]
    slave_date = mydir[17:]
   
    logging.info("In directory {} looking for file with date {}".format(os.getcwd(),master_date)) 
    master_file = glob.glob("*%s*.SAFE" % master_date)[0]
    slave_file = glob.glob("*%s*.SAFE" % slave_date)[0]

    f = open("IFM/baseline.log","r")
    for line in f:
        if "estimated baseline perpendicular component" in line:
            t = re.split(":",line)
            s = re.split("\s+",t[1])
            baseline = float(s[1])
    f.close

    back = os.getcwd()
    os.chdir(os.path.join(master_file,"annotation"))
    for myfile in os.listdir("."):
        if "001.xml" in myfile:
            root = etree.parse(myfile)
            for coord in root.iter('productFirstLineUtcTime'):
                utc = coord.text
                logging.info("Found utc time {}".format(utc))
    t = utc.split("T")
    logging.info("{}".format(t))
    s = t[1].split(":")
    logging.info("{}".format(s))
    utctime = ((int(s[0])*60+int(s[1]))*60)+float(s[2])
    os.chdir(back) 
 
    name = "IFM/" + master_date[:8] + ".mli.par"
    f = open(name,"r")
    for line in f:
        if "heading" in line:
            t = re.split(":",line)
            s = re.split("\s+",t[1])
            heading = float(s[1])
    f.close
    
    master_file = master_file.replace(".SAFE","")
    slave_file = slave_file.replace(".SAFE","")

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
    f.write('DEM source: %s\n' % dem_source)
    f.write('DEM resolution (m): %s\n' % (res*2))
    f.write('Unwrapping type: mcf\n')
    f.write('Unwrapping threshold: none\n')
    f.write('Speckle filtering: off\n')
    f.close()
    os.chdir("..")  
    

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
def procS1StackGAMMA(alooks=4,rlooks=20,csvFile=None,dem=None,use_opentopo=None,
                     inc_flag=None,look_flag=None,los_flag=None,proc_all=None,
                     time=None,mask=False):

    # If file list is given, download the files
    if csvFile is not None:
        file_subroutines.prepare_files(csvFile)
  
    (filenames,filedates) = file_subroutines.get_file_list()
    
    logging.info("{}".format(filenames))
    logging.info("{}".format(filedates))

    # If no DEM is given, determine one from first file
    if dem is None:
        dem, dem_source = getDemFileGamma(filenames,use_opentopo,alooks,mask)
    else: 
        dem_source = "UNKNOWN"

    length=len(filenames)

    if not proc_all:
         # Make directory and link files for pairs and 2nd pairs
         for x in xrange(length-2):
             makeDirAndLinks(filedates[x],filedates[x+1],filenames[x],filenames[x+1],dem)
             makeDirAndLinks(filedates[x],filedates[x+2],filenames[x],filenames[x+2],dem)
    else:
         # Make directory and link files for ALL possible pairs
         for i in xrange(length):
             for j in xrange(i+1,length):
                 makeDirAndLinks(filedates[i],filedates[j],filenames[i],filenames[j],dem)
            
    # If we have anything to process
    if (length > 1) :
        if not proc_all:
            # Make directory and link files for last pair
            makeDirAndLinks(filedates[length-2],filedates[length-1],filenames[length-2],filenames[length-1],dem)

        # Run through directories processing ifgs as we go
        if not os.path.exists("PRODUCTS"):
            os.mkdir("PRODUCTS")
        first = 1
	dirs = os.listdir(".")
	dirs.sort
        for mydir in dirs:
            if len(mydir) == 31 and os.path.isdir(mydir) and "_20" in mydir:
                logging.info("Processing directory %s" % mydir)
                os.chdir(mydir)
                master = mydir.split("_")[0]
                slave = mydir.split("_")[1]
                for myfile in glob.glob("*.SAFE"):
                    if master in myfile: 
                        masterFile = myfile
                    if slave in myfile:
                        slaveFile = myfile
                gammaProcess(masterFile,slaveFile,"IFM",dem=dem,rlooks=rlooks,alooks=alooks,
                  inc_flag=inc_flag,look_flag=look_flag,los_flag=los_flag,time=time)
                makeParameterFile(mydir,alooks,rlooks,dem_source)
                os.chdir("..")
                for myfile in glob.glob("{}/PRODUCT/*".format(mydir)):
                    shutil.move(myfile,"PRODUCTS/{}".format(os.path.basename(myfile)))
                if not first:
                    shutil.rmtree(mydir,ignore_errors=True)
                first = 0

###########################################################################

if __name__ == '__main__':

  parser = argparse.ArgumentParser(prog='procS1StackGAMMA',
    description='Process a stack of Sentinel-1 data into interferograms using GAMMA software')
  parser.add_argument("-f","--file",help="Read image names from CSV file, otherwise will automatically process all SAFE files in your current directory")
  parser.add_argument("-d","--dem",help="Input DEM file to use, otherwise will calculate a bounding box and use get_dem")
  parser.add_argument("-i",action="store_true",help="Create incidence angle file")
  parser.add_argument("-l",action="store_true",help="Create look vector theta and phi files")
  parser.add_argument("-s",action="store_true",help="Create line of sight displacement file")
  parser.add_argument("-o",action="store_true",help="Use opentopo to get the DEM file instead of get_dem")
  parser.add_argument("-r","--rlooks",default=20,help="Number of range looks (def=20)")
  parser.add_argument("-a","--alooks",default=4,help="Number of azimuth looks (def=4)")
  parser.add_argument("-p",action="store_true",help="Process ALL possible pairs")
  parser.add_argument("-t",nargs=4,metavar=("t1","t2","t3","length"),help="Start times and number of selected bursts to process")
  parser.add_argument("-m","--mask",action="store_true",help="Apply water body mask to DEM file prior to processing")
  args = parser.parse_args()

  logFile = "procS1StackGAMMA_{}_log.txt".format(os.getpid())
  logging.basicConfig(filename=logFile,format='%(asctime)s - %(levelname)s - %(message)s',
                        datefmt='%m/%d/%Y %I:%M:%S %p',level=logging.DEBUG)
  logging.getLogger().addHandler(logging.StreamHandler())
  logging.info("Starting run")

  procS1StackGAMMA(alooks=args.alooks,rlooks=args.rlooks,csvFile=args.file,dem=args.dem,use_opentopo=args.o,
                   inc_flag=args.i,look_flag=args.l,los_flag=args.s,proc_all=args.p,time=args.t,mask=args.mask)

