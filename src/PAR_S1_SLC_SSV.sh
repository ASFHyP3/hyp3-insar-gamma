#! /bin/tcsh -f
#  This script is reading the all the S1 data set listed and converted into
#  GAMMA internal format
#
#

set nonomatch
set wrk = `pwd`  # setup current working dir
echo $wrk

if ($# == 1) then
  set pol = $1
  echo "Trying to process the $pol polarization"
else 
  echo "Defaulting to the vv polarization"
  set pol = "vv"
endif

foreach zipf ( *.zip ) # ($filen) 
        if ( -e $zipf) then
          echo "Processing file $zipf"
          unzip -o $zipf
        endif
end

foreach safef ( *.SAFE ) 
        set type = `echo $safef | awk '{print substr($0,14,3)}'`
        echo "Found type $type"

        if ($type =~ {SSH,SSV}) then
          echo "Found single pol file"
          set single_pol = 1
        else if ($type =~ {SDV}) then
          echo "Found multi-pol file"
          set single_pol = 0
          if ($pol == "hv" || $pol == "hh") then
            echo "ERROR: Incompatible polarization type"
            exit
          endif
        else if ($type =~ {SDH}) then
          echo "Found multi-pol file"
          set single_pol = 0
          if ($pol == "vh" || $pol == "vv") then
            echo "ERROR: Incompatible polarization type"
            exit
          endif
        endif
        echo "Processing file $safef"
        set folder = `echo $safef | cut -d '.' -f1`
        set datelong = `echo $safef | cut -d '_' -f6`
        set acqdate = `echo $datelong | cut -d 'T' -f1`
        echo $folder  $datelong $acqdate
        cd $folder.SAFE

        if ($single_pol == 1) then
          par_S1_SLC measurement/s1*-iw1* annotation/s1*-iw1* annotation/calibration/calibration-s1*-iw1* annotation/calibration/noise-s1*-iw1* ${acqdate}_001.slc.par ${acqdate}_001.slc ${acqdate}_001.tops_par
          par_S1_SLC measurement/s1*-iw2* annotation/s1*-iw2* annotation/calibration/calibration-s1*-iw2* annotation/calibration/noise-s1*-iw2* ${acqdate}_002.slc.par ${acqdate}_002.slc ${acqdate}_002.tops_par
          par_S1_SLC measurement/s1*-iw3* annotation/s1*-iw3* annotation/calibration/calibration-s1*-iw3* annotation/calibration/noise-s1*-iw3* ${acqdate}_003.slc.par ${acqdate}_003.slc ${acqdate}_003.tops_par
        else if ($pol == "vv") then
          par_S1_SLC measurement/s1*-iw1*vv* annotation/s1*-iw1*vv* annotation/calibration/calibration-s1*-iw1*vv* annotation/calibration/noise-s1*-iw1*vv* ${acqdate}_001.slc.par ${acqdate}_001.slc ${acqdate}_001.tops_par
          par_S1_SLC measurement/s1*-iw2*vv* annotation/s1*-iw2*vv* annotation/calibration/calibration-s1*-iw2*vv* annotation/calibration/noise-s1*-iw2*vv* ${acqdate}_002.slc.par ${acqdate}_002.slc ${acqdate}_002.tops_par
          par_S1_SLC measurement/s1*-iw3*vv* annotation/s1*-iw3*vv* annotation/calibration/calibration-s1*-iw3*vv* annotation/calibration/noise-s1*-iw3*vv* ${acqdate}_003.slc.par ${acqdate}_003.slc ${acqdate}_003.tops_par
        else if ($pol == "vh") then
          par_S1_SLC measurement/s1*-iw1*vh* annotation/s1*-iw1*vh* annotation/calibration/calibration-s1*-iw1*vh* annotation/calibration/noise-s1*-iw1*vh* ${acqdate}_001.slc.par ${acqdate}_001.slc ${acqdate}_001.tops_par
          par_S1_SLC measurement/s1*-iw2*vh* annotation/s1*-iw2*vh* annotation/calibration/calibration-s1*-iw2*vh* annotation/calibration/noise-s1*-iw2*vh* ${acqdate}_002.slc.par ${acqdate}_002.slc ${acqdate}_002.tops_par
          par_S1_SLC measurement/s1*-iw3*vh* annotation/s1*-iw3*vh* annotation/calibration/calibration-s1*-iw3*vh* annotation/calibration/noise-s1*-iw3*vh* ${acqdate}_003.slc.par ${acqdate}_003.slc ${acqdate}_003.tops_par
        else if ($pol == "hh") then
          par_S1_SLC measurement/s1*-iw1*hh* annotation/s1*-iw1*hh* annotation/calibration/calibration-s1*-iw1*hh* annotation/calibration/noise-s1*-iw1*hh* ${acqdate}_001.slc.par ${acqdate}_001.slc ${acqdate}_001.tops_par
          par_S1_SLC measurement/s1*-iw2*hh* annotation/s1*-iw2*hh* annotation/calibration/calibration-s1*-iw2*hh* annotation/calibration/noise-s1*-iw2*hh* ${acqdate}_002.slc.par ${acqdate}_002.slc ${acqdate}_002.tops_par
          par_S1_SLC measurement/s1*-iw3*hh* annotation/s1*-iw3*hh* annotation/calibration/calibration-s1*-iw3*hh* annotation/calibration/noise-s1*-iw3*hh* ${acqdate}_003.slc.par ${acqdate}_003.slc ${acqdate}_003.tops_par
        else if ($pol == "hv") then
          par_S1_SLC measurement/s1*-iw1*hv* annotation/s1*-iw1*hv* annotation/calibration/calibration-s1*-iw1*hv* annotation/calibration/noise-s1*-iw1*hv* ${acqdate}_001.slc.par ${acqdate}_001.slc ${acqdate}_001.tops_par
          par_S1_SLC measurement/s1*-iw2*hv* annotation/s1*-iw2*hv* annotation/calibration/calibration-s1*-iw2*hv* annotation/calibration/noise-s1*-iw2*hv* ${acqdate}_002.slc.par ${acqdate}_002.slc ${acqdate}_002.tops_par
          par_S1_SLC measurement/s1*-iw3*hv* annotation/s1*-iw3*hv* annotation/calibration/calibration-s1*-iw3*hv* annotation/calibration/noise-s1*-iw3*hv* ${acqdate}_003.slc.par ${acqdate}_003.slc ${acqdate}_003.tops_par
        else
          echo "Unrecognized polarization $pol"
          exit
        endif

        get_orb.py $folder
	S1_OPOD_vec ${acqdate}_001.slc.par *.EOF
	S1_OPOD_vec ${acqdate}_002.slc.par *.EOF
	S1_OPOD_vec ${acqdate}_003.slc.par *.EOF

        ls *_00*.slc >slctab
        ls *_00*.slc.par > slcpartab
        ls *_00*.tops_par > topstab
        paste slctab slcpartab topstab >SLC_TAB
        #SLC_mosaic_S1_TOPS SLC_TAB ${acqdate}_mos.slc ${acqdate}_mos.slc.par - - -
        set width = `awk '$1 == "range_samples:" {print $2}' ${acqdate}_003.slc.par`
        rasSLC ${acqdate}_003.slc $width 1 0 50 10

        mkdir $wrk/${acqdate}/
        mv *.slc* $wrk/${acqdate}/
        mv *.tops_par $wrk/${acqdate}/
        mv SLC_TAB $wrk/${acqdate}/

        cd $wrk
#        rm -rf $folder.SAFE
end

