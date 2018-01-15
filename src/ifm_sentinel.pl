#!/usr/bin/perl

use FileHandle;
use File::Basename;
use Getopt::Long;
use File::Copy;
use File::Glob ':glob';
use Cwd;
use Env qw(GAMMA_HOME);

if (($#ARGV + 1) < 1) {die <<EOS ;}

usage: $0 <options> output [azlks rnglks] [bm bs]
	output		Output igram directory name
        azlks           Number of looks in azimuth (default 10)
        rlks            Number of looks in range (default 2)
	bm		Master burst file
	bs		Slave burst file
	-d=dem 		(option) specify a DEM file to use (e.g. big for big.dem/big.par)
        -c		(option) cross pol processing - either hv or vh (default hh or vv)
        -i              (option) create incidence angle map corrected for earth curvature
        -l              (option) create look vector theta and phi 

EOS

print "\n\nSentinel1A differential interferogram creation program\n";

my $dem = '';
GetOptions ('d=s' => \$dem , 'c' => \$cp_flag, 'i' => \$inc_flag, 'l' => \$look_flag);

my $out_dir = $ARGV[0];
print "Creating output interferogram directory $out_dir\n\n";

my $WRK = getcwd();
my $log = "$WRK/$out_dir.log";

open my $fh, ">", 'processing.log' || die "Can't open processing.log file";
$datestring = localtime();
my $msg = "$datestring - starting processing\n";
print $fh $msg;

$rlks = 2;
$azlks = 10;

if($#ARGV >= 1) {$azlks = $ARGV[1]; print "Setting azimuth looks to $azlks\n";}
if($#ARGV >= 2) {$rlks = $ARGV[2]; print "Setting range looks to $rlks\n";}
if($#ARGV >= 3) {$bm = $ARGV[3]; print "Setting burst master file to $bm\n";}
if($#ARGV >= 4) {$bs = $ARGV[4]; print "Setting burst slave file to $bs\n";}

#
# Ingest the data into Gamma format
#
my $cnt = 0;
@files = glob "*.zip";
foreach my $file (@files) {
  if ($file =~ /_IW_SLC__/) { 
    $cnt = $cnt + 1;
    if ($file =~ /SDV/) { $type = "SDV"; $pol = "vv"; }
    elsif ($file =~ /SDH/) { $type = "SDH"; $pol = "hh"; }
    elsif ($file =~ /SSV/) { $type = "SSV"; $pol = "vv"; }
    elsif ($file =~ /SSH/) { $type = "SSH"; $pol = "hh"; }
  }
}

#
# If no zip files, look for SAFE files
# 
if ($cnt != 2) { 
  $cnt = 0;
  @files = glob "*.SAFE";
  foreach my $file (@files) {
    print "Checking $file\n";
    if ($file =~ /_IW_SLC__/) { 
      $cnt = $cnt + 1;
      if ($file =~ /SDV/) { $type = "SDV"; $pol = "vv"; }
      elsif ($file =~ /SDH/) { $type = "SDH"; $pol = "hh"; }
      elsif ($file =~ /SSV/) { $type = "SSV"; $pol = "vv"; }
      elsif ($file =~ /SSH/) { $type = "SSH"; $pol = "hh"; }
    }
  }
}

if ($cnt != 2) { die "ERROR: Need two and only two input files of type S1?_IW_SLC__\n\n"; }
print "Type of file is $type\n";

if ($cp_flag) {
  if ($type eq "SDV") {
    $pol = "vh";
    print "Setting pol to vh\n";
  } elsif ($type eq "SDH") {
    $pol = "hv";
    print "Setting pol to hv\n";
  } else {
    print "Flag mismatch -- processing $pol\n";
  }
}
 
print "Processing the $pol polarization\n";

$datestring = localtime();
my $msg = "$datestring - PAR_S1_SLC_SSV\n";
print $fh $msg;

execute("PAR_S1_SLC_SSV.sh $pol",$log);

#
# Get a DEM file if we need to
#
if ($dem eq '') {
  print "Getting a DEM file covering this SAR image\n";
  my @cc = get_cc();
  $min_lon = $cc[0];
  $max_lon = $cc[1];
  $min_lat = $cc[2];
  $max_lat = $cc[3];

  $dem = "big";
  $parfile = "big.par";

  $datestring = localtime();
  my $msg = "$datestring - get_dem.pl\n";
  print $fh $msg;

  $cmd="get_dem.py -u $min_lon $min_lat $max_lon $max_lat tmpdem.tif";
  execute($cmd,$log);

  # If we downsized the SAR image, downsize the DEM file
  # if rlks == 1, then the SAR image is roughly 20 m square -> use native dem res
  # if rlks == 2, then the SAR image is roughly 40 m square -> set dem to 80 meters
  # if rlks == 3, then the SAR image is roughly 60 m square -> set dem to 120 meters 
  # etc.
  #
  # The DEM is set to double the res because it will be 1/2'd by the procedure
  # I.E. if you give a 100 meter DEM as input, the output Igram is 50 meters
  #
  if ($rlks == 1) {
    print "Using DEM at native resolution\n";
  }
  else {
    $res = 20 * $rlks * 2;
    $cmd = "gdalwarp -tr $res $res tmpdem.tif tmpdem2.tif";
    execute($cmd,$log);
    move("tmpdem2.tif","tmpdem.tif");
  }

  print "utm2dem.pl tmpdem.tif $dem.dem $parfile\n";
  `utm2dem.pl tmpdem.tif $dem.dem $parfile`;
} 
else {
  print "Using DEM file $dem\n";
}

mkdir $out_dir;


# Copy the SLC data into the IFM directory
# Create initial mapping from master image to DEM file
#
$datestring = localtime();
my $msg = "$datestring - SLC_copy_S1_fullSW.sh\n";
print $fh $msg;

my $pass = 1;
my @dirs = glob "20??????";
foreach my $l (@dirs) {
  if (-d $l && (length($l)==8)) {
    chdir("$l");
    $bursts=20;
    $lines = `cat *.tops_par`;
    my @out = split /\n/, $lines;
    foreach my $o (@out) {
      if ($o =~ m/number_of_bursts:\s+(\S+)/) {
        $bursts = ($1<$bursts) ? $1 : $bursts;
      }
    }
    print "  Found $bursts bursts to process\n";

    if ($pass == 1) {
      $save_bursts = $bursts;
      if ($bursts == 20) {
        print "ERROR: was unable to get number of bursts\n";
        exit;
      }
    } else {
      if ($bursts != $save_bursts) {
        print "Warning: number of bursts do not match\n";
	print "Using smaller of the two\n";
	$bursts = ($bursts<$save_bursts) ? $bursts : $save_bursts
      }
    }
    chdir("..");
    $pass = $pass + 1;
  }
}

$pass = 1;
foreach my $l (@dirs) {
  if (-d $l && (length($l)==8)) {
    chdir("$l");
    print "\nEntering directory $l\n";
    print "  This is pass #$pass\n";
    if ($pass==1) {
        copy("../$bm","$bm") or die ("ERROR $0: Copy failed: $!");
        $cmd = "SLC_copy_S1_fullSW.sh $WRK/$out_dir $l SLC_TAB $bm $pass $WRK $dem $azlks $rlks";
    } else {
        copy("../$bs","$bs") or die ("ERROR $0: Copy failed: $!");
        $cmd = "SLC_copy_S1_fullSW.sh $WRK/$out_dir $l SLC_TAB $bs $pass $WRK $dem $azlks $rlks";
    }
    execute($cmd,"$log");
    chdir("..");
    $pass = $pass + 1;
  }
}

chdir("$out_dir");

$datestring = localtime();
my $msg = "$datestring - INTERF_PWR_S1_LT_TOPS_Proc.sh 0\n";
print $fh $msg;
$cmd = "INTERF_PWR_S1_LT_TOPS_Proc.sh $dirs[0] $dirs[1] ./DEM/HGT_SAR_".$azlks."_$rlks $azlks $rlks 3 0";
execute($cmd,$log);

$datestring = localtime();
my $msg = "$datestring - INTERF_PWR_S1_LT_TOPS_Proc.sh 1\n";
print $fh $msg;
$cmd = "INTERF_PWR_S1_LT_TOPS_Proc.sh $dirs[0] $dirs[1] 0 $azlks $rlks 3 1";
execute($cmd,$log);

$datestring = localtime();
my $msg = "$datestring - INTERF_PWR_S1_LT_TOPS_Proc.sh 2\n";
print $fh $msg;
$cmd = "INTERF_PWR_S1_LT_TOPS_Proc.sh $dirs[0] $dirs[1] 0 $azlks $rlks 3 2";
execute($cmd,$log);

#
# Check the azimuth offset
# It needs to be less than 0.02 in order for this to work
#
my $checkfile = `cat offsetfit3.log`;
my @check = split /\n/, $checkfile;   # split into lines
my $offset = 1.0;
foreach my $ch (@check) {
    if ($ch =~ m/final azimuth offset poly. coeff.:\s+(\S+)/){
      $offset = $1;
    }
}
if ($offset > 0.02) {
  print "ERROR: Found azimuth offset of $offset!\n";
  exit;
} else {
  print "Found azimuth offset of $offset\n";
}

my $output = "$dirs[0]_$dirs[1]";

$datestring = localtime();
my $msg = "$datestring - S1_coreg_overlap\n";
print $fh $msg;
$cmd = "S1_coreg_overlap SLC1_tab SLC2R_tab $output $output.off.it $output.off.it.corrected";
execute($cmd,$log);

$datestring = localtime();
my $msg = "$datestring - INTERF_PWR_S1_LT_TOPS_Proc_MAN.sh\n";
print $fh $msg;
$cmd = "INTERF_PWR_S1_LT_TOPS_Proc_MAN.sh $dirs[0] $dirs[1] $output.off.it.corrected $azlks $rlks";
execute($cmd,$log);


#
# Perform phase unwrapping and geocoding of results
#
$datestring = localtime();
my $msg = "$datestring - Unwrapping_Geocoding_S1.sh\n";
print $fh $msg;
$cmd = "Unwrapping_Geocoding_S1.sh $dirs[0] $dirs[1] man $azlks $rlks 0 1 1";
execute($cmd,$log);

#
# Generate metadata
#

$out = `base_init $dirs[0].slc.par $dirs[1].slc.par - - base > baseline.log`;

chdir($WRK);

$etc_dir = dirname($0) . "/../etc";
copy("$etc_dir/sentinel_xml.xsl","sentinel_xml.xsl") or die ("ERROR $0: Copy failed: $!");

my @list = glob "S1*.SAFE";
$pass = 0;
for (@list) {
  $path = $_;
  $cmd = "xsltproc --stringparam path $path --stringparam timestamp timestring --stringparam file_size 1000 --stringparam server stuff --output $dirs[$pass].xml sentinel_xml.xsl $path/manifest.safe";
  execute($cmd,$log);
  $pass = $pass + 1;
}

$dem_source = get_dem_type($log);

$version_file = "$GAMMA_HOME/ASF_Gamma_version.txt";
$gamma_version = "20150702"; # The version we got from Charles Werner
if (open(VER, "$version_file")) {
  $gamma_version = <VER>;
  chomp($gamma_version);
} else {
  print "No ASF_Gamma_version.txt file found in $GAMMA_HOME\n";
}

open(HDF5_LIST,"> hdf5.txt") or die "ERROR $0: cannot create hdf5.txt\n\n";
print HDF5_LIST "[Gamma DInSar]\n";
print HDF5_LIST "granule = s1_vertical_displacement\n";
print HDF5_LIST "data = Sentinel-1\n";
print HDF5_LIST "master metadata = $dirs[0].xml\n";
print HDF5_LIST "slave metadata = $dirs[1].xml\n";
print HDF5_LIST "amplitude master = $out_dir/$dirs[0].mli.geo.tif\n";
print HDF5_LIST "amplitude slave = $out_dir/$dirs[1].mli.geo.tif\n";
print HDF5_LIST "digital elevation model = $out_dir/$output.dem.tif\n";
print HDF5_LIST "simulated phase = $out_dir/$output.sim_unw.geo.tif\n";
print HDF5_LIST "filtered interferogram = $out_dir/$output.diff0.man.adf.bmp.geo.tif\n";
print HDF5_LIST "filtered coherence = $out_dir/$output.adf.cc.geo.tif\n";
print HDF5_LIST "unwrapped phase = $out_dir/$output.adf.unw.geo.tif\n";
print HDF5_LIST "vertical displacement = $out_dir/$output.vert.disp.geo.tif\n";
print HDF5_LIST "mli.par file = $out_dir/$dirs[0].mli.par\n";
print HDF5_LIST "gamma version = $gamma_version\n";
print HDF5_LIST "dem source = $dem_source\n";
print HDF5_LIST "main log = $log\n";
print HDF5_LIST "processing log = processing.log\n";
close(HDF5_LIST);


$prod_dir = "PRODUCT";
mkdir $prod_dir;

my @files = glob "S1*.SAFE";
@master_list = split /_/, $files[0];
$master_date = $master_list[5];
@slave_list = split /_/, $files[1];
$slave_date = $slave_list[5];

my $long_output = "${master_date}_${slave_date}";
copy("$out_dir/$dirs[0].mli.geo.tif","${prod_dir}/${long_output}_amp.tif") or die ("ERROR $0: Move failed: $!");
copy("$out_dir/$output.adf.cc.geo.tif","${prod_dir}/${long_output}_corr.tif") or die ("ERROR $0: Move failed: $!");
copy("$out_dir/$output.vert.disp.geo.org.tif","${prod_dir}/${long_output}_vert_disp.tif") or die ("ERROR $0: Move failed: $!");
copy("$out_dir/$output.adf.unw.geo.tif","${prod_dir}/${long_output}_unw_phase.tif") or die ("ERROR $0: Move failed: $!");
if ($inc_flag) { copy("$out_dir/$output.inc.tif","${prod_dir}/${long_output}_inc.tif") or die ("ERROR $0: Move failed: $!");}
if ($look_flag) { 
    copy("$out_dir/$output.lv_theta.tif","${prod_dir}/${long_output}_lv_theta.tif") or die ("ERROR $0: Move failed: $!");
    copy("$out_dir/$output.lv_phi.tif","${prod_dir}/${long_output}_lv_phi.tif") or die ("ERROR $0: Move failed: $!");
}
$cmd = "makeAsfBrowse.py ${out_dir}/${output}.diff0.man.adf.bmp.geo.tif ${prod_dir}/${long_output}_color_phase";
execute($cmd,"$log");
$cmd = "makeAsfBrowse.py ${out_dir}/${output}.adf.unw.geo.bmp.tif ${prod_dir}/${long_output}_unw_phase";
execute($cmd,"$log");

$datestring = localtime();
my $msg = "$datestring - Done!!!\n";
print $fh $msg;

print "\nDone!!!\n";

exit;


sub get_cc {

    my $annotation = `cat */*/s1*.xml`;
    my @ann = split /\n/, $annotation;   # split into lines

    my $min_lat = 90;
    my $min_lon = 180;
    my $max_lat = -90;
    my $max_lon = -180; 

    foreach my $line (@ann) {
      if ($line =~ m/<latitude>(\S+)<\/latitude>/) {
        $max_lat = ($1 > $max_lat) ? $1 : $max_lat;
        $min_lat = ($1 < $min_lat) ? $1 : $min_lat;
      }
      if ($line =~ m/<longitude>(\S+)<\/longitude/) {
        $max_lon = ($1 > $max_lon) ? $1 : $max_lon;
        $min_lon = ($1 < $min_lon) ? $1 : $min_lon;
      }
    } 

    $dmax_lat = sprintf("%.8g",$max_lat);
    $dmin_lat = sprintf("%.8g",$min_lat);
    $dmax_lon = sprintf("%.8g",$max_lon);
    $dmin_lon = sprintf("%.8g",$min_lon);

    $dmax_lat = $dmax_lat + 1.00;
    $dmin_lat = $dmin_lat - 1.00;
    $dmax_lon = $dmax_lon + 1.00;
    $dmin_lon = $dmin_lon - 1.00;

    print "    found max latitude of $dmax_lat\n";
    print "    found min latitude of $dmin_lat\n";
    print "    found max longitude of $dmax_lon\n";
    print "    found min longitude of $dmin_lon\n";

    @parms = ("$dmin_lon","$dmax_lon","$dmin_lat","$dmax_lat");
    return @parms;
}

sub execute{
  my ($command, $log) = @_;
  print "$command\n";

  my $out = `$command`;
  my $exit = $? >> 8;

  if (-e $log){open(LOG,">>$log") or die "ERROR $0: cannot open log file: $log  command: $command\n";}
  else {open(LOG,">$log") or die "ERROR $0 : cannot open log file: $log  command: $command\n";}
  LOG->autoflush;
  print LOG ("\nRunning: ${command}\nOutput:\n${out}\n----------\n");
  close LOG;
  if ($exit != 0) {
    # Moving the "ERROR" into the regular print, so that they appear in the right order
    print "\nnon-zero exit status: ${command}\nOutput:\n${out}\nERROR: non-zero exit status: $command\n";
    die "$0 ERROR";
  }
}

sub get_dem_type {
  my ($log) = @_;
  open(LOG,$log) or die "ERROR $0: could not open log: $log: $!\n\n";
  my (@lines) = <LOG>;
  close(LOG);

  $dem_type = "";
  while (my $line = shift(@lines)) {
    if ($line =~ /Now generating tmpdem\.tif using (\w+)/) {
      $dem_type = $1;
      last;
    }
  }
  return $dem_type;
}


