      program makencml

!      --This file is a component of the USGS program Ash3d for volcanic ash transport
!          and dispersion.

!      --Use of this program is described in:

!        Schwaiger, H.F., Denlinger, R.P., and Mastin, L.G., in press, Ash3d, a finite-
!           volume, conservative numerical model for ash transport and tephra deposition,
!           Journal of Geophysical Research, 117, B04204, doi:10.1029/2011JB008968

!      --Written in Fortran 90

!      --The program has been successsfully tested and run on the Linux Operating System using
!          Red Hat and Ubuntu 10 and 11.

!       Although this program has been used by the USGS, no warranty, expressed or implied, is 
!         made by the USGS or the United States Government as to the accuracy and functioning 
!         of the program and related program material nor shall the fact of distribution constitute 
!         any such warranty, and no responsibility is assumed by the USGS in connection therewith.

!    program that makes an ncml file that strips out all the variables not used

      implicit none
      integer            ::   nargs
      character(len=130)  :: infile
      character(len=18)  :: outfile
     

!     TEST READ COMMAND LINE ARGUMENTS
      nargs = iargc()
      if (nargs.eq.2) then                !If there's 1 command-line argument,
                                          ! it's the input file name.  Read it.
           call getarg(1,infile)
           call getarg(2,outfile)
         else
           write(6,*)'Enter name of input file:$'
           write(6,*)'Example: gfs.t18z.pgrb2f00'
           read(5,'(a35)') infile
           write(6,*) 'Enter name of output file (17 chars):$'
           write(6,*) 'Example: gfs.t18z.f00.ncml'
           read(5,'(a35)') outfile
      end if

      write(6,2) infile, outfile
2     format('making ncml wrapper for ',a35,/, &
             'Creating ncml file ',a17)

      open(unit=10,file=outfile)
      write(10,1) infile
      write(6,*)  'Task completed'
      close(10)

      stop 0

!the following variables will remain in the netcdf file
            !float lat(lat)
            !float lon(lon)
            !double reftime(reftime)
            !float isobaric2(isobaric2)
            !char reftime_ISO(reftime, reftime(ISO_strlen)
            !double time(time)
            !float isobaric3(isobaric3)
            !float Relative_humidity_isobaric(time, isobaric3, lat, lon)
            !float Temperature_isobaric(time,isobaric3,lat,lon)
            !float u-component_of_wind_isobaric(time, isobaric3, lat, lon)
            !float v-component_of_wind_isobaric(time, isobaric3, lat, lon)
            !float Vertical_velocity_pressure_isobaric(time, isobaric2, lat, lon)

1     format('<?xml version="1.0" encoding="UTF-8"?>',/, &
             '<!--this is an attempt at an ncml version of the grib2 file -->',/, &
             '<netcdf xmlns="http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2" location="',a24,'">',/, &
             '  <remove name="pressure_difference_layer" type="variable" />',/, &
             '  <remove name="pressure_difference_layer_bounds" type="variable" />',/, &
             '  <remove name="isobaric" type="variable" />',/, &
             '  <remove name="height_above_ground_layer" type="variable" />',/, &
             '  <remove name="height_above_ground_layer_bounds" type="variable" />',/, &
             '  <remove name="pressure_difference_layer1" type="variable" />',/, &
             '  <remove name="pressure_difference_layer1_bounds" type="variable" />',/, &
             '  <remove name="potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="height_above_ground" type="variable" />',/, &
             '  <remove name="altitude_above_msl" type="variable" />',/, &
             '  <remove name="isobaric1" type="variable" />',/, &
             '  <remove name="sigma_layer" type="variable" />',/, &
             '  <remove name="sigma_layer_bounds" type="variable" />',/, &
             '  <remove name="height_above_ground1" type="variable" />',/, &
             '  <remove name="height_above_ground2" type="variable" />',/, &
             '  <remove name="height_above_ground3" type="variable" />',/, &
             '  <remove name="sigma" type="variable" />',/, &
             '  <remove name="height_above_ground_layer1" type="variable" />',/, &
             '  <remove name="height_above_ground_layer1_bounds" type="variable" />',/, &
             '  <remove name="height_above_ground4" type="variable" />',/, &
             '  <remove name="depth_below_surface_layer" type="variable" />',/, &
             '  <remove name="depth_below_surface_layer_bounds" type="variable" />',/, &
             '  <remove name="pressure_difference_layer2" type="variable" />',/, &
             '  <remove name="pressure_difference_layer2_bounds" type="variable" />',/, &
             '  <remove name="Absolute_vorticity_isobaric" type="variable" />',/, &
             '  <remove name="Apparent_temperature_height_above_ground" type="variable" />',/, &
             '  <remove name="Cloud_mixing_ratio_isobaric" type="variable" />',/, &
             '  <remove name="Cloud_water_entire_atmosphere" type="variable" />',/, &
             '  <remove name="Convective_available_potential_energy_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Convective_available_potential_energy_surface" type="variable" />',/, &
             '  <remove name="Convective_inhibition_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Convective_inhibition_surface" type="variable" />',/, &
             '  <remove name="Dewpoint_temperature_height_above_ground" type="variable" />',/, &
             '  <remove name="Geopotential_height_tropopause" type="variable" />',/, &
             '  <remove name="Geopotential_height_potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="Geopotential_height_surface" type="variable" />',/, &
             '  <remove name="Geopotential_height_highest_tropospheric_freezing" type="variable" />',/, &
             '  <remove name="Geopotential_height_zeroDegC_isotherm" type="variable" />',/, &
             '  <remove name="Geopotential_height_maximum_wind" type="variable" />',/, &
             '  <remove name="Haines_Index_surface" type="variable" />',/, &
             '  <remove name="ICAO_Standard_Atmosphere_Reference_Height_tropopause" type="variable" />',/, &
             '  <remove name="ICAO_Standard_Atmosphere_Reference_Height_maximum_wind" type="variable" />',/, &
             '  <remove name="Ice_cover_surface" type="variable" />',/, &
             '  <remove name="Land_cover_0__sea_1__land_surface" type="variable" />',/, &
             '  <remove name="Per_cent_frozen_precipitation_surface" type="variable" />',/, &
             '  <remove name="Potential_temperature_sigma" type="variable" />',/, &
             '  <remove name="Precipitable_water_entire_atmosphere" type="variable" />',/, &
             '  <remove name="Pressure_height_above_ground" type="variable" />',/, &
             '  <remove name="Pressure_potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="Pressure_tropopause" type="variable" />',/, &
             '  <remove name="Pressure_surface" type="variable" />',/, &
             '  <remove name="Pressure_maximum_wind" type="variable" />',/, &
             '  <remove name="Pressure_reduced_to_MSL_msl" type="variable" />',/, &
             '  <remove name="Relative_humidity_sigma_layer" type="variable" />',/, &
             '  <remove name="Relative_humidity_sigma" type="variable" />',/, &
             '  <remove name="Relative_humidity_entire_atmosphere" type="variable" />',/, &
             '  <remove name="Relative_humidity_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Relative_humidity_height_above_ground" type="variable" />',/, &
             '  <remove name="Relative_humidity_highest_tropospheric_freezing" type="variable" />',/, &
             '  <remove name="Relative_humidity_zeroDegC_isotherm" type="variable" />',/, &
             '  <remove name="Snow_depth_surface" type="variable" />',/, &
             '  <remove name="Soil_temperature_depth_below_surface_layer" type="variable" />',/, &
             '  <remove name="Specific_humidity_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Specific_humidity_height_above_ground" type="variable" />',/, &
             '  <remove name="Storm_relative_helicity_height_above_ground_layer" type="variable" />',/, &
             '  <remove name="Temperature_height_above_ground" type="variable" />',/, &
             '  <remove name="Temperature_altitude_above_msl" type="variable" />',/, &
             '  <remove name="Temperature_tropopause" type="variable" />',/, &
             '  <remove name="Temperature_potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="Temperature_maximum_wind" type="variable" />',/, &
             '  <remove name="Temperature_surface" type="variable" />',/, &
             '  <remove name="Temperature_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Temperature_sigma" type="variable" />',/, &
             '  <remove name="Total_ozone_entire_atmosphere" type="variable" />',/, &
             '  <remove name="Ozone_Mixing_Ratio_isobaric" type="variable" />',/, &
             '  <remove name="Vertical_Speed_Shear_potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="Vertical_Speed_Shear_tropopause" type="variable" />',/, &
             '  <remove name="U-Component_Storm_Motion_height_above_ground_layer" type="variable" />',/, &
             '  <remove name="V-Component_Storm_Motion_height_above_ground_layer" type="variable" />',/, &
             '  <remove name="Ventilation_Rate_planetary_boundary" type="variable" />',/, &
             '  <remove name="MSLP_Eta_model_reduction_msl" type="variable" />',/, &
!             '  <remove name="\5-Wave_Geopotential_Height_isobaric" type="variable" />',/, &
             '  <remove name="Planetary_Boundary_Layer_Height_surface" type="variable" />',/, &
             '  <remove name="Pressure_of_level_from_which_parcel_was_lifted_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="Sunshine_Duration_surface" type="variable" />',/, &
             '  <remove name="Surface_Lifted_Index_surface" type="variable" />',/, &
             '  <remove name="Best_4_layer_Lifted_Index_surface" type="variable" />',/, &
             '  <remove name="Volumetric_Soil_Moisture_Content_depth_below_surface_layer" type="variable" />',/, &
             '  <remove name="Wilting_Point_surface" type="variable" />',/, &
             '  <remove name="Field_Capacity_surface" type="variable" />',/, &
             '  <remove name="Vertical_velocity_pressure_sigma" type="variable" />',/, &
             '  <remove name="Water_equivalent_of_accumulated_snow_depth_surface" type="variable" />',/, &
             '  <remove name="Wind_speed_gust_surface" type="variable" />',/, &
             '  <remove name="u-component_of_wind_height_above_ground" type="variable" />',/, &
             '  <remove name="u-component_of_wind_planetary_boundary" type="variable" />',/, &
             '  <remove name="u-component_of_wind_sigma" type="variable" />',/, &
             '  <remove name="u-component_of_wind_maximum_wind" type="variable" />',/, &
             '  <remove name="u-component_of_wind_tropopause" type="variable" />',/, &
             '  <remove name="u-component_of_wind_altitude_above_msl" type="variable" />',/, &
             '  <remove name="u-component_of_wind_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="u-component_of_wind_potential_vorticity_surface" type="variable" />',/, &
             '  <remove name="v-component_of_wind_height_above_ground" type="variable" />',/, &
             '  <remove name="v-component_of_wind_planetary_boundary" type="variable" />',/, &
             '  <remove name="v-component_of_wind_maximum_wind" type="variable" />',/, &
             '  <remove name="v-component_of_wind_sigma" type="variable" />',/, &
             '  <remove name="v-component_of_wind_tropopause" type="variable" />',/, &
             '  <remove name="v-component_of_wind_altitude_above_msl" type="variable" />',/, &
             '  <remove name="v-component_of_wind_pressure_difference_layer" type="variable" />',/, &
             '  <remove name="v-component_of_wind_potential_vorticity_surface" type="variable" />',/, &
             '</netcdf>')
        end
