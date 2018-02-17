#!/bin/bash -fe
# MOD Feb 20 2016, unwarp adf-ifg, geocode adf-ifg


if [ "$#" -le 3 ]
then
    echo " "
    echo "$0: For the Sentinel-1 SLC interferogram for unwrapping (mcf) and geocoding"
    echo "                                                                       01/2016 W.G"
    echo " "
    echo "usage: $0 <pass1> <pass2> [step] [rlks] [azlks] [tri_mode] [npatr] [npatraz]"
    echo "       1.pass1       pass 1 identifier (example: pass number) reference"
    echo "       2.pass2       pass 2 identifier (example: pass number)"
    echo "       3.step        level of interferograms for unwrapping and geocoding"
    echo "                   e.g., 'it1' for result with 1 iteration;"
    echo "                          'man' for from spectral diversity  "
    echo "       4.rlks        number of range looks (default=10)"
    echo "       5.azlks       number of azimuth looks (default=2)"
    echo "       6.tri_mode    triangulation mode for mcf unwrapper "
    echo "                   0. filled triangular mesh (default)"
    echo "                   1. Delaunay triangulation "
    echo "       7.npatr       number of patches in range (default 1)"
    echo "       8.npataz      number of patches in azimuth (default 1) "
    echo "   Note1 : Run this in the IFG processing folder, where interferograms and DEM folder are"
    echo "   Note2   adf filter alpha value is 0.6"
    echo "   Note3 : It will unwrap everywhere"
    echo "Example: "
    echo "$0 20150417 20150429 it3 10 2 0 1 1 "
    echo "/center/w/gong/Kenny/scripts/Unwrapping_Geocoding_S1.sh 20150830 20150923 it2 10 2 0 1 1"
    echo ""
    exit
fi

rlks=10
azlks=2
tri=0
npatr=1
npataz=1
alpha=0.6

if [ "$#" -ge 4 ]; then
        rlks=$4
fi

if [ "$#" -ge 5 ]; then
        azlks=$5
fi

if [ "$#" -ge 6 ]; then
        tri=$6
fi

if [ "$#" -ge 7 ]; then
       npatr=$7
fi

if [ "$#" -ge 8 ]; then
      npataz=$8
fi


mname=$1   #20141015
sname=$2 #20141003
step=$3  # e.g., man

wrk=`pwd`

dem=./DEM/demseg
demfile=./DEM/demseg.par  #./DEM/HGT_SAR_10_2
newseg=./DEM/new_seg.par
lt=./DEM/MAP2RDC
ifgname=${mname}_${sname} #.diff0.it #20141003_20141015

if [ ! -e $demfile ]
then
    echo " $demfile is not exist, please double check"
    exit
fi

if [ ! -e $lt ]
then
    echo " $lt is not exist, please double check"
    exit
fi

if [ ! -e ${ifgname}.off.it ]
then
   echo " ${ifgname}.off.it is not exist, please double check"
   exit
fi


width=`grep interferogram_width:  ${ifgname}.off.it  | awk '{print $2}'`
nline=`grep interferogram_azimuth_lines:  ${ifgname}.off.it  | awk '{print $2}'`
demw=`grep width:  $demfile | awk '{print $2}'`
demn=`grep nlines: $demfile | awk '{print $2}'` 

ifgf=${ifgname}.diff0.${step} # e.g., 20151009_20151102.diff0.man 20151009_20151102.diff0.it3
echo "$ifgf will be use for unwrapping and geocoding"
echo " " 

echo "-------------------------------------------------"
echo "            Start unwrapping"
echo "------------------------------------------------ "

echo "adf $ifgf $ifgf.adf ${ifgname}.adf.cc $width $alpha - 5"
adf ${ifgf} ${ifgf}.adf ${ifgname}.adf.cc $width $alpha - 5 

echo "rasmph_pwr ${ifgf}.adf ${mname}.mli $width"
rasmph_pwr ${ifgf}.adf $mname.mli $width

echo "rascc ${ifgname}.adf.cc $mname.mli  $width 1 1 0 1 1 .1 .9 - - - ${ifgname}.adf.cc.ras"
rascc ${ifgname}.adf.cc $mname.mli  $width 1 1 0 1 1 .1 .9 - - - ${ifgname}.adf.cc.ras

echo "rascc_mask ${ifgname}.adf.cc $mname.mli $width 1 1 0 1 1 0.05"
rascc_mask ${ifgname}.adf.cc $mname.mli $width 1 1 0 1 1 0.05

# echo "mcf ${ifgf}.adf ${ifgname}.adf.cc ${ifgname}.adf.cc_mask.bmp ${ifgname}.adf.unw $width $tri 0 0 - - $npatr $npataz"
# mcf ${ifgf}.adf ${ifgname}.adf.cc ${ifgname}.adf.cc_mask.bmp ${ifgname}.adf.unw $width $tri 0 0 - - $npatr $npataz  

echo "mcf ${ifgf}.adf ${ifgname}.adf.cc - ${ifgname}.adf.unw $width $tri 0 0 - - $npatr $npataz"
mcf ${ifgf}.adf ${ifgname}.adf.cc - ${ifgname}.adf.unw $width $tri 0 0 - - $npatr $npataz  

echo "rasrmg ${ifgname}.adf.unw $mname.mli $width"
rasrmg ${ifgname}.adf.unw $mname.mli $width 1 1 0 1 1 0.33333 1.0 .35 0.0 - ${ifgname}.adf.unw.ras

echo "dispmap ${ifgname}.adf.unw DEM/HGT_SAR_${rlks}_${azlks} ${mname}.mli.par - ${ifgname}.vert.disp 1"
dispmap ${ifgname}.adf.unw DEM/HGT_SAR_${rlks}_${azlks} ${mname}.mli.par - ${ifgname}.vert.disp 1

echo "rashgt ${ifgname}.vert.disp - $width 1 1 0 1 1 0.028"
rashgt ${ifgname}.vert.disp - $width 1 1 0 1 1 0.028

#echo "rashgt ${ifgname}.vert.disp ${mname}.mli $width 1 1 0 1 1 0.01"
#rashgt ${ifgname}.vert.disp ${mname}.mli $width 1 1 0 1 1 0.01

echo "dispmap ${ifgname}.adf.unw DEM/HGT_SAR_${rlks}_${azlks} ${mname}.mli.par - ${ifgname}.los.disp 0"
dispmap ${ifgname}.adf.unw DEM/HGT_SAR_${rlks}_${azlks} ${mname}.mli.par - ${ifgname}.los.disp 0

echo "rashgt ${ifgname}.los.disp - $width 1 1 0 1 1 0.028"
rashgt ${ifgname}.los.disp - $width 1 1 0 1 1 0.028


echo "-------------------------------------------------"
echo "             Unwrapping done"
echo "-------------------------------------------------"

echo "-------------------------------------------------"
echo "            Start geocoding"
echo "------------------------------------------------ "

echo "geocode_back $mname.mli $width $lt $mname.mli.geo $demw $demn 0 0"
geocode_back $mname.mli $width $lt $mname.mli.geo $demw $demn 0 0 

echo "data2geotiff $demfile $mname.mli.geo 2 $mname.mli.geo.tif"
data2geotiff $demfile $mname.mli.geo 2 $mname.mli.geo.tif 

echo "geocode_back $sname.mli $width $lt $sname.mli.geo $demw $demn 0 0"
geocode_back $sname.mli $width $lt $sname.mli.geo $demw $demn 0 0 

echo "data2geotiff $demfile $sname.mli.geo 2 $sname.mli.geo.tif"
data2geotiff $demfile $sname.mli.geo 2 $sname.mli.geo.tif 

echo "geocode_back ${ifgname}.sim_unw $width $lt ${ifgname}.sim_unw.geo $demw $demn 0 0"
geocode_back ${ifgname}.sim_unw $width $lt ${ifgname}.sim_unw.geo $demw $demn 0 0

echo "data2geotiff $demfile ${ifgname}.sim_unw.geo 2 ${ifgname}.sim_unw.geo.tif"
data2geotiff $demfile ${ifgname}.sim_unw.geo 2 ${ifgname}.sim_unw.geo.tif

echo "geocode_back ${ifgname}.adf.unw $width $lt ${ifgname}.adf.unw.geo $demw $demn 0 0"
geocode_back ${ifgname}.adf.unw $width $lt ${ifgname}.adf.unw.geo $demw $demn 0 0

echo "data2geotiff $demfile  ${ifgname}.adf.unw.geo  2 ${ifgname}.adf.unw.geo.tif"
data2geotiff $demfile  ${ifgname}.adf.unw.geo  2 ${ifgname}.adf.unw.geo.tif 

echo "geocode_back ${ifgf}.adf $width $lt ${ifgf}.adf.geo $demw $demn 0  1"
geocode_back ${ifgf}.adf $width $lt ${ifgf}.adf.geo $demw $demn 0  1 

echo "geocode_back ${ifgname}.adf.unw.ras $width $lt ${ifgname}.adf.unw.geo.bmp $demw $demn 0 2"
geocode_back ${ifgname}.adf.unw.ras $width $lt ${ifgname}.adf.unw.geo.bmp $demw $demn 0 2 

echo "data2geotiff $demfile ${ifgname}.adf.unw.geo.bmp 0 ${ifgname}.adf.unw.geo.bmp.tif"
data2geotiff $demfile ${ifgname}.adf.unw.geo.bmp 0 ${ifgname}.adf.unw.geo.bmp.tif  

echo "geocode_back ${ifgf}.adf.bmp $width $lt ${ifgf}.adf.bmp.geo $demw $demn 0 2"
geocode_back ${ifgf}.adf.bmp $width $lt ${ifgf}.adf.bmp.geo $demw $demn 0 2

echo "data2geotiff $demfile ${ifgf}.adf.bmp.geo 0 ${ifgf}.adf.bmp.geo.tif"
data2geotiff $demfile ${ifgf}.adf.bmp.geo 0 ${ifgf}.adf.bmp.geo.tif

echo "geocode_back ${ifgname}.adf.cc $width $lt ${ifgname}.adf.cc.geo $demw $demn 0 0"
geocode_back ${ifgname}.adf.cc $width $lt ${ifgname}.adf.cc.geo $demw $demn 0 0

echo "data2geotiff $demfile ${ifgname}.adf.cc.geo 2 ${ifgname}.adf.cc.geo.tif"
data2geotiff $demfile ${ifgname}.adf.cc.geo 2 ${ifgname}.adf.cc.geo.tif

echo "data2geotiff $demfile DEM/demseg 2 ${ifgname}.dem.tif"
data2geotiff $demfile DEM/demseg 2 ${ifgname}.dem.tif

echo "geocode_back ${ifgname}.vert.disp.bmp $width $lt ${ifgname}.vert.disp.bmp.geo $demw $demn 0 2"
geocode_back ${ifgname}.vert.disp.bmp $width $lt ${ifgname}.vert.disp.bmp.geo $demw $demn 0 2

echo "data2geotiff $demfile ${ifgname}.vert.disp.bmp.geo 0 ${ifgname}.vert.disp.geo.tif"
data2geotiff $demfile ${ifgname}.vert.disp.bmp.geo 0 ${ifgname}.vert.disp.geo.tif

echo "geocode_back ${ifgname}.vert.disp $width $lt ${ifgname}.vert.disp.geo $demw $demn 0 0"
geocode_back ${ifgname}.vert.disp $width $lt ${ifgname}.vert.disp.geo $demw $demn 0 0

echo "data2geotiff $demfile ${ifgname}.vert.disp.geo 2 ${ifgname}.vert.disp.geo.org.tif"
data2geotiff $demfile ${ifgname}.vert.disp.geo 2 ${ifgname}.vert.disp.geo.org.tif

echo "geocode_back ${ifgname}.los.disp.bmp $width $lt ${ifgname}.los.disp.bmp.geo $demw $demn 0 2"
geocode_back ${ifgname}.los.disp.bmp $width $lt ${ifgname}.los.disp.bmp.geo $demw $demn 0 2

echo "data2geotiff $demfile ${ifgname}.los.disp.bmp.geo 0 ${ifgname}.los.disp.geo.tif"
data2geotiff $demfile ${ifgname}.los.disp.bmp.geo 0 ${ifgname}.los.disp.geo.tif

echo "geocode_back ${ifgname}.los.disp $width $lt ${ifgname}.los.disp.geo $demw $demn 0 0"
geocode_back ${ifgname}.los.disp $width $lt ${ifgname}.los.disp.geo $demw $demn 0 0

echo "data2geotiff $demfile ${ifgname}.los.disp.geo 2 ${ifgname}.los.disp.geo.org.tif"
data2geotiff $demfile ${ifgname}.los.disp.geo 2 ${ifgname}.los.disp.geo.org.tif

echo "data2geotiff $demfile DEM/inc 2 ${ifgname}.inc.tif"
data2geotiff $demfile DEM/inc_flat 2 ${ifgname}.inc.tif

# generate look vector
look_vector $mname.mli.par ${ifgname}.off.it $demfile $dem lv_theta lv_phi

# echo "geocode_back lv_theta $width $lt ${ifgname}.lv_theta.geo $demw $demn 0 0"
# geocode_back lv_theta $width $lt ${ifgname}.lv_theta.geo $demw $demn 0 0

echo "data2geotiff $demfile lv_theta 2 ${ifgname}.lv_theta.tif"
data2geotiff $demfile lv_theta 2 ${ifgname}.lv_theta.tif

# echo "geocode_back lv_phi $width $lt ${ifgname}.lv_phi.geo $demw $demn 0 0"
# geocode_back lv_phi $width $lt ${ifgname}.lv_phi.geo $demw $demn 0 0

echo "data2geotiff $demfile lv_phi 2 ${ifgname}.lv_phi.tif"
data2geotiff $demfile lv_phi 2 ${ifgname}.lv_phi.tif

proj=`grep DEM_projection:  $demfile | awk '{print $2}'`

if [ $proj == "EQA" ]
then

  echo "------------------------------------------------------------------------"
  echo "producing kml file for unwrapped bmp, so far deal with latlon projection"
  echo "------------------------------------------------------------------------"
  demw2=$(($demw-1))
  demn2=$(($demn-1))

  clat=`grep corner_lat:  $demfile | awk '{print $2}'`
  wlon=`grep corner_lon:  $demfile | awk '{print $2}'`
  plat=`grep post_lat:  $demfile | awk '{print $2}'`
  plon=`grep post_lon:  $demfile | awk '{print $2}'`
  echo $demn2 $demw2 $clat $wlon $plat $plon

  plat2=`echo ${plat} | sed -e 's/[eE]+*/\\*10\\^/'`
  plon2=`echo ${plon} | sed -e 's/[eE]+*/\\*10\\^/'`

  clat2=`echo "$demn2*$plat2+$clat" | bc -l`
  elon=`echo "$wlon+$plon2*$demw2" | bc -l` 

  echo $elon $wlon $plon2 $demw2  
  echo $clat2 
  tempi=`echo $clat'<'$clat2 | bc -l`

  if [ $tempi == 1 ]
  then
    slat=$clat
    nlat=$clat2
  else
    slat=$clat2
    nlat=$clat
  fi


  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > $ifgname.kml
  echo "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\">" >> $ifgname.kml
  echo "<GroundOverlay>" >>$ifgname.kml
  echo "   <name> unwrapped $ifgf </name>" >>$ifgname.kml
  echo "   <Icon>"  >>$ifgname.kml
  echo "      <href>${ifgname}.adf.unw.geo.bmp</href>" >>$ifgname.kml
  echo "      <viewBoundScale>0.75</viewBoundScale>" >>$ifgname.kml
  echo "   </Icon>"   >>$ifgname.kml
  echo "   <LatLonBox>"  >>$ifgname.kml
  echo "      <north>$nlat</north>" >>$ifgname.kml
  echo "      <south>$slat</south>" >>$ifgname.kml
  echo "      <east>$elon</east>" >>$ifgname.kml
  echo "      <west>$wlon</west>" >>$ifgname.kml
  echo "   </LatLonBox>" >>$ifgname.kml
  echo "</GroundOverlay>" >>$ifgname.kml
  echo "</kml>" >>$ifgname.kml
fi


echo "-------------------------------------------------"
echo "               Geocoding done"
echo "-------------------------------------------------"


