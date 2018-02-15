#! /bin/bash -f
#  This script is preparing S1 data for interferometry processing
#  1. Data will be prepared as full swath (three) mosaiced
#  2. For master image the DEM data will be prepared
#     Make sure the DEM data is provided, modifed the line
#
#
#  Create by W.G, 2015
#
#
if [ "$#" -le 4 ]
then
    echo " "
    echo "$0: Preparing for the Sentinel-1 full swath SLC data, Organize folder and DEM"
    echo "                                                                       05/2015 W.G"
    echo " "
    echo "USAGE: $0 <IFG_Folder> <SLC identifier> <SLC_TAB> <BURST_tab> <Master/Slave>"
    echo "       1. IFG_Folder   Absolute path of desination folder "
    echo "       2. SLC Id       SLC identifier (example: 20150429)"
    echo "       3. SLC_TAB      Corresponding SLC tab file"
    echo "                       1st row- iw1_SLC iw1_SLC_par iw1_TOPSAR_par"
    echo "                       2nd row- iw2_SLC iw2_SLC_par iw2_TOPSAR_par"
    echo "                       3rd row- iw3_SLC iw3_SLC_par iw3_TOPSAR_par"
    echo "       4. Burst TAB    Burst tab for which busrts to copy"
    echo "       5. M/S          Master/Slave image flag"
    echo "                       input 1 for master"
    echo "                       input 2 for slave"
    echo "       6. DEM_folder   Absolute path of DEM data folder"
    echo "       7. DEM Id       DEM identifier (example, "Nepal" for Nepal.par Nepal.dem)"
    echo "       8. raml         multi-look factor in range direction (default is 10) "
    echo "       9. azml         multi-look factor in azimuth direction (default is 2)"
    echo ""
    echo "EXAMPLE: $0 /import/c/w/gong/Kenny/S1_Nepal_coseismic/20150417_460B_20150429_7332/ 20150429  SLC_TAB Burst_TAB 2 /import/c/w/gong/Kenny/DEM/Nepal/  final_Nepal"
    exit
fi


path=$1
slcname=$2
tabin=$3
burst_tab=$4
raml=10
azml=2
msflag=1

#dempath=/import/c/w/gong/Kenny/DEM/Nepal/
#demname=final_Nepal
demovr1=2
demovr2=2

if [ "$#" -ge 5 ]; then
msflag=$5
fi

if [ "$#" -ge 6 ]; then
dempath=$6
fi

if [ "$#" -ge 7 ]; then
demname=$7
fi

if [ "$#" -ge 8 ]; then
raml=${8}
fi

if [ "$#" -gt 8 ]; then
azml=${9}
fi

tabout0=${tabin}

echo "SLC_copy_S1_bash.sh $1 $2 $3 $4 $5 $6" > $path/SLC_copy_S1_bash_${msflag}.log
echo ""

wrk=`pwd`  # setup current working dir

# preparing the folder save swath mosaic

i=Full
if [ -e  ${tabout0}_sw${i} ]
then
rm ${tabout0}_sw${i}
fi

while read p ; do
	slc=`echo $p | cut -d ' ' -f1`
	par=`echo $p | cut -d ' ' -f2`
	top=`echo $p | cut -d ' ' -f3`
	echo ${path}/${slc} ${path}/${par} ${path}/${top}>>${tabout0}_sw${i}
done <$tabin

#while [ $i -lt 4 ] ; do

echo "##=============-  -================" >>$path/SLC_copy_S1_bash_${msflag}.log

echo "SLC_copy_S1_TOPS ${tabin}  ${tabout0}_sw${i} ${burst_tab}"
SLC_copy_S1_TOPS ${tabin}  ${tabout0}_sw${i} ${burst_tab} >> $path/SLC_copy_S1_bash_${msflag}.log 
#echo ""

cp ${tabin} ${path}/

echo 'cd `pwd`' >>$path/SLC_copy_S1_bash_${msflag}.log  

cd ${path}/

echo "SLC_mosaic_S1_TOPS ${tabin} ${slcname}.slc ${slcname}.slc.par $raml $azml"
SLC_mosaic_S1_TOPS ${tabin} ${slcname}.slc ${slcname}.slc.par $raml $azml >> $path/SLC_copy_S1_bash_${msflag}.log
echo ""

width=`awk '$1 == "range_samples:" {print $2}' $slcname.slc.par`

echo "rasSLC $slcname.slc $width 1 0 50 10"
rasSLC $slcname.slc $width 1 0 50 10 >> $path/SLC_copy_S1_bash_${msflag}.log
echo ""


echo "multi_S1_TOPS ${tabin}  ${slcname}.mli ${slcname}.mli.par $raml $azml"
multi_S1_TOPS  ${tabin} ${slcname}.mli ${slcname}.mli.par $raml $azml >> $path/SLC_copy_S1_bash_${msflag}.log
echo ""


echo $msflag
if [ "$msflag" = "1" ]
then 
	if [ ! -d DEM ]
   	then
	mkdir DEM
	fi

	cd DEM

	mliwidth=`awk '$1 == "range_samples:" {print $2}' ../${slcname}.mli.par`
	mlinline=`awk '$1 == "azimuth_lines:" {print $2}' ../${slcname}.mli.par`
	echo `pwd` >>$path/SLC_copy_S1_bash_${msflag}.log

	echo "GC_map_mod ../${slcname}.mli.par  - $dempath/${demname}.par $dempath/${demname}.dem $demovr1 $demovr2 demseg.par demseg ${slcname}.mli  MAP2RDC inc pix ls_map 1 1"
echo "GC_map_mod ../${slcname}.mli.par  - $dempath/${demname}.par $dempath/${demname}.dem $demovr1 $demovr2 demseg.par demseg ${slcname}.mli  MAP2RDC inc pix ls_map 1 1" >> $path/SLC_copy_S1_bash_${msflag}.log
	GC_map_mod ../${slcname}.mli.par  - $dempath/${demname}.par $dempath/${demname}.dem $demovr1 $demovr2 demseg.par demseg ../${slcname}.mli  MAP2RDC inc pix ls_map 1 1 # >> $path/SLC_copy_S1_bash.log

 	demwidth=`awk '$1 == "width:" {print $2}' demseg.par`

	echo "geocode MAP2RDC demseg $demwidth HGT_SAR_${raml}_${azml} $mliwidth $mlinline"
	geocode MAP2RDC demseg $demwidth HGT_SAR_${raml}_${azml} $mliwidth $mlinline #>> $path/SLC_copy_S1_bash_${msflag}.log

	echo "GC_map_mod ../${slcname}.mli.par  - $dempath/${demname}.par $dempath/${demname}.dem $demovr1 $demovr2 demseg.par demseg ../${slcname}.mli  MAP2RDC inc pix ls_map 1 1" > geocode.log
	echo "geocode MAP2RDC demseg $demwidth HGT_SAR_${raml}_${azml} $mliwidth $mlinline" >> geocode.log

	# Create flat earth incidence angle file
        gc_map ../${slcname}.mli.par - $dempath/${demname}.par 1 demseg.par demseg map_to_rdc 2 2 pwr_sim_map - - inc_flat

	cd ..
fi
echo ""

cp ${tabin} SLC${msflag}_tab
cd $wrk 

echo `pwd` >>$path/SLC_copy_S1_bash_${msflag}.log
echo "##-------------finish sw$i --------------------##">>$path/SLC_copy_S1_bash_${msflag}.log
echo "###----------------------------------------------##">>$path/SLC_copy_S1_bash_${msflag}.log

