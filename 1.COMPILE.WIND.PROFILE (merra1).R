 ##
#####
## ##################################################################################################
#####
 ##
 ##  this requires us to have a template NetCDF file with the right variables available
 ##  can't do that within R easily, so need to download NCO from http://nco.sourceforge.net/
 ##  save an single MERRA SLV file as MERRA_IN.nc and run the following commands:
 ##
 #### MERRA 1
  # ncks -x -v disph,t10m,t2m,ts,u10m,u50m,v10m,v50m MERRA_IN.nc MERRA_OUT.nc
  # ncrename -h -O -v u2m,A MERRA_OUT.nc
  # ncrename -h -O -v v2m,z MERRA_OUT.nc
  # ncatted -a long_name,A,o,c,"Scale factor for log-law extrapolation: W = A log(h / z)" MERRA_OUT.nc
  # ncatted -a long_name,z,o,c,"Ref height for log-law extrapolation: W = A log(h / z)" MERRA_OUT.nc
  #
 ##
 ##
#####
## ##################################################################################################
#####
 ##
 ##  this runs through all merra files in the specified folders  
 ##  reads the wind speed data and calculates the extrapolation parameters
 ##  then saves the A and z values to NetCDF files
 ##
 ##  after running, you should move the resulting files into their own folder
 ##
 ##


#####
## ##  SETUP
#####

	# the folders we wish to read merra data from
	merraBase = 'W:/MERRA_WIND/'

	# the folders we wish to write profiles to
	outputBase = 'W:/MERRA_PROFILES/'

	# our blank NetCDF template file to be filled
	templateFile = 'M:/WORK/Wind Modelling/VWF CODE/TOOLS/MERRA.log.law.template.A.z.nc'

	# path to the VWF model
	VWFMODEL = 'Q:/VWF/lib/VWF.R'





#####
## ##  READ IN DATA
#####

	# load the VWF model
	source(VWFMODEL)

	# find and prepare all our merra files
	merra = prepare_merra_files(merraFolder)

	# prepare a NetCDF file handler so our format is known
	f = merra$files[1]
	nc = NetCdfClass(f, 'MERRA1', TRUE)

	# subset if necessary
	if (exists('region'))
		nc$subset_coords(region)

	# close this input file
	nc$close_file()







#####
## ##  PREPARE OUR CLUSTER
#####

	# build a parallel cluster
	# note that it doesn't make sense going much beyond 8 cores
	library(doParallel)
	cl = makeCluster(8)
	registerDoParallel(cl)

	# provide the extrapoalte function to each core
	clusterExport(cl, varlist=c('extrapolate_log_law'))







#####
## ##  RUN
#####

	# run through each input merra file
	for (f in merra$files)
	{
		# decide the filename for this output data
		o = gsub('prod.assim.tavg1_2d_slv', 'wind_profile', f)
		o = gsub('tavg1_2d_slv_Nx', 'wind_profile', f)
		o = gsub(merraBase, outputBase, o)

		# skip if this already exists
		clear_line()
		if (file.exists(o))
		{
			clear_line("Skipping", o)
			next
		}



		# get this file's time attributes
		nc$open_file(f)
		myTime = ncatt_get(nc$ncdf, "time", "units")$value
		nc$close_file()



		# do the extrapolation, getting the A,z parameters
		profile = extrapolate_ncdf(f)

		# safety checks
		err = which(profile$z > 100)
		profile$z[err] = 100

		err = which(profile$z < 10^-10)
 		profile$z[err] = 10^-10

		err = which(profile$A < 0)
		profile$A[err] = 0




		# create the NetCDF file for this month
		file.copy(templateFile, o)

		# open this file for writing
		ncout = nc_open(o, write=TRUE)

		# set its time attributes
		ncatt_put(ncout, "time", "units", myTime)

		# put our data in
		for (var in names(profile))
		{
			ncvar_put(ncout, var, profile[[var]])
		}

		# save and close
		nc_close(ncout)
		cat("Written", o, "\n")
	}



	cat("\n\n\nFLAWLESS!\n\n")
	