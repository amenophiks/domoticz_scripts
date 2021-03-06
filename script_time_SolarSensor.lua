  
--[[      Virtual Lux sensor and other real-time solar data
 
    ~/domoticz/scripts/lua/script_time_SolarSensor.lua
 
    -- Autors  ----------------------------------------------------------------
    V1.0 - Sébastien Joly - Great original work
    V1.1 - Neutrino - Adaptation to Domoticz
    V1.2 - Jmleglise - An acceptable approximation of the lux below 1° altitude for Dawn and dusk + translation + several changes to be more userfriendly.
    V1.3 - Jmleglise - keep the time of black night in lasptUpdate
    ]]--
 
    -- Variables to customize ------------------------------------------------
       local city = "Paris"            -- Your city for Wunderground API
       local cityId = "zmw:00000.65.07156"            -- Your city for Wunderground API
       local countryCode = "FR"            -- Your country code for Wunderground API
       local idxLux ='104'            -- Your virtual Lux Device ID
       local idxSolarAzimuth ='105'       -- Your virtual Azimuth Device ID
       local idxSolarAltitude ='106'       -- Your virtual Solar Altitude Device ID
       local idxUserVarOcta='8'           -- Your user variable ID , named octa
       local wuAPIkey = "f5d71dc5da531d17" -- Your Weather Underground API Key
       local latitude = 48.8088104        -- your home
       local longitude = 2.3049647       -- your home
       local altitude = 47              -- Your home altitude : run once in debug = 1 to found your altitude in Log and write it here
       local WMOID = '07145'    -- Your nearest SYNOP Station for ogimet (to get Cloud layer). Run once with debug=1 to get it in the log. (or, better, choose it there : http://www.ogimet.com/gsynop_nav.phtml.en )
       local DEBUG = 0             -- 0 , 1 for domoticz log , 2 for file log
       -- and customize the URL of api.wunderground around line 104 according to your country.
 
    -- Below , edit at your own risk ------------------------------------------

    function leapYear(year)   
       return year%4==0 and (year%100~=0 or year%400==0)
    end
 
    function split(s, delimiter)   
       result = {};
       for match in (s..delimiter):gmatch("(.-)"..delimiter) do
         table.insert(result, match);
       end
       return result;
    end
 
    function round(num, dec)
       if num == 0 then
         return 0
       else
         local mult = 10^(dec or 0)
         return math.floor(num * mult + 0.5) / mult
       end
    end
 
    commandArray = {}
 
    time = os.date("*t")
    if  ((time.min % 15)==0)  then -- Run every 5 minutes. Check the wundergroud API limitation before changing this
 
       json = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")()  -- For Linux
       --json = (loadfile "D:\\Domoticz\\scripts\\lua\\json.lua")()  -- For Windows
 
       local indexArray=0
       local arbitraryTwilightLux=4.74     -- W/m²  egal 600 Lux
       local constantSolarRadiation = 1361 -- Solar Constant W/m²
 
       if (uservariables['octa'] == nil) then print("Error : Did you create the Uservariable octa ?") end
       --  API Wunderground
       --local config=assert(io.popen('curl http://api.wunderground.com/api/'..wuAPIkey..'/conditions/q/'..countryCode..'/'..city..'.json'))  -- customize here !!
       local config=assert(io.popen('curl http://api.wunderground.com/api/'..wuAPIkey..'/conditions/q/'..cityId..'.json'))  -- customize here !!
       local location = config:read('*all')
       config:close()
       local jsonLocation = json:decode(location)
       if( DEBUG == 1) then
          local latitude = jsonLocation.current_observation.display_location.latitude
          local longitude = jsonLocation.current_observation.display_location.longitude
          local altitude = jsonLocation.current_observation.display_location.elevation
          print('Lat: '..latitude..'Long: '..longitude..'Alt: '..altitude)
       end
       relativePressure = jsonLocation.current_observation.pressure_mb
       ----------------------------------
       local year = os.date("%Y")
       local numOfDay = os.date("%j")
       if  leapYear(year) == true then   
          nbDaysInYear = 366  -- How many days in the year ?
       else
          nbDaysInYear = 365
       end
 
       angularSpeed = 360/365.25
       local Declinaison = math.deg(math.asin(0.3978 * math.sin(math.rad(angularSpeed) *(numOfDay - (81 - 2 * math.sin((math.rad(angularSpeed) * (numOfDay - 2))))))))
       timeDecimal = (os.date("!%H") + os.date("!%M") / 60) -- Coordinated Universal Time  (UTC)
       solarHour = timeDecimal + (4 * longitude / 60 )    -- The solar Hour
       hourlyAngle = 15 * ( 12 - solarHour )          -- hourly Angle of the sun
       sunAltitude = math.deg(math.asin(math.sin(math.rad(latitude))* math.sin(math.rad(Declinaison)) + math.cos(math.rad(latitude)) * math.cos(math.rad(Declinaison)) * math.cos(math.rad(hourlyAngle))))-- the height of the sun in degree, compared with the horizon
 
       local azimuth = math.acos((math.sin(math.rad(Declinaison)) - math.sin(math.rad(latitude)) * math.sin(math.rad(sunAltitude))) / (math.cos(math.rad(latitude)) * math.cos(math.rad(sunAltitude) ))) * 180 / math.pi -- deviation of the sun from the North, in degree
       local sinAzimuth = (math.cos(math.rad(Declinaison)) * math.sin(math.rad(hourlyAngle))) / math.cos(math.rad(sunAltitude))
       if(sinAzimuth<0) then azimuth=360-azimuth end
       sunstrokeDuration = math.deg(2/15 * math.acos(- math.tan(math.rad(latitude)) * math.tan(math.rad(Declinaison)))) -- duration of sunstroke in the day . Not used in this calculation.
       RadiationAtm = constantSolarRadiation * (1 +0.034 * math.cos( math.rad( 360 * numOfDay / nbDaysInYear )))    -- Sun radiation  (in W/m²) in the entrance of atmosphere.
       -- Coefficient of mitigation M
       absolutePressure = relativePressure - round((altitude/ 8.3),1) -- hPa
       sinusSunAltitude = math.sin(math.rad(sunAltitude))
       M0 = math.sqrt(1229 + math.pow(614 * sinusSunAltitude,2)) - 614 * sinusSunAltitude
       M = M0 * relativePressure/absolutePressure
 
       if (DEBUG == 1) then
          print('<b style="color:Blue"==============  SUN  LOG ==================</b>')
          print(os.date("%Y-%m-%d %H:%M:%S", os.time()))
          print(city .. ", latitude:" .. latitude .. ", longitude:" .. longitude)
          print("Home altitude = " .. tostring(altitude) .. " m")
          print("number Of Day = " .. numOfDay)     
          if nbDaysInYear==366 then
             print(year .." is a leap year !")
          else
             print(year.." is not a leap year")
          end
          print("Angular Speed = " .. angularSpeed .. " per day")
          print("Declinaison = " .. Declinaison .. "°")
          print("Universel Coordinated Time (UTC)".. timeDecimal .." H.dd")
          print("Solar Hour ".. solarHour .." H.dd")
          print("Altitude of the sun = " .. sunAltitude .. "°")
          print("Angular hourly = ".. hourlyAngle .. "°")
          print("Azimuth of the sun = " .. azimuth .. "°")
          print("Duration of the sunstroke of the day = " .. round(sunstrokeDuration,2) .." H.dd")  -- not used
          print("Radiation max en atmosphere = " .. round(RadiationAtm,2) .. " W/m²")
          print("Local relative pressure = " .. relativePressure .. " hPa")
          print("Absolute pressure in atmosphere = " .. absolutePressure .. " hPa")
          print("Coefficient of mitigation M = " .. M .." M0:"..M0)
       end
 
       -- Get  SYNOP  message from  Ogimet web  site
       hourUTCminus1 = os.date("!%H")-1
       if string.len(hourUTCminus1) == 1 then
          hourUTCminus1 = "0" .. hourUTCminus1
       end
       UTC = os.date("%Y%m%d").. hourUTCminus1.."00" -- os.date("!%M")
       if (DEBUG == 1) then
          local WMOID = jsonLocation.current_observation.display_location.wmo
       end
 
       cmd='curl "http://www.ogimet.com/cgi-bin/getsynop?block='..WMOID..'&begin='..UTC..'"'
       if( DEBUG == 1) then print(cmd) end
       local ogimet=assert(io.popen(cmd))
       local synop = ogimet:read('*all')
       ogimet:close()
       if( DEBUG == 1) then print('ogimet:'..synop) end
 
       if string.find(synop,"Status: 500") == nil
       then   
          rslt = split(synop,",")
          CodeStation = rslt[1]
          rslt = split(synop, " "..CodeStation.. " ")
          Trame = string.gsub(rslt[2], "=", "")
          Trame = CodeStation .." ".. Trame
          rslt = split(Trame, " ")
          Octa = string.sub(rslt[3], 1, 1)  -- 3rd char is the cloud layer.  0=no cloud , 1-8= cloudy from 1 to 8 max , 9 =Fog , / = no data
          if Octa == "/" then   -- not defined ? take the previous value
             Octa = uservariables['octa']
          elseif Octa == "9" then
             Octa = 8
          end
       else
          Octa = uservariables['octa']
       end
       --commandArray['Variable:octa']=tostring(Octa)  -- store the  octa variable
       --os.execute('curl "http://127.0.0.1:8081/json.htm?type=command&param=updateuservariable&idx='..idxUserVarOcta..'&vname=octa&vtype=0&vvalue='..tostring(Octa)..'"')
       commandArray[indexArray] = {['Variable:octa'] = tostring(Octa)}
       indexArray=indexArray+1
 
       Kc=1-0.75*math.pow(Octa/8,3.4)  -- Factor of mitigation for the cloud layer
 
       if sunAltitude > 1 then -- Below 1° of Altitude , the formulae reach their limit of precision.
          directRadiation = RadiationAtm * math.pow(0.6,M) * sinusSunAltitude
          scatteredRadiation = RadiationAtm * (0.271 - 0.294 * math.pow(0.6,M)) * sinusSunAltitude
          totalRadiation = scatteredRadiation + directRadiation
          Lux = totalRadiation / 0.0079  -- Radiation in Lux. 1 Lux = 0,0079 W/m²
          weightedLux = Lux * Kc   -- radiation of the Sun with the cloud layer
       elseif sunAltitude <= 1 and sunAltitude >= -6  then -- apply theoretical Lux of twilight
          directRadiation = 0
          scatteredRadiation = 0
          arbitraryTwilightLux=arbitraryTwilightLux-(1-sunAltitude)/7*arbitraryTwilightLux
          totalRadiation = scatteredRadiation + directRadiation + arbitraryTwilightLux 
          Lux = totalRadiation / 0.0079  -- Radiation in Lux. 1 Lux = 0,0079 W/m²
          weightedLux = Lux * Kc   -- radiation of the Sun with the cloud layer
       elseif sunAltitude < -6 then  -- no management of nautical and astronomical twilight...
          directRadiation = 0
          scatteredRadiation = 0
          totalRadiation = 0
          Lux = 0
          weightedLux = 0  --  should be around 3,2 Lux for the nautic twilight. Nevertheless.
       end
 
       if (DEBUG == 1) then   
          print("Station SYNOP = " .. WMOID)
          print( Octa .. " Octa")
          print("Kc = " .. Kc)
          print("Direct Radiation = ".. round(directRadiation,2) .." W/m²")
          print("Scattered Radiation = ".. round(scatteredRadiation,2) .." W/m²")
          print("Total radiation = " .. round(totalRadiation,2) .." W/m²")
          print("Total Radiation in lux = ".. round(Lux,2).." Lux")
          print("and at last, Total weighted lux  = ".. round(weightedLux,2).." Lux")   
        end
       -- cmd='curl "http://127.0.0.1:8081/json.htm?type=command&param=udevice&idx='..idxLux..'&svalue='..tostring(round(weightedLux,0))..'"'
       -- if( DEBUG == 1) then print(cmd) end
       -- os.execute(cmd)
 
	if tonumber(otherdevices_svalues['Lux'])+round(weightedLux,0)>0   -- No update if Lux is already 0. So lastUpdate of the sensor switch will keep the time of day when Lux has reached 0. (Kind of timeofday['SunsetInMinutes'])
	then
		commandArray[indexArray] = {['UpdateDevice'] = idxLux..'|0|'..tostring(round(weightedLux,0))}
		indexArray=indexArray+1
	end
       commandArray[indexArray] = {['UpdateDevice'] = idxSolarAzimuth..'|0|'..tostring(round(azimuth,0))} 
       indexArray=indexArray+1
       commandArray[indexArray] = {['UpdateDevice'] = idxSolarAltitude..'|0|'..tostring(round(sunAltitude,0))}
       indexArray=indexArray+1
 
       if (DEBUG == 2) then
          logDebug=os.date("%Y-%m-%d %H:%M:%S",os.time())
          logDebug=logDebug.." Azimuth:" .. azimuth .. " Height:" .. sunAltitude
          logDebug=logDebug.." Octa:" .. Octa.."  KC:".. Kc
          logDebug=logDebug.." Direct:"..directRadiation.." inDirect:"..scatteredRadiation.." TotalRadiation:"..totalRadiation.." LuxCloud:".. round(weightedLux,2)
          os.execute('echo '..logDebug..' >>logSun.txt')  -- Windows platform !!
       end
    end
    return commandArray
