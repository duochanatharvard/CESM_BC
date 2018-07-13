#####################################################################################
# A script for making boundary files from E runs for F runs
# Modification regarding using other SST as inputs are instructed
# Please make sure that the sea ice and SST have the same and standard resolution
# The reference is here:
#         http://www.cesm.ucar.edu/models/cesm1.2/cesm/doc/usersguide/x2306.html
#####################################################################################

#######################################################
# Setting Parameters
#######################################################
export casename="E_4c"

# directory of this file and icesst toolbox
export dir_tool=$(pwd)

# directory of SST and seaice data
export dir_data="/n/regal/huybers_lab/dchan/cesm_output/${casename}/run/"

# directory of forcing files
export dir_forcing="/n/home10/dchan/holy_kuang/cesm_output/CESM_input/atm/cam/sst/"

export num_yr=20
export num_yr_0=`expr $num_yr - 1`
export num_mon=`expr $num_yr \* 12`
export num_mon_0=`expr $num_yr \* 12 - 1`
# Interval to take climatology. First year starts from 0.
export yr_clim_st=0
export yr_clim_ed=${num_yr_0}


#######################################################
# copy the target files into a working directory
# Modify these lines for your requirements
#######################################################
cd ${casename}
mkdir sea_ice
nohup cp -i ${casename}.cice.h.004*.nc sea_ice/  &
nohup cp -i ${casename}.cice.h.005*.nc sea_ice/  &
nohup cp -i ${casename}.cice.h.006*.nc sea_ice/  &
cd sea_ice

#######################################################
# Concatinate SST files
#######################################################
rm ice_cov.nc sst_cpl sst_cpl_inter sst_cpl.nc sst_cpl_sub
ncrcat -v sst ${casename}.cice.h.*.nc temp.nc
ncrename -v sst,SST_cpl temp.nc sst_cpl.nc
rm temp.nc

#######################################################
# Concatinate aice files
#######################################################
ncrcat -v aice ${casename}.cice.h.*.nc temp.nc
ncrename -v aice,ice_cov temp.nc temp2.nc
ncap2 -s 'ice_cov=ice_cov/100.' temp2.nc ice_cov.nc
rm temp.nc temp2.nc

#######################################################
# Convert SST file into the standard format
#######################################################
# Modify fill values in the sst_cpl file (which are over land points) to
# have value -1.8 and remove fill and missing value designators;
# change coordinate lengths and names:

# to accomplish this, first run ncdump,
ncdump -d 9,17 sst_cpl.nc > sst_cpl

# then replace _ with -1.8 in SST_cpl,
# then remove lines with _FillValue and missing_value.
sed -i "s/\b_\b/-1.8/g"  sst_cpl
grep -v "_FillValue" sst_cpl > sst_cpl_inter
grep -v "missing_value" sst_cpl_inter > sst_cpl_sub

# To change coordinate lengths and names,
# replace nlon by lon, nlat by lat, TLONG by lon, TLAT by lat.
sed -i "s/\bTLONG\b/lon/g"   sst_cpl_sub
sed -i "s/\bTLON\b/lon/g"   sst_cpl_sub
sed -i "s/\bTLAT\b/lat/g"   sst_cpl_sub
sed -i "s/\bni\b/lon/g"   sst_cpl_sub
sed -i "s/\bnj\b/lat/g"   sst_cpl_sub

# ncdumpThe last step is to run ncgen.
ncgen -o sst_cpl_new.nc sst_cpl_sub
rm sst_cpl sst_cpl_inter sst_cpl_sub

#######################################################
# Convert Sea Ice file into the standard format
#######################################################
# Modify fill values in the ice_cov file (which are over land points)
# to have value 1 and remove fill and missing value designators;
# change coordinate lengths and names; patch longitude and latitude to
# replace missing values: to accomplish this,

# first run ncdump,
ncdump -d 9,17 ice_cov.nc > ice_cov

# then replace _ with 1 in ice_cov,
# then remove lines with _FillValue and missing_value.
sed -i "s/\b_\b/1/g"  ice_cov
grep -v "_FillValue" ice_cov > ice_cov_inter
grep -v "missing_value" ice_cov_inter > ice_cov_sub

# To change coordinate lengths and names,
# replace ni by lon, nj by lat, TLON by lon, TLAT by lat.
sed -i "s/\bTLONG\b/lon/g"  ice_cov_sub
sed -i "s/\bTLON\b/lon/g"   ice_cov_sub
sed -i "s/\bTLAT\b/lat/g"   ice_cov_sub
sed -i "s/\bni\b/lon/g"     ice_cov_sub
sed -i "s/\bnj\b/lat/g"     ice_cov_sub

# To patch longitude and latitude arrays,
# replace values of those arrays with those in sst_cpl file.
# (Note: the replacement of longitude and latitude missing values
# by actual values should not be necessary but is safer.)
# by CD: This step is omitted becuase in the slab ocean run,
# both sst and sea ice are output by the cice module,
# and should have the same longitude and latitude

ncgen -o ice_cov_new.nc ice_cov_sub
rm ice_cov ice_cov_inter ice_cov_sub

#######################################################
# Combining the two files,
# by appending the cice into the sst file
# And Rename the file to ssticetemp.nc.
#######################################################
cp ice_cov_new.nc ice_cov_new2.nc
cp sst_cpl_new.nc sst_cpl_new2.nc
ncks -A -v ice_cov ice_cov_new2.nc sst_cpl_new2.nc
cp sst_cpl_new2.nc ssticetemp.nc

#######################################################
# Modify the time
#######################################################
# The time variable will refer to the number of days at the end of each month,
# counting from year 0, whereas the actual simulation began at year 1 (CESM default);
# however, we want time values to be in the middle of each month,
# referenced to the first year of the simulation (first time value equals 15.5);
# extract (using ncks) time variable from existing amip sst file into working netcdf file.

# A forcing file can be download from here:
#                   https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata/atm/

# Note that the target file here is the HadISST AMIP forcing file
# Please make sure that the data format are consistent in the two files
# Other wise convert with ncap2 first
ncap2  -s 'time=float(time)' sst_HadOIBl_bc_1x1_1850_2016_c170525.nc  sst_HadOIBl_bc_1x1_1850_2016_c170525_2.nc
ncks -A -d time,0,${num_mon_0} -v time ${dir_forcing}sst_HadOIBl_bc_1x1_1850_2016_c170525_2.nc ssticetemp.nc

# Add date variable: ncdump date variable from existing amip sst file;
# modify first year to be year 0 instead of 1949
# (do not including leading zeroes or it will interpret as octal)
# and use correct number of months; ncgen to new netcdf file;
# extract date (using ncks) and place in working netcdf file.

# This is achived using the following matlab code
matlab -nosplash -nodesktop -r "N=${num_yr};year=repmat([0:1:N-1],12,1);month=repmat([1:12]',1,N);day=repmat([16;15;repmat(16,10,1)],1,N);a=(year*10000+month*100+day);file=[${dir_data},'sea_ice/ssticetemp.nc'];nccreate(file,'date','Dimensions',{'time',12*N},'Datatype','int32');ncwrite(file,'date',a(:));ncwriteatt(file,'date','long_name','current date (YYYYMMDD)');quit;">>log_snd

# Add datesec variable: extract (using ncks) datesec (correct number of months) from existing amip sst file and place in working netcdf file.
ncks -A -d time,0,${num_mon_0} -v datesec ${dir_forcing}sst_HadOIBl_bc_1x1_1850_2016_c170525_2.nc ssticetemp.nc

#######################################################
# At this point, you have an SST/ICE file in the correct format.
# However, due to CAM's linear interpolation between mid-month values,
# you need to apply a procedure to assure that the computed monthly means are consistent with the input data.
# To do this, you can invoke the bcgen code in models/atm/cam/tools/icesst and following the following steps:
# reference: https://bb.cgd.ucar.edu/problem-recipe-using-b-compset-output-create-sstice-forcing-files-f-compset
# This toolbox does not come with the CESM but can be found here: ftp://ftp.cgd.ucar.edu/archive/SSTICE/
# Credit goes to Jim Rosinski, Brian Eaton, B. Eaton for coding up this toolbox
# It now comes with the code in Github, with all following modifications:
# 1. In driver.f90, sufficiently expand the lengths of variables prev_history and history
#    (16384 should be sufficient); also comment out the test that the
#    climate year be between 1982 and 2001 (lines 152-158).
# 2. In bcgen.f90 and setup_outfile.f90, change the dimensions of xlon and xlat to (nlon,nlat);
#    this is to accommodate use of non-cartesian ocean grid.
# 3. In setup_outfile.f90, modify the 4th and 5th arguments in the calls to
#    wrap_nf_def_var for lon and lat to be 2 and dimids;
#    this is to accommodate use of non-cartesian ocean grid.
# 4. Adjust Makefile to have proper path for LIB_NETCDF and INC_NETCDF.
#######################################################

# Rename SST_cpl to SST, and ice_cov to ICEFRAC in the current SST/ICE file:
cp ssticetemp.nc ssticetemp_new.nc
ncrename -v SST_cpl,SST -v ice_cov,ICEFRAC ssticetemp_new.nc

# Modify namelist accordingly.
cd dir_tool
cd bcgen
sed -i "s/\( iyrn = \).*/\1${num_yr_0}/"             namelist
sed -i "s/\( iyrnout = \).*/\1${num_yr_0}/"          namelist
sed -i "s/\( iyrnrd = \).*/\1${num_yr_0}/"           namelist
sed -i "s/\( iyr1clm = \).*/\1${yr_clim_st}/"        namelist
sed -i "s/\( iyrnclm = \).*/\1${yr_clim_ed}/"        namelist

# Make bcgen and execute per instructions.
gmake

# Run the bcgen code and the resulting sstice_ts.nc
# file is the desired ICE/SST file.
rm  ssticetemp_new.nc
ln -sf ${dir_data}/sea_ice/ssticetemp_new.nc .
./bcgen -i ssticetemp_new.nc -c sstice_clim_${casename}.nc -t sstice_ts_${casename}.nc < namelist

# Place new SST/ICE file in desired location.
cp -i sstice_clim_* ${dir_forcing}
cp -i sstice_ts_* ${dir_forcing}
