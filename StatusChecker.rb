require_relative 'HtmlTableStatusScraper'
require_relative 'ColParamRange'
require_relative 'Email'
require_relative 'SQLChecker'
require_relative 'SublinkStatusScraper'
require_relative 'RemoteFileGrepper'
require_relative 'ping'
require_relative 'grab_geopdf_numbers'
require_relative 'log_checker'
require 'date'

def boilToSMS(alertStr)
  alerts = alertStr.split('<td style="background-color: ')
  alerts = alerts.find_all {|str| str =~ /#F99/}
  alerts = alerts.collect {|str| str =~ />([^>]+)(<\/a>)*<\/td>/; $1}
  alerts.join(', ')
end

email = false
if (!ARGV[0].nil?)
    if ((ARGV[0] <=> "email") == 0)
        email=true
    end    
end

# set up timestamp stuff
DAY_SECONDS = 24 * 60 * 60
today = Time.new
yesterday = today - DAY_SECONDS
year = today.year
yesteryear = yesterday.year
yesteryear = yesteryear.to_s
yr = year.to_s
mon = today.mon.to_s
tday = today.mday
yday = (tday-1).to_s
yyday =(tday-2).to_s
hr = ((today.hour)-1).to_s
tday = tday.to_s
ydoy = ((today.yday)-1).to_s
htmlErrorMesgs = ""
MAX_TABLE_COLS = 8
# results hash
results = { 'products' => {}, 'webapps' => {}, 'systems' => {} }
# and links
links = { 'products' => {}, 'webapps' => {}, 'systems' => {} }

# to use the HTML table status scraper, you need:
#  -- a URL
#  -- a regular expression to pick the lines of interest
#  -- a regular expression to pick a data column out of a line
#  -- an index to find the data value from the regexp match

# hyd
# hyds should show up before noon
if today.hour > 11
    hydday = today.yday
    dbNow = Time.new
else
    hydday = today.yday - 1
    dbNow = (Time.new) - DAY_SECONDS
end
# url = sprintf("http://alfi.soils.wisc.edu/wimnext/opu/data/opu%4d%03d",year,hydday)
url = sprintf("/wimnext/opu/data/opu%4d%03d",year,hydday)
lineMatch = sprintf("%4d%03d",year,hydday)

# note this is a plain generic HtmlStatusScraper
htmlScraper = HtmlStatusScraper.new(url,lineMatch)
htmlScraper.serverStr = "alfi.soils.wisc.edu"
if ((results['products']["hyd"] = htmlScraper.validate) == false)
    htmlErrorMesgs += htmlScraper.errMesg
end
links['products']["hyd"] = "http://alfi.soils.wisc.edu/cgi-bin/asig/HYDAccessPage.rb#today"

# HYD database

dbChecker = SQLChecker.new("opu")
results['products']["hydDB"] = dbChecker.hasYesterday(dbNow,"hyd","date")
links['products']["hydDB"] = "http://alfi.soils.wisc.edu/asig/rails/wimnext-rails/hyd"
# check AWS 7-day page

# the url; easy enough for this one
url = '/uwex_agwx/awon/awon_seven_day';

# match yesterday's date inside an HTML table; when all filled out, this
# comes out looking something like <TD>2002-0*5-0*15</TD>.*</TR>
# note the .*</TR> at the end, that grabs all the rest of the thing so that
# the subsequent column matching has something to work with
lineMatch = "<TD>#{yr}-0*#{mon}-0*#{yday}<\/TD>.*</TR>"

# create a scraper
htmlScraper = HtmlTableStatusScraper.new(url,lineMatch)
htmlScraper.serverStr = "alfi.soils.wisc.edu"

# set the column-pattern string -- note the "%d"s, they're explained
# below
ColParamRange.rePatStr = 
  "(<(T|t)(D|d)[^<]*</*(T|t)(D|d)[^>]*>){%d,%d}<(T|t)(D|d)[^>]*>(-*\\d+.\\d*)"
#  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|||||||^^^^^^^^^^^^^^^^^|||||||||||
#     regexp for "columns to skip"    # of cols  stuff before   the number
#                                     to skip    number

# if you count the parenthesized expressions in the above, the number we're interested in is inside
# the eighth one
ColParamRange.matchExpIndex = 8

# now comes the neat part. the column names are just used for output; the next 
# number is which column this is in the table (starting with 0); next is min 
# acceptable value, finally max acceptable value. the column number gets plugged
# into the regexp above in place of the "%d"s

htmlScraper.colsToCheck = [
  ColParamRange.new("Pcpn",   1,  0.0,    30.0),
  ColParamRange.new("ET",     2,  0.0,   0.3),
  ColParamRange.new("SolRad", 3,  0.0,    500.0),
  ColParamRange.new("PctClr", 4,  0.0,    100.0),
  ColParamRange.new("MaxTAir",5,  -40.0,  120.0),
  ColParamRange.new("MaxRH",  9,  50.0,   105.0),
  ColParamRange.new("MaxT2in",11, -40.0,  150.0),
  ColParamRange.new("MaxWind",14,  0.0,    85.0),
  ]

# the validate method returns true if the data can be found & are in-range
if ((results['products']["aws"] = htmlScraper.validate) == false)
    htmlErrorMesgs += htmlScraper.errMesg
end
links['products']["aws"] = "/asigServlets/AWSReport"

# now do it again for ASOS; the regexps are simpler because we can pick and choose
# which columns are displayed for this one

# the URL is a little more complicated, since we're doing a query
url = "/asigServlets/AsosReport?ID=KAIG&show_first_line=yes&data_field=date&data_field=NominalTime&data_field=TAir&startyear=#{yr}&startmonth=#{mon}&startday=#{yyday}&endyear=#{yr}&endmonth=#{mon}&endday=#{yday}"

# look for lines with yesterday's date, 9 AM
lineMatch = "#{yr}-0*#{mon}-0*#{yday},\s*09:.*$"
htmlScraper = HtmlTableStatusScraper.new(url,lineMatch)

# search the line for comma, an optional minus sign, one or more digits, a decimal point,
# and zero or more digits 
ColParamRange.rePatStr = ",\s*(-*\\d+\\.*\\d*)"
# there's only one expression in the thing
ColParamRange.matchExpIndex = 1
# we're actually not using the "columns" thing, but i've got "2" in here for mnemonics
htmlScraper.colsToCheck = [
            ColParamRange.new("TAir",    2,  -40.0,  120.0)
            ]

# validate and record results
if ((results['products']["asos"] = htmlScraper.validate) == false)
    htmlErrorMesgs += htmlScraper.errMesg
end
links['products']["asos"] ="http://alfi.soils.wisc.edu/wimnext/asos/SelectHourlyAsos.html"

# Degree-day grids; pretty familiar by now
url = "/asigServlets/DDReport?Latitude=42.0&Longitude=98.0&startyear=#{yr}&startmonth=1&startday=1&endyear=#{yr}&endmonth=#{mon}&endday=#{tday}&method=0&lowthresh=52&upthresh=100&datadump=0"
lineMatch = "<tr><td><center>#{yr}-0*#{mon}-0*#{yday}.*"

htmlScraper = HtmlTableStatusScraper.new(url,lineMatch)
# look for a date column, followed by some number of number columns
ColParamRange.rePatStr = "(<tr><td><center>.*-\\d+</center></td>)((<td><center>)(-*\\d+\\.\\d*)</center></td>){%d,%d}"
ColParamRange.matchExpIndex = 4
htmlScraper.colsToCheck = [
            ColParamRange.new("Max Temp",    1,  -40.0,  120.0),
            ColParamRange.new("Min Temp",    2,  -40.0,  120.0),
            ColParamRange.new("Degree Days", 3,  0.0,    120.0),
            ColParamRange.new("Accum DD",    4,  0.0,    2900.0)
            ]
if ((results['products']["ddreport"] = htmlScraper.validate) == false)
    htmlErrorMesgs += htmlScraper.errMesg
end
links['products']["ddreport"] = url

# daily grid temps report: servlet needs to be line-broken first
# url = "asigServlets/DailyTempReport?Latitude=42.0&Longitude=98.0&show_first_line=no&startyear=2002&startmonth=1&startday=1&endyear=2002&endmonth=6&endday=11"

# check for ET and DD Emails -- BROKEN UNTIL SSL!
etEmail = true
ddEmail = true

# ehc = EmailHeaderChecker.new('facstaff.wisc.edu')
# srchStr = "Subject:\s*ET for #{yr} #{ydoy} at 43.5 -89.25"
# etEmail = ehc.find(srchStr)

# if today.wday == 2
#     srchStr = "Subject:\s*Degree-days for Tuesday, 0*#{today.mon}/0*#{today.mday}/0*#{2000-year}"
#     ddEmail = ehc.find(srchStr)
# else
#     ddEmail = true
# end
# took out dd for now
# resultStr = "aws: #{aws}\nasos: #{asos}\ndd: #{ddreport}\nopu: #{opu}\nopumke: #{opumke}\nETemail: #{etEmail}\nDegree-day emails: #{ddEmail}\n"
# results = aws && asos && ddreport && opu && opumke && etEmail && ddEmail

#
# Check databases: all should have values from yesterday
#

dbNow = Time.new
dbChecker = SQLChecker.new("aws")
stnids = [4781,4751]
awsDB = true
awsBatt = true
stnids.each do |stnid|
    awsDB &= dbChecker.hasYesterday(dbNow,"t_411","theDate","stnid=#{stnid}")
    awsDB &= dbChecker.hasYesterday(dbNow,"t_412","theDate","stnid=#{stnid}")
    awsDB &= dbChecker.hasYesterday(dbNow,"t_403","theDate","stnid=#{stnid}")
    awsBatt &= dbChecker.allLastWeek(dbNow,3600*24,7,"t_411","theDate","stnid=#{stnid} and DMnBatt > 11.90")
end
results['products']["awsDB"] = awsDB
results['products']["awsBatt"] = awsBatt
dbChecker = SQLChecker.new("asos")
results['products']["asosDB"] = dbChecker.hasYesterday(dbNow,"asosData","Date")


# now the various tables in the "grids" database
dbChecker = SQLChecker.new("grids")

#
# ET database won't be up to date in the winter; awswait.pl defines "winter"
# as DOY > 320 || DOY < 85
#
if (today.yday > 84 && today.yday < 321)
	results['products']["gridETDB"] = dbChecker.hasYesterday(dbNow,"WiMnDET","dateStamp")
else
	results['products']["gridETDB"] = true
end
	
# the hourly vapor grid table has no data!
# gridWIHourlyVaprDB = dbChecker.hasYesterday(dbNow,"WiHourlyVapr","dateStamp")
gridWIHourlyVaprDB = true
results['products']["gridWIDAveTAirDB"] = dbChecker.hasYesterday(dbNow,"WiMnDAveTAir","dateStamp")


#
# EMS / FOE
#
url = "/ems/do-login?username=zoopy&password=hoopy"
emsScraper = HtmlStatusScraper.new(url,/ALL AVAILABLE ASSESSMENTS/i)
if ((results['webapps']["ems"] = emsScraper.validate) == false)
    htmlErrorMesgs += emsScraper.errMesg
end
links['webapps']["ems"] = url

url = "/foe/login"
foeScraper = HtmlStatusScraper.new(url,"Why save Energy?")
if ((results['webapps']["foe"] = foeScraper.validate) == false)
    htmlErrorMesgs += foeScraper.errMesg
end
links['webapps']["foe"] = url

#
# GYPSY MOTH
#
# gypsy_moth = system("CheckGrid #{year} #{ydoy} ~asig/products/db/asos/WIMNTAvg#{year}")
# url = "/cgi-bin/asig/gypsymoth.pl?region=BUF&ichill=0&chill=5&ddmethod=1&bbmethod=1&lemethod=1&wopct=40&ropct=20&bopct=10&rmpct=15&smpct=10&abpct=5"
# # something whacky about RE scanning. till I figure it out, just look for date
# # lineMatch = "wimnext\/tree\/tmp\."
# # htmlScraper = SublinkStatusScraper.new(url,lineMatch,80,false,/\/wimnext\/tree\/tmp\..*\.gif/)
# # htmlScraper.serverStr = "www.soils.wisc.edu"
# htmlScraper = HtmlStatusScraper.new(url,"Gypsy Moth Phenology")
# gypsy_moth &= htmlScraper.validate
# if ((results['products']["gypsymoth"] = gypsy_moth) == false)
#    htmlErrorMesgs += htmlScraper.errMesg
# end
# links['products']["gypsymoth"] = url

#
# DAILY DD REPORT
#
dd_url = "http://alfi.soils.wisc.edu/~asig/wiDDs.html"
dd_regexp = Regexp.new(yesterday.strftime("%e %B %Y:"))
daily_dd = HtmlStatusScraper.new(dd_url,dd_regexp,80,false)
daily_dd.serverStr = "alfi.soils.wisc.edu"
if ((results['products']["dailyDDs"] = daily_dd.validate) == false)
  htmlErrorMesgs += daily_dd.errMesg
end
links['products']["dailyDDs"] = dd_url

camScraper = HtmlStatusScraper.new("/halfsize.jpg",".*")
camScraper.serverStr = "128.104.33.220";
# if ((results['products']["webCam"] = camScraper.validate) == false)
#	htmlErrorMesgs += camScraper.errMesg
# end	    

results['products']["awswait"] = false
File.open("/home/asig/heartbeat/awsWaitProc.txt") do |f|
	f.each do |line|
		if (line =~ /awswait.pl/)
			results['products']["awswait"] = true
		end
	end
end

result = true

#
# Check on pyranometer-insol calibration files
# We're looking for the noon (181500.00 Z) value to be non-zero.
# Since George changes the path on these from time to time, and SSEC is
# planning to change login creds to Kang, this is fragile. But hopefully
# it will at least function for now.
#
# Later: Now an unfunded project, so George has pulled the plug. I'll leave the code
# in here just in case of resurrection someday.
# Later still: Resurrected!
# pyro_date = sprintf("%4d%03d",yesteryear,ydoy)
# results['products']["Pyro cal of Diak's model"] = RemoteFileGrepper.check('aws@kang.soils.wisc.edu',
  # "/home5/homer_home2/insol/mcidas/data/CalibSave.with_pyro/CALEAST1.#{pyro_date}",
  # '181500\.00.*[1-9][0-9]*\.[0-9]*$')
# 
# # check that they aren't 'missing value' either
# results['products']["pyro_cal"] &= !(RemoteFileGrepper.check('aws@soils.ssec.wisc.edu',
#   "/home5/homer_home2/insol/mcidas/data/CalibSave.with_pyro/CALEAST1.#{pyro_date}",
#   '181500\.00.*-9+.0+$'))

# Check on Alfi backups; look for at least one success, and that all filesystems at least got attempted
alfi_backup_filesystems = %w(etc lib64 /usr/local httpd /home www)
abd = Date.today
abd_str = "#{abd.month}/#{abd.mday}/#{abd.strftime("%Y")}"
alfi_backup_success = LogChecker.find_in_log('/var/log/retroclient.history',Regexp.new("^#{abd_str}.+successfully$"))
for fs in alfi_backup_filesystems
  alfi_backup_success |= LogChecker.find_in_log('/var/log/retroclient.history',Regexp.new(abd_str + '.+' + fs))
end
results['systems']["Alfi Retrospect Backups"] = alfi_backup_success

# Yesterday's Molly Bucky Backup
today = Date.today; dayname = today.strftime("%a")
yesterday = today - 1
# No backups on Sat or Sun, so no results expected on Sun or Mon
if dayname == "Sun" or dayname == "Mon"
  results['systems']["No #{yesterday.strftime("%a")} Molly B/Us"] = true
else
  mbd_regexp = /^#{yesterday.strftime("%Y-%m-%d")}/
  success_regexp = /Successful incremental backup of '\/'/
  results['systems']["Molly Bucky Backups"]  = LogChecker.find_last_in_log(mbd_regexp,'/home/asig/heartbeat/bucky.log',success_regexp)
end

results['webapps']["cons-train"] = HtmlStatusScraper.new('http://localhost',/Conservation/,9000).validate
links['webapps']["cons-train"] = "http://conservation-training.wisc.edu"
# results['webapps']["Pyro-Model Compare"] = HtmlStatusScraper.new('http://andi.soils.wisc.edu',/Pyranometer/,3000).validate
# links['webapps']["Pyro-Model Compare"] = "http://andi.soils.wisc.edu:3000/"

# Check that the other servers are at least pingable
#  servers_to_check = %w(andi molly a266 alli punkadoodle redbird)
servers_to_check = %w(andi molly a266 alli redbird kang)

for server in servers_to_check
  results['systems']['Ping '+server] = Ping.pingecho(server+'.soils.wisc.edu',5,22) # timeout 5, use SSH port since they all support it
end

other_servers = {
  'cals_sw' => ['144.92.93.185'], 
  'cals_sw_db' => ['144.92.93.187'], 'cals_sw_fw' => ['144.92.93.186'], 'cals_sw_ls' => ['144.92.133.236'],
  'wisp' => ['wisp.cals.wisc.edu',80]
}

other_servers.each do |name,address|
  results['systems']['Ping '+name] = Ping.pingecho(address[0],5,address[1])
end

# Web cam. 
results['systems']['Web Cam'] = Ping.pingecho('128.104.33.220')
links['systems']['Web Cam'] = 'http://128.104.33.220/'

# Check the MMAS server. If the GetFeatureInfo service is working for this (arbitrarily chosen) point, chances are the app is too
mmas = HtmlStatusScraper.new('/geoserver/wms?LAYERS=mmas%3Adtr%2Cmmas%3Acivil%2Cmmas%3Acities%2Cmmas%3Awater%2Cmmas%3Amajorhwy%2Cmmas%3Adot_roads%2Cmmas%3Acounties%2Cmmas%3Adtrs&STYLES=&HEIGHT=575&WIDTH=600&SRS=EPSG%3A3071&FORMAT=image%2Fpng&SERVICE=WMS&VERSION=1.1.1&REQUEST=GetFeatureInfo&EXCEPTIONS=application%2Fvnd.ogc.se_xml&BBOX=531951.081359%2C255265.288907%2C601801.043641%2C322204.836093&X=192&Y=140&INFO_FORMAT=application%2Fvnd.ogc.gml&QUERY_LAYERS=mmas%3Adtr&FEATURE_COUNT=1&srs=EPSG%3A3071&styles=&layers=mmas%3Acivil',/wfs:FeatureCollection/)
mmas.serverStr = 'http://gis.soils.wisc.edu'
results['webapps']["MMAS"] = mmas.validate
links['webapps']["MMAS"] = 'http://www.manureadvisorysystem.wi.gov'

# Check the GeoServer 2 webapp as well. Let's grab, oh, the main runoff-risk page:
ror_timestamp = Date.today.strftime('%b %d')
manure = HtmlStatusScraper.new('/app/events/runoff_forecast',ror_timestamp)
manure.serverStr = '144.92.93.196'
results['webapps']['ROR'] = manure.validate
links['webapps']['ROR'] = 'http://www.manureadvisorysystem.wi.gov/app/events/runoff_forecast'

# Also check the statistics page
manure = HtmlStatusScraper.new('/app/stats/',"BROKEN")
manure.serverStr = 'www.manureadvisorysystem.wi.gov'
results['webapps']['ROR_stats'] = manure.validate(true) # means 'look for the absence of...'
links['webapps']['ROR_stats'] = 'http://www.manureadvisorysystem.wi.gov/app/stats/'

# Display the number of GeoPDFs downloaded from mmas-mapping
geopdf_str = "#{last_months_geopdfs} GeoPDFs downloaded"
results['webapps'][geopdf_str] = true
links['webapps'][geopdf_str] = 'http://mmas-mapping.soils.wisc.edu/usage/'

# Grab the forecast valid time off the runoffrisk page
ror = HtmlStatusScraper.new('/app/events/runoff_forecast','')
ror.serverStr = 'gis.soils.wisc.edu'
ror_timestamp = ''

ror.validate do |data_returned|
    data_returned.scan(Regexp.new(/Forecast updated (.+[AP])M/)) do |line|
        if $1 && $1 != ''
            ror_timestamp = $1 + 'M' 
            break
        end
    end
end



timeStampStr = dbNow.strftime("%d-%b-%y (DOY %j), %H:%m")
resultStr = <<END
<html>
  <head>
    <title>ASIG Systems Status Dashboard at #{timeStampStr} (yesterday was #{yesterday})</title>
    <meta HTTP-EQUIV="Refresh" CONTENT="600"/>
  </head>
<body>
<p>Some notes on what breaks:</p>
<p>If you see just "aws" red, that's likely to be a problem with the AWON download, which is hosted from the Win XP VM on Redbird. That's a pretty Rube Goldberg system at this point, but if the VM isn't running, the download won't.</p>
<p>If "asos" and "aws" are BOTH red, try clicking the links. If you get a 503 error, that means Tomcat on Alfi <a href="https://trac.soils.wisc.edu/trac/meta_info_and_systems/wiki/FixingAlfi">needs to be restarted</a>.</p>
<p>MollyBuckyBackups is often red; my script for detecting problems there has false alarms from time to time. Check the logs in /var/log/tsm if you're worried.</p>
<p>Ping cals_db and Ping cals_sw have been red for awhile, that project should be picking back up soon so I've left them on the dashboard.</p>
<table border="1" style="width: 600px">
END

hdr_table = <<END
<table border="1">
  <tr>
    <td colspan="#{results.length-3}" align="center"><a href="http://agwx.soils.wisc.edu/uwex_agwx/">WIMNExt</a> status at 
    <a href="http://alfi.soils.wisc.edu/cgi-bin/asig/doyCal.rb">#{timeStampStr}</a></td>
    <td><a href="http://usairnet.com/cgi-bin/launch/code.cgi?sta=KMSN&model=avn&state=WI&Submit=Get+Forecast">Meteogram</a></td>
    <td><a href="http://andi.soils.wisc.edu:3000/">Insol Comparison</a></td>
  </tr>
</table>
END

resultStr += hdr_table

hdrcolor = '#FFC'
hdrbgcolor = '#333'
resultStr += '<table border="1" width="800px">'
results.keys.sort.each do |type|
  resultStr += "<tr><th style=\"color: #{hdrcolor}; background-color: #{hdrbgcolor}\" colspan=\"#{MAX_TABLE_COLS}\">#{type.to_s.upcase}</th></tr>\n<tr>"
  cols = 0
  results[type].keys.sort.each do |key|
    result &= results[type][key]
    if results[type][key]
      color = '#9F9' # light green for OK
    else
      color = '#F99' # light red for broken!
    end
    resultStr += "<td style=\"background-color: #{color}\">"
    if ((link = links[type][key]) == nil)
        resultStr += "#{key}</td>"
    else
        resultStr += "<a href=\"#{link}\">#{key}</a></td>"
    end
    cols += 1
    if cols >= MAX_TABLE_COLS
      cols = 0
      resultStr += "</tr><tr>"
    end
  end
end

resultStr += "</tr></table><p/>"

yname = "%04d" % today.year
mname = "%02d" % today.mon
dname = "%02d" % today.mday

yesterday = today - (3600*24)
yesterday_datestamp = "#{yname}-#{mname}-#{dname}"

last_week = yesterday - (7 * (3600*24))
last_week_yname = "%04d" % last_week.year
last_week_mname = "%02d" % last_week.mon
last_week_dname = "%02d" % last_week.mday

last_week_datestamp = "#{last_week_yname}-#{last_week_mname}-#{last_week_dname}"


if ((htmlErrorMesgs <=> "") != 0)
    resultStr += "<br/><h3>HTML Error Messages encountered:</h3> <p>"
    resultStr += htmlErrorMesgs
    resultStr += "</p>"
end
emailResultStr = resultStr
if (email)
  web_cam_pic = " src=\"http://alfi.soils.wisc.edu/~asig/webcam/halfsize.jpg\""
else  
  web_cam_pic = " src=\"http://alfi.soils.wisc.edu/~asig/webcam/fullsize.jpg\""
end

movieURL = "http://alfi.soils.wisc.edu/~asig/webcam/archive/#{yname}/#{mname}/#{dname}/movie.html"

resultStr += <<END
<img src="http://alfi.soils.wisc.edu/wimnext/et/yestWIMNet.gif"/>
<h3>RRAF at #{ror_timestamp}</h3>
<img src="http://gis.soils.wisc.edu/geoserver/wms?LAYERS=mmas:rf_map_0&STYLES=&SRS=EPSG:3071&FORMAT=image/gif&TILED=false&TRANSPARENT=TRUE&SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&BBOX=267255.9375,170674.5,757576.8125,721773.25&WIDTH=512&HEIGHT=512"/>
<div>
  <a href="http://128.104.33.220/">Direct to Web cam</a><br/>
  <a href=\"#{movieURL}\"><img #{web_cam_pic} </a>
</div>
</body></html> 
END

resultStr += <<END
<p>

		<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781&size=big\">
			<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781\"/>
		</a>
		<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751&size=big\">
			<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751\"/>
		</a>
		<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773&size=big\">
			<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773\"/>
		</a>
</p>
END

# Soil Temps too
resultStr += <<END
<p>
<a href=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps?size=big\">
	<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps\"/>
</a>
<a href=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps?size=big&depth=10\">
	<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps?depth=10\"/>
</a>
<a href=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps?size=big&depth=50\">
	<IMG src=\"http://andi.soils.wisc.edu:3000/awon/show_soil_temps?depth=50\"/>
</a>
</p>
END

resultStr += <<END
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781&which=bucket_line&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781&which=bucket_line\">
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751&which=bucket_line&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751&which=bucket_line\">
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773&which=bucket_line&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773&which=bucket_line\">
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781&which=bucket_scatter&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4781&which=bucket_scatter\">
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751&which=bucket_scatter&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4751&which=bucket_scatter\">
<a href=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773&which=bucket_scatter&size=big\"><IMG src=\"http://andi.soils.wisc.edu:3000/awon/show?stn=4773&which=bucket_scatter\">
END

unless email
  resultStr += <<END
  <img src="http://www.crh.noaa.gov/images/ncrfc/data/soiltemp/obfrostDepth.gif"></img>
  <img src="http://www.nohrsc.noaa.gov/interactive/html/map_only.php?var=ssm_swe&dy=#{yr}&dm=#{mon}&dd=#{tday}&dh=18&min_x=-93.566666666668&min_y=42.208333333334&max_x=-85.766666666668&max_y=46.6&bgvar=dem&shdvar=shading&title=0&width=800&height=450&font=0&lbl=m&palette=0&h_o=0&metric=0&o1=1&o9=1&o12=1&o13=1"></img>

<p/>
END
end

# </a><a href=\"http://www.soils.wisc.edu/~asig/heartbeat/arl_rain_compare.gif\"><IMG src=\"http://www.soils.wisc.edu/~asig/heartbeat/thumb_arl_rain_compare.gif\"></a><a href=\"http://andi.soils.wisc.edu:3000/?stn=ARL\"><IMG src=\"http://andi.soils.wisc.edu:3000/compare_plot/show_compare?start_date=#{last_week_datestamp}&end_date=#{yesterday_datestamp}&stn=ARL&start_hour=1&end_hour=24&model_name=SSEC_Production&plot_size=Small\"></a>
# <a href=\"http://www.soils.wisc.edu/~asig/heartbeat/han_rain_by_doy.gif\"><IMG src=\"http://www.soils.wisc.edu/~asig/heartbeat/thumb_han_rain_by_doy.gif\"></a>
# <a href=\"http://www.soils.wisc.edu/~asig/heartbeat/han_rain_compare.gif\"><IMG src=\"http://www.soils.wisc.edu/~asig/heartbeat/thumb_han_rain_compare.gif\"></a><a href=\"http://andi.soils.wisc.edu:3000/?stn=HAN\"><IMG src=\"http://andi.soils.wisc.edu:3000/compare_plot/show_compare?start_date=#{last_week_datestamp}&end_date=#{yesterday_datestamp}&stn=HAN&start_hour=1&end_hour=24&model_name=SSEC_Production&plot_size=Small\"></a>
# </body></html>
# END

if (email)
    if (!result)
        sendAlert(boilToSMS(emailResultStr))
    end
else
    print "#{resultStr}\n"
end    
##################
# SVN LOG (old)
##################
# StatusChecker script
# $Revision: 1.42 $
# $Log: StatusChecker.rb,v $
# Revision 1.42  2007/12/17 16:56:36  wayne
# incorporating new AWON plots
#
# Revision 1.41  2007/09/04 15:24:44  wayne
# i dunno
#
# Revision 1.40  2007/07/25 21:40:03  wayne
# added ET plot to page
#
# Revision 1.39  2006/10/05 14:20:17  wayne
# added HYD database checking, changed webcam IP, added rain bucket and insol comparisons, used HERE document for resultStr
#
# Revision 1.38  2006/08/18 15:34:54  wayne
# visual tweaks
#
# Revision 1.37  2006/08/16 20:29:06  wayne
# some minor tweaks
#
# Revision 1.36  2006/07/18 19:18:47  wayne
# Dialed back gypsymoth checking for a green
#
# Revision 1.35  2005/12/26 21:32:37  wayne
# fixed HTML email; now uses localhost SMTP too
#
# Revision 1.34  2005/12/05 15:31:43  wayne
# currently broken, think it was the last changes to webcam stuff
#
# Revision 1.31  2005/08/25 14:56:11  wayne
# added todays-movie link to webcam image
#
# Revision 1.30  2005/05/18 14:33:28  wayne
# removed ems; added wimnext link
#
# Revision 1.29  2005/03/03 23:14:56  wayne
# changed AWON battery-voltage threshold to 12.01
#
# Revision 1.28  2005/02/23 18:04:40  wayne
# changed URLs to match new servlet layout
#
# Revision 1.27  2004/12/20 17:45:57  wayne
# added optional minus signs for digit-checking patterns
#
# Revision 1.26  2004/12/17 16:35:35  wayne
# memo to self: test, THEN commit!
#
# Revision 1.23  2004/11/12 22:31:07  wayne
# fixed HYD to point to alfi
#
# Revision 1.22  2004/09/22 15:25:42  wayne
# added timestamp to table
#
# Revision 1.21  2004/09/22 15:20:34  wayne
# changed title timestamp to display DOY
#
# Revision 1.20  2004/09/07 18:37:34  wayne
# Upped degree-day limit yet again
#
# Revision 1.19  2004/08/23 16:41:30  wayne
# added all-last-week checking of AWS battery
#
# Revision 1.18  2004/08/23 15:48:55  wayne
# Expanded DD range
#
# Revision 1.17  2004/08/06 18:31:28  wayne
# Added HTML error message buffer
# Removed OPUMKE entirely
# Made EMS checker case-insensitive
#
# Revision 1.16  2004/07/24 17:00:35  wayne
# woops, had debug stuff on
#
# Revision 1.15  2004/07/23 18:27:56  wayne
# production -- now either does report or email depending on
# existence of "email" cmd-line arg (only sends email if
# something's wrong)
#
# Revision 1.14  2004/07/23 18:17:21  wayne
# changed refresh rate to every 600 seconds
#
# Revision 1.13  2004/07/23 18:15:32  wayne
# fixed quotes in meta tag to automagically refresh
#
# Revision 1.12  2004/07/23 18:13:29  wayne
# added meta tag to automagically refresh
#
# Revision 1.11  2004/07/23 17:23:54  wayne
# looks operational
#
# Revision 1.10  2004/07/23 17:23:07  wayne
# looks operational
#
# Revision 1.9  2004/07/23 16:03:32  wayne
# many updates and fixes; now does HTML output and SQL checking
#
# Revision 1.8  2004/03/02 21:31:56  wayne
# Fixed false AWS positives; ET can be < 0.05 and still be good!
#
# Revision 1.7  2004/03/02 21:10:37  wayne
# Further refinements
#
# Revision 1.6  2002/07/18 15:57:35  wayne
# added stuff to check email products and report to me via email
#
# Revision 1.5  2002/07/10 16:13:04  wayne
# Fixed problem with OPU; now won't look for today's OPU until noon. Also made
# @verbose in Html*Scraper an instance variable, and added the grid stuff.
# Modified Files:
# HtmlStatusScraper.rb HtmlTableStatusScraper.rb
# StatusChecker.rb
# Added Files:
# GridStatusChecker.rb grid.rb gridtest.rb
#
# Revision 1.4  2002/07/08 22:56:44  wayne
# Got everything including OPU and OPUMKE going at once (!). Now, on to grids
# and SQL databases directly!
# Modified Files:
# 	ColParamRange.rb HtmlStatusScraper.rb
# 	HtmlTableStatusScraper.rb StatusChecker.rb
#
# Revision 1.3  2002/06/07 16:27:01  wayne
# Now it's AWS, ASOS, and ASOS Degree Days are all working.
#
