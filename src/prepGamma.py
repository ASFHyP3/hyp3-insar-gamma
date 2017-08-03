#!/usr/bin/env python
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4
###############################################################################
# prepGamma.py
#
# Project:   
# Purpose:  Cut all gamma files to same size and corner coordinates
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
import re

#####################
#
# Define procedures
#
#####################
def get_projection():
    for mydir in os.listdir("."):
        if len(mydir)==17 and os.path.isdir(mydir):
            os.chdir(mydir)
            g = open('IFM.log')
            for line in g.readlines():
                if "projection:" in line and "GEOGCS" in line:
                    t = re.split(':',line)
                    proj = t[1]
                    break 
    os.chdir("..")
    return proj

def read_file_list(name,north,east,width,nlines,south,west,posting):
    x = 0
    for mydir in os.listdir("."):
        if len(mydir)==17 and os.path.isdir(mydir):
            name.append(mydir)
            os.chdir("%s/IFM/DEM" % mydir)
            g = open('demseg.par','r')
            for line in g.readlines():
                if "width:" in line:
                    t = re.split(':',line)
                    w = t[1].split()
                    width.append(int(w[0]))
                elif "nlines:" in line:
                    t = re.split(':',line)
                    l = t[1].split()
                    nlines.append(int(l[0]))
                elif "corner_north:" in line:
                    t = re.split(':',line)
                    n = t[1].split()
                    north.append(float(n[0]))
                elif "corner_east:" in line:
                    t = re.split(':',line)
                    e = t[1].split()
                    east.append(float(e[0]))
                elif "post_north:" in line:
                    t = re.split(':',line)
                    p = t[1].split()
                    posting.append(float(p[0]))
                  
            g.close() 
            s = north[x] + (posting[x] * nlines[x])
            south.append(s)
            w = east[x] - (posting[x] * width[x])
            west.append(w)
            os.chdir("../../..")
            x = x + 1


def get_bounding_box_utm(north,east,south,west,posting):
    length = len(north)
    min_north = 10000000
    max_south = -10000000
    max_east = -10000000
    min_west = 10000000
    for x in xrange(length):
        min_north = min(min_north,north[x])
        max_south = max(max_south,south[x])
        min_west = min(min_west,west[x])
        max_east = max(max_east,east[x])
    width = -1.0 * (min_west - max_east) / posting[x]
    length = -1.0 * (min_north - max_south) / posting[x]
    northing = min_north
    easting = max_east
    return width, length, northing, easting

def cut_image_to_box(name,north,east,width,nlines,w,l,n,e,post):
    first_line = int((n-north)/post)
    first_samp = int((east-e)/post)
    cnt = 0
    print "Clipping image %s from line %s to %s and samples %s to %s" % (name,first_line,l+first_line,first_samp,w+first_samp)
    read_size = width * 4
    hi = int(w+first_samp) * 4
    lo = int(first_samp) * 4

    filename = "%s/IFM/%s.adf.unw.geo" % (name,name)
    filename2 = "%s/IFM/%s.adf.unw.geo.clip" % (name,name)
    g = open(filename2,'wb')
    with open(filename,"rb") as f:
        for x in xrange(nlines):
            data = f.read(read_size)
            data2 = data[lo:hi]
            if (x >= first_line and x < l+first_line):
                g.write(data2)
    f.close()
    g.close()

    filename = "%s/IFM/%s.adf.cc.geo" % (name,name)
    filename2 = "%s/IFM/%s.adf.cc.geo.clip" % (name,name)
    g = open(filename2,'wb')
    with open(filename,"rb") as f:
        for x in xrange(nlines):
            data = f.read(read_size)
            data2 = data[lo:hi]
            if (x >= first_line and x < l+first_line):
                g.write(data2)
    f.close()
    g.close()

def prepGamma():

    name = []
    north = []
    east = []
    width = []
    nlines = []
    south = []
    west = []
    posting = []
    zone = []
    northing = []

    read_file_list(name,north,east,width,nlines,south,west,posting)

    (w,l,n,e)= get_bounding_box_utm(north,east,south,west,posting)

    length = len(name)
    for x in xrange(length):
        cut_image_to_box(name[x],north[x],east[x],width[x],nlines[x],w,l,n,e,posting[x])

    proj = get_projection()

    f = open("file_sizes.txt","w")
    line = "width: %s\n" % int(w)
    f.write(line)
    line = "nlines: %s\n" % int(l)
    f.write(line)
    line = "northing: %s\n" % n
    f.write(line)
    line = "easting: %s\n" % e
    f.write(line)
    line = "posting: %s\n" % posting[0]
    f.write(line)
    line = "projection: %s\n" % proj
    f.write(line)
    f.close()

#####################
#
# Main Program
#
#####################

if __name__ == "__main__":

    prepGamma()
    
   
