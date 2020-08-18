#!/usr/bin/python3

# pysolar library for calculations
from pysolar.solar import *

# datetime for "now"
import datetime

# so that we can ignore warnings
import warnings

# ignore leapseconds warnings
warnings.simplefilter("ignore")

#lat lon of roof plus elevation of webcamera
lat, lon, elevation =  ENTERLATITUDEHERE, ENTERLONGITUDEHERE, ENTERELEVATIONHERE

# create a timezone aware datetime
now = datetime.datetime.now(datetime.timezone.utc)

# calculate the sunelevation
sunelevation = get_altitude(lat, lon, now, elevation=elevation)

# adjust it down so that at dawn we already have some time before for the shutter 
sunelevation += 6

#print to stdout, which will be catched by the bash script
print(sunelevation)
