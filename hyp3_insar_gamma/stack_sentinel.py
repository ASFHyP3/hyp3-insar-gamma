"""Process a stack of Sentinel-1 data into interferograms using GAMMA software"""

import argparse
import glob
import logging
import os
import re
import shutil

from hyp3lib import file_subroutines
from lxml import etree

from hyp3_insar_gamma.getDemFileGamma import getDemFileGamma
from hyp3_insar_gamma.ifm_sentinel import gammaProcess


def makeDirAndLinks(name1, name2, file1, file2, dem):
    dirname = '%s_%s' % (name1, name2)
    if not os.path.exists(dirname):
        os.mkdir(dirname)
    os.chdir(dirname)
    if not os.path.exists(file1):
        os.symlink("../%s" % file1, "%s" % file1)
    if not os.path.exists(file2):
        os.symlink("../%s" % file2, "%s" % file2)
    if not os.path.exists("%s.dem" % dem):
        os.symlink("../%s.dem" % dem, "%s.dem" % dem)
    if not os.path.exists("%s.par" % dem):
        os.symlink("../%s.par" % dem, "%s.par" % dem)
    os.chdir('..')


def makeParameterFile(mydir, alooks, rlooks, dem_source):
    res = 20 * int(alooks)

    master_date = mydir[:15]
    slave_date = mydir[17:]

    logging.info("In directory {} looking for file with date {}".format(os.getcwd(), master_date))
    master_file = glob.glob("*%s*.SAFE" % master_date)[0]
    slave_file = glob.glob("*%s*.SAFE" % slave_date)[0]

    with open("IFM/baseline.log", "r") as f:
        for line in f:
            if "estimated baseline perpendicular component" in line:
                # FIXME: RE is overly complicated here. this is two simple string splits
                t = re.split(":", line)
                s = re.split(r'\s+', t[1])
                baseline = float(s[1])

    back = os.getcwd()
    os.chdir(os.path.join(master_file, "annotation"))

    utctime = None
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
                utctime = ((int(s[0]) * 60 + int(s[1])) * 60) + float(s[2])
    os.chdir(back)

    heading = None
    name = "IFM/" + master_date[:8] + ".mli.par"
    with open(name, "r") as f:
        for line in f:
            if "heading" in line:
                t = re.split(":", line)
                # FIXME: RE is overly complicated here. this is two simple string splits
                s = re.split(r'\s+', t[1])
                heading = float(s[1])

    master_file = master_file.replace(".SAFE", "")
    slave_file = slave_file.replace(".SAFE", "")

    os.chdir("PRODUCT")
    name = "%s.txt" % mydir
    with open(name, 'w') as f:
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
        f.write('DEM resolution (m): %s\n' % (res * 2))
        f.write('Unwrapping type: mcf\n')
        f.write('Unwrapping threshold: none\n')
        f.write('Speckle filtering: off\n')
    os.chdir("..")


def procS1StackGAMMA(alooks=4, rlooks=20, csvFile=None, dem=None, use_opentopo=None,
                     inc_flag=None, look_flag=None, los_flag=None, proc_all=None,
                     time=None, mask=False):
    """
    Args:
        alooks: azimuth looks
        rlooks: range looks
        csvFile: name of CSV file use to for get_asf.py
        dem: name of external DEM file
        use_opentopo: flag for using opentopo instead of get_dem
        inc_flag:
        look_flag:
        los_flag:
        proc_all:
        time:
        mask:
    """
    # If file list is given, download the files
    if csvFile is not None:
        file_subroutines.prepare_files(csvFile)

    (filenames, filedates) = file_subroutines.get_file_list()

    logging.info("{}".format(filenames))
    logging.info("{}".format(filedates))

    # If no DEM is given, determine one from first file
    if dem is None:
        dem, dem_source = getDemFileGamma(filenames[0], use_opentopo, alooks, mask)
    else:
        dem_source = "UNKNOWN"

    length = len(filenames)

    if not proc_all:
        # Make directory and link files for pairs and 2nd pairs
        for x in range(length - 2):
            makeDirAndLinks(filedates[x], filedates[x + 1], filenames[x], filenames[x + 1], dem)
            makeDirAndLinks(filedates[x], filedates[x + 2], filenames[x], filenames[x + 2], dem)
    else:
        # Make directory and link files for ALL possible pairs
        for i in range(length):
            for j in range(i + 1, length):
                makeDirAndLinks(filedates[i], filedates[j], filenames[i], filenames[j], dem)

    # If we have anything to process
    if (length > 1):
        if not proc_all:
            # Make directory and link files for last pair
            makeDirAndLinks(filedates[length - 2], filedates[length - 1], filenames[length - 2], filenames[length - 1],
                            dem)

        # Run through directories processing ifgs as we go
        if not os.path.exists("PRODUCTS"):
            os.mkdir("PRODUCTS")
        first = 1
        dirs = sorted(os.listdir("."))
        for mydir in dirs:
            if len(mydir) == 31 and os.path.isdir(mydir) and "_20" in mydir:

                logging.info("Processing directory %s" % mydir)
                os.chdir(mydir)

                master = mydir.split("_")[0]
                slave = mydir.split("_")[1]

                masterFile = None
                slaveFile = None
                for myfile in glob.glob("*.SAFE"):
                    if master in myfile:
                        masterFile = myfile
                    if slave in myfile:
                        slaveFile = myfile

                gammaProcess(masterFile, slaveFile, "IFM", dem=dem, dem_source=dem_source, rlooks=rlooks,
                             alooks=alooks, inc_flag=inc_flag, look_flag=look_flag, los_flag=los_flag,
                             time=time)

                makeParameterFile(mydir, alooks, rlooks, dem_source)

                os.chdir("..")

                for myfile in glob.glob("{}/PRODUCT/*".format(mydir)):
                    shutil.move(myfile, "PRODUCTS/{}".format(os.path.basename(myfile)))
                if not first:
                    shutil.rmtree(mydir, ignore_errors=True)
                first = 0


def main():
    """Main entrypoint"""
    parser = argparse.ArgumentParser(
        prog='procS1StackGAMMA.py',
        description=__doc__,
    )

    parser.add_argument("-f", "--file",
                        help="Read image names from CSV file, otherwise will automatically process "
                             "all SAFE files in your current directory")
    parser.add_argument("-d", "--dem",
                        help="Input DEM file to use, otherwise will calculate a bounding box and use get_dem")
    parser.add_argument("-i", action="store_true", help="Create incidence angle file")
    parser.add_argument("-l", action="store_true", help="Create look vector theta and phi files")
    parser.add_argument("-s", action="store_true", help="Create line of sight displacement file")
    parser.add_argument("-o", action="store_true", help="Use opentopo to get the DEM file instead of get_dem")
    parser.add_argument("-r", "--rlooks", default=20, help="Number of range looks (def=20)")
    parser.add_argument("-a", "--alooks", default=4, help="Number of azimuth looks (def=4)")
    parser.add_argument("-p", action="store_true", help="Process ALL possible pairs")
    parser.add_argument("-t", nargs=4, metavar=("t1", "t2", "t3", "length"),
                        help="Start times and number of selected bursts to process")
    parser.add_argument("-m", "--mask", action="store_true",
                        help="Apply water body mask to DEM file prior to processing")
    args = parser.parse_args()

    logFile = "procS1StackGAMMA_{}_log.txt".format(os.getpid())
    logging.basicConfig(filename=logFile, format='%(asctime)s - %(levelname)s - %(message)s',
                        datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.INFO)
    logging.getLogger().addHandler(logging.StreamHandler())
    logging.info("Starting run")

    procS1StackGAMMA(
        alooks=args.alooks, rlooks=args.rlooks, csvFile=args.file, dem=args.dem, use_opentopo=args.o,
        inc_flag=args.i, look_flag=args.l, los_flag=args.s, proc_all=args.p, time=args.t, mask=args.mask
    )


if __name__ == "__main__":
    main()