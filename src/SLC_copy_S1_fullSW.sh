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
if [ "$#" -le 7 ]
then
    echo " "
    echo "$0: Preparing for the Sentinel-1 full swath SLC data, Organize folder and DEM"
    echo "                                                                       05/2015 W.G"
    echo " "
    echo "USAGE: $0 <IFG_Folder> <SLC identifier> <SLC_TAB> <Burst Index-First> <Burst Index-Last> <Master/Slave>"
    echo "       1. IFG_Folder   Absolute path of desination folder "
    echo "       2. SLC Id       SLC identifier (example: 20150429)"
    echo "       3. SLC_TAB      Corresponding SLC tab file"
    echo "                       1st row- iw1_SLC iw1_SLC_par iw1_TOPSAR_par"
    echo "                       2nd row- iw2_SLC iw2_SLC_par iw2_TOPSAR_par"
    echo "                       3rd row- iw3_SLC iw3_SLC_par iw3_TOPSAR_par"
    echo "       4. Burst Id-1   Burst number of the first burst to copy in SLC swath"
    echo "       5. Burst Id-2   Burst number of the last burst to copy in SLC swath"
    echo "       6. M/S          Master/Slave image flag"
    echo "                       input 1 for master"
    echo "                       input 2 for slave"
    echo "       7. DEM_folder   Absolute path of DEM data folder"
    echo "       8. DEM Id       DEM identifier (example, "Nepal" for Nepal.par Nepal.dem)"
    echo "       9. raml         multi-look factor in range direction (default is 10) "
    echo "       10.azml         multi-look factor in azimuth direction (default is 2)"
    echo ""
    echo "EXAMPLE: $0 /import/c/w/gong/Kenny/S1_Nepal_coseismic/20150417_460B_20150429_7332/ 20150429  SLC_TAB 1 5 2 /import/c/w/gong/Kenny/DEM/Nepal/  final_Nepal"
    exit
fi


path=$1
slcname=$2
tabin=$3
burstu=$4
burstl=$5
raml=10
azml=2
msflag=1

#dempath=/import/c/w/gong/Kenny/DEM/Nepal/
#demname=final_Nepal
demovr1=2
demovr2=2

if [ "$#" -ge 6 ]; then
msflag=$6
fi

if [ "$#" -ge 7 ]; then
dempath=$7
fi

if [ "$#" -ge 8 ]; then
demname=$8
fi

if [ "$#" -ge 9 ]; then
raml=${9}
fi

if [ "$#" -gt 9 ]; then
azml=${10}
fi

tabout0=${tabin}_${burstu}_${burstl}

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

echo ${burstu} ${burstl} > BURST_tab
echo ${burstu} ${burstl} >> BURST_tab
echo ${burstu} ${burstl} >> BURST_tab
# echo "2 10" >> BURST_tab


echo "SLC_copy_S1_TOPS ${tabin}  ${tabout0}_sw${i} BURST_tab"
SLC_copy_S1_TOPS ${tabin}  ${tabout0}_sw${i} BURST_tab >> $path/SLC_copy_S1_bash_${msflag}.log 
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
	cd ..
fi
echo ""

cp ${tabin} SLC${msflag}_tab
cd $wrk 

echo `pwd` >>$path/SLC_copy_S1_bash_${msflag}.log
echo "##-------------finish sw$i --------------------##">>$path/SLC_copy_S1_bash_${msflag}.log
echo "###----------------------------------------------##">>$path/SLC_copy_S1_bash_${msflag}.log

