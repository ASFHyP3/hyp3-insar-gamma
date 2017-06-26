#!/bin/bash -fe

if [ "$#" -le 2 ]
then
    echo " "
    echo "$0: For the Sentinel-1 SLC data with DEM coregistration- One single iteration"
    echo "                                                                       05/2015 W.G"
    echo " "
    echo "usage: $0 <pass1> <pass2> [offfile] [rlks] [azlks] [iter] [step] [npoly]"
    echo "       pass1       pass 1 identifier (example: pass number) reference"
    echo "       pass2       pass 2 identifier (example: pass number)"
    echo "       offfile     offset parameter file used in co-registration"
    echo "       rlks        number of range looks (default=10)"
    echo "       azlks       number of azimuth looks (default=2)"
#    echo "       iter        number of iteration for precise coregistration (default=5)"
#    echo "       step        step of offset estimation"
#    echo "                      0: Preparing LT and SIM_UNW "
#    echo "                      1: initial co-registration with DEM"
#    echo "                      2: iteration co-registration"
#    echo "                      3: interferogram generation only"
#    echo "       npoly       number of model polynomial parameters (enter - for default, 1, 3, 4, 6, default: 1)"
    echo "   Note1 : SLC1_tab (reference S-1 SLC) 1st row- iw1_SLC iw1_SLC_par iw1_TOPSAR_par"
    echo "                                      2nd row- iw2_SLC iw2_SLC_par iw2_TOPSAR_par"
    echo "                                      3rd row- iw3_SLC iw3_SLC_par iw3_TOPSAR_par"
    echo "           SLC2_tab (slave S-1 SLC) same format as SLC1_tab"
    echo "           SLC2R_tab (S-1 SLC to be coregistered)"
    echo "   Note2 : Terrian Look-up-table is named as PASS1.lt"
    echo ""
    echo "$0 20150417 20150429 20150307_20150518.off.it 10 2 "
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

rlks=10
azlks=2
npoly=1


if [ "$#" -ge 3 ]; then
        offfile=$3
fi

if [ "$#" -ge 4 ]; then
        rlks=$4
fi

if [ "$#" -ge 5 ]; then
        azlks=$5
fi


wrk=`pwd`

mname=$1   #20141015
sname=$2 #20141003
demfile=$3  #./DEM/HGT_SAR_10_2

ifgname=${mname}_${sname} #20141003_20141015

SLC1tab=SLC1_tab
SLC2tab=SLC2_tab 
SLC2R_tab=SLC2R_tab
lt=$mname.lt


echo "-----------------Starting single iteration co-registration with LT--------------"
#	azshift_thre=0.01
  echo ""
  echo "SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par $offfile $SLC2R_tab ${sname}.rslc ${sname}.rslc.par"
  SLC_interp_lt_S1_TOPS $SLC2tab ${sname}.slc.par $SLC1tab ${mname}.slc.par $lt ${mname}.mli.par ${sname}.mli.par $offfile $SLC2R_tab ${sname}.rslc ${sname}.rslc.par

  echo "create_offset ${mname}.slc.par ${sname}.slc.par ${offfile}.temp 1 $rlks $azlks 0"
  create_offset ${mname}.slc.par ${sname}.slc.par ${offfile}.temp 1 $rlks $azlks 0
  echo ""
#  cp offset_par.0 ${offfile}.temp

  echo "offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${offfile}.temp offs snr 256 64 - 1 32 128 0.2"
  offset_pwr ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${offfile}.temp offs snr 512 256 - 1 16 64 0.2 4

  echo "offset_fit offs snr ${offfile}.temp - - 0.2 1 > ${offfile}.temp.log"
  offset_fit offs snr ${offfile}.temp - - 0.2 1 > ${offfile}.temp.log
  
  echo "SLC_diff_intf ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${offfile}.temp ${ifgname}.sim_unw ${ifgname}.diff0.man $rlks $azlks 0 0"
  SLC_diff_intf ${mname}.slc ${sname}.rslc ${mname}.slc.par ${sname}.rslc.par ${offfile}.temp ${ifgname}.sim_unw ${ifgname}.diff0.man $rlks $azlks 0 0
    width=`grep interferogram_width:  ${offfile}.temp  | awk '{print $2}'`
  
  echo "rasmph_pwr ${ifgname}.diff0.man ${mname}.mli $width 1 1 0 3 3"
  rasmph_pwr ${ifgname}.diff0.man ${mname}.mli $width 1 1 0 3 3

  offset_add ${offfile} ${offfile}.temp  ${offfile}.out
