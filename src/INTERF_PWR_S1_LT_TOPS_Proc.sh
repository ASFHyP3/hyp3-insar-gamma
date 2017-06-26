#!/bin/bash -fe

if [ "$#" -le 2 ]
then
    echo " "
    echo "$0: For the Sentinel-1 SLC data with DEM coregistration"
    echo "                                                                       05/2015 W.G"
    echo " "
    echo "usage: $0 <pass1> <pass2> [rlks] [azlks] [iter] [step] [npoly]"
    echo "       pass1       pass 1 identifier (example: pass number) reference"
    echo "       pass2       pass 2 identifier (example: pass number)"
    echo "       DEM_SAR     DEM file in SAR coordinates with path, e.g. ./DEM/HGT_SAR"
    echo "                   Skip Look-up-table generation by giving '0' "
    echo "       rlks        number of range looks (default=10)"
    echo "       azlks       number of azimuth looks (default=2)"
    echo "       iter        number of iteration for precise coregistration (default=5)"
    echo "       step        step of offset estimation"
    echo "                      0: Preparing LT and SIM_UNW "
    echo "                      1: initial co-registration with DEM"
    echo "                      2: iteration co-registration"
#    echo "                      3: interferogram generation only"
#    echo "       npoly       number of model polynomial parameters (enter - for default, 1, 3, 4, 6, default: 1)"
    echo "   Note1 : SLC1_tab (reference S-1 SLC) 1st row- iw1_SLC iw1_SLC_par iw1_TOPSAR_par"
    echo "                                      2nd row- iw2_SLC iw2_SLC_par iw2_TOPSAR_par"
    echo "                                      3rd row- iw3_SLC iw3_SLC_par iw3_TOPSAR_par"
    echo "           SLC2_tab (slave S-1 SLC) same format as SLC1_tab"
    echo "           SLC2R_tab (S-1 SLC to be coregistered): will be automatically generated"
    echo "   Note2 : Terrian Look-up-table is named as PASS1.lt"
    echo "           It will be automatically generated, if DEM_SAR ~= 0"
#    echo "         before $0, all subswaths should be merged using SLC_mosaic_S1_TOPS"
    echo "   Note3 : check final azimuth offset poly. coeff. of report_offsetfit (should be around 0.00010 or 0.00001)"
    echo "$0 20150417 20150429 ./DEM//HGT_SAR_10_2 10 2 5 0"
    echo ""
    exit
fi
# example ../../INTERF_PWR_S1_LT_TOPS_Prep.sh 20150417 20150429 ./DEM//HGT_SAR_10_2 10 2 5 0
# exmple ../../INTERF_PWR_S1_LT_TOPS_Prep.sh 20150417 20150429 0 10 2 5 0


ALGORITHM=1

cat > dummy.isp <<EOF
offset parameters
0 0
50 50
128 1024
8.0


EOF

numit=5
rlks=10
azlks=2
#iter=5
step=0
npoly=1

if [ "$#" -ge 4 ]; then
        rlks=$4
fi

if [ "$#" -ge 5 ]; then
        azlks=$5
fi

if [ "$#" -ge 6 ]; then
        numit=$6
fi

if [ "$#" -ge 7 ]; then
        step=$7
fi

#if [ "$#" -ge 7 ]; then
#        npoly=$7
#fi

wrk=`pwd`

mname=$1   #20141015
sname=$2 #20141003
demfile=$3  #./DEM/HGT_SAR_10_2

ifgname=${mname}_${sname} #20141003_20141015

SLC1tab=SLC1_tab
SLC2tab=SLC2_tab 
SLC2R_tab=SLC2R_tab
lt=$mname.lt

if [ -e $SLC2R_tab ]
then
    rm SLC2R_tab
fi

while read p ; do
    slc=`echo $p | cut -d ' ' -f1`
    slc1=`echo $slc | cut -d '.' -f1`
     
    echo ${slc1}.rslc ${slc1}.rslc.par ${slc1}.rtops_par>>SLC2R_tab
done <$SLC2tab


if [ -e $demfile ]    #[  "$step" = "0" ]
then
	echo "-----------------INPUT DEM FILE - $demfile exists----------------"
	echo "------------will prepare look-up-table and sim_unw file----------"

	echo "create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_temp 1 $rlks $azlks 0"
	create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_temp 1 $rlks $azlks 0 # < dummy.isp
	echo ""

	echo "rdc_trans $mname.mli.par $demfile $sname.mli.par $mname.lt"
	rdc_trans $mname.mli.par $demfile $sname.mli.par $mname.lt
	echo ""

	echo "phase_sim_orb ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_temp $demfile ${ifgname}.sim_unw ${mname}.slc.par -"
	phase_sim_orb ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_temp $demfile ${ifgname}.sim_unw ${mname}.slc.par -
	echo ""

#	rm ${ifgname}.off_temp 
fi

if [  "$step" = "1" ]
then 
    echo "-----------------Starting initial co-registration with LT--------------"
    echo "-----------------------------------------------------------------------"

	i=0
	echo "SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par - $SLC2R_tab ${sname}.rslc ${sname}.rslc.par"
	SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par - $SLC2R_tab ${sname}.rslc ${sname}.rslc.par
	echo""

	echo "checking the initial LT resampling result"

	echo "create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_${i} 1 $rlks $azlks 0"
	create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_${i} 1 $rlks $azlks 0

	echo "offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} offs snr 256 64 offsets 1 64 256 0.2"
	offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} offs snr 256 64 offsets 1 64 256 0.2 

	offset_fit offs snr ${ifgname}.off_${i} - - 0.2 1 > offsetfit${i}.log

	SLC_diff_intf ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} ${ifgname}.sim_unw ${ifgname}.diff0 $rlks $azlks 0 0

	width=`grep interferogram_width:  ${ifgname}.off_${i}  | awk '{print $2}'`
	rasmph_pwr ${ifgname}.diff0 ${mname}.mli $width 1 1 0 3 3

	cp ${ifgname}.off_${i} ${ifgname}.off.it

fi

if [  "$step" = "2" ]
then
    echo "-----------------Starting iteration co-registration with LT--------------"
    echo "------------------------NO. of iteration is $numit------------------------------------"
	i=1
#	azshift_thre=0.01
while [ "$i" -le $numit ]
  do
  echo ""
  echo "SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par ${ifgname}.off.it $SLC2R_tab ${sname}.rslc ${sname}.rslc.par"
  SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par ${ifgname}.off.it $SLC2R_tab ${sname}.rslc ${sname}.rslc.par

  echo "create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_${i} 1 $rlks $azlks 0"
  create_offset ${mname}.slc.par ${sname}.slc.par ${ifgname}.off_${i} 1 $rlks $azlks 0

  echo "offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} offs snr 256 64 offsets 1 64 256 0.2"
  offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} offs snr 256 64 offsets 1 64 256 0.2 

  echo "offset_fit offs snr ${ifgname}.off_${i} - - 0.2 1 > offsetfit${i}.log"
  offset_fit offs snr ${ifgname}.off_${i} - - 0.2 1 > offsetfit${i}.log
  azshiftit=`grep "final azimuth offset poly. coeff.:" offsetfit${i}.log  | awk '{print $6}'`
  echo "the azimuth shift compensation value is "
  echo $azshiftit

#  if [ "$azshiftit" -le "$azshift_thre" ]
#  then
    SLC_diff_intf ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${ifgname}.off_${i} ${ifgname}.sim_unw ${ifgname}.diff0.it${i} $rlks $azlks 0 0
    width=`grep interferogram_width:  ${ifgname}.off_${i}  | awk '{print $2}'`
    rasmph_pwr ${ifgname}.diff0.it${i} ${mname}.mli $width 1 1 0 3 3
#fi

  offset_add ${ifgname}.off.it ${ifgname}.off_${i}  ${ifgname}.off_${i}.temp
  cp ${ifgname}.off_${i}.temp ${ifgname}.off.it

  i=$(($i+1))
done
#
#if [ "$azshiftit" -le "$azshift_thre" ]
#then
#echo "the incoherence co-reigistration estimated offset seems ok, go check out image"
#fi

fi



