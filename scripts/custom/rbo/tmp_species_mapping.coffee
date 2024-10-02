_ = require 'underscore'
async = require "async"
config = require '../../../config'
moment    = require 'moment'

#example:  ./node_modules/coffeescript/bin/coffee scripts/custom/rbo/tmp_species_mapping.coffee
#example:  coffee scripts/custom/rbo/tmp_species_mapping.coffee


config.resolve (
  logger
  Secure
  User
  Tenant
  HuntinFoolState
) ->

  TENANTID = "5684a2fc68e9aa863e7bf182" #RBO LIVE
  #TENANTID = "5bd75eec2ee0370c43bc3ec7" #RBO TEST

  userAppTotal = 0
  userAppCount = 0
  master_species_list = []
  master_missing_species_list = []
  typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

  tRRADS_SPECIES_LIST = ["Brown Bear","Grizzly Bear","Tule Elk","Crappie Fish","Bass Fish","Pike Fish","Jumbo Whitefish Fish","Perch Fish","Rainbow Trout Fish","Salmon Fish","Halibut Fish","Merriam Turkey","Osceola Turkey","North American Alligator","Trout Fish","Canine","Ibex","Sharptail Grouse","Roosevelt Elk","Himalayan Tahr","North American Sheep","Whitetail Deer","Ocelot","California Bighorn","Dall Sheep","Mule Deer","Kudu","Desert Sheep","Fannin Sheep","Kamchatka Snow Sheep","Coues Whitetail Deer","Sitka Blacktail Deer","Red Stag Deer","Hog","Tahr","Cape Buffalo","Asiatic Water Buffalo","Gemsbuck","Impala","Blue Wildebeest","Sable","Springbok","Aoudad Sheep","Warthog","Pheasant","White Quail","Prairie Chicken","Blue Grouse","Crocodile","Bear","Black Bear","Cougar","Rocky Mountain Bighorn Sheep","Cow Elk","Wild Boar","Waterfowl","Varmit","Vacation","Upland Bird","Turkey","African Cats","Alligator","Tur","North American Deer","Moose","Hippo","Fish","Elk","Chamois","Bison","Pronghorn","Lynx","Lion","Leopard","Cheetah","Woods Bison","Barren Ground Caribou","Central Barren Ground","Mountain Caribou","Quebec Labrador Caribou","Newfoundland Caribou","Polar Bear","Alaska Yukon Moose","Shiras Moose","Canada Moose","Eastern Canada Moose","Greenland Muskox","Canada Muskox","Alaska Muskox","Bobcat","Alpine Chamois","Anatolian Chamois","Balkan Chamois","Pyrenean Chamois","Cantabrian Chamois","Caucasian Chamois","Chartreuse Chamois","Carpathian Chamois","Low Tantra Chamois","Bukharan Markhor","Astor Markhor","Sulaiman Markhor","Kashmir Markhor","Mid-Caucasian Tur","Western or Kuban Tur","Dagestan Tur","Marco Polo Argali","Russian Snow Sheep","Altay Argali","Hungay Argali","Gobi Argali","Karaganda Argali","Matisoni Argali","Sair Argali","Severtzov Argali","Kara Tau Argali","Stone Sheep","Koryak Snow Sheep","Chukotka Snow Sheep","Kolyma Snow Sheep","Puturana Snow Sheep","Columbia Blacktail Deer","Columbia Whitetail Deer","Axis Deer","Rusa Deer","Fallow Deer","Sambar Deer","Mid-Asian Ibex","Himalayan Ibex","Asiatic Wolf","Gray Wolf","Plains Bison","Rocky Mountain Elk","North American Cats","Blackbuck","Tien Shan Marco Polo Argali","Hume Marco Polo Argali","Yakutia Snow Sheep","Rocky Mountain Goat","Muskox","International Deer","Barbary Sheep","Argali Sheep","Bezoar","Sindh Ibex","Kri Kri Ibex","Nubian Ibex","Punjab Urial","Persian Ibex","Alpine Ibex","Southeastern Ibex","Altay Ibex","Gobi Ibex","Becite Ibex","Gredos Ibex","Ronda Ibex","Afgan Urial","Urial Sheep","Blanford Urial","Transcaspian Urial","Himalayan Blue Sheep","Chinese Blue Sheep","Red Sheep","Armenian Mouflon Sheep","Konya Mouflon Sheep","Anatolian Wild Boar","Russian Wild Boar","Forest Buffalo","Savannah Buffalo","Bongo","Lord Derby Eland","Livingston Eland","Roe Deer","Addax","Nilgai","Cape Eland","East African Eland","Bushbuck","Mountain Kudu","Nyala","Mountain Nyala","Sitatunga","Scimitar Oryx","Arabian Oryx","Gazelle","Waterbuck","Black Wildebeest","Hartebeest","Lechwe","Kob","Oribi","Roan","Duiker","Blesbuck","Clipspringer","Topi","Korrigum","Canada Goose","Ducks","Snow Goose","Prairie Dog","Marmot","Squirrel","Baboon","Monkey","Dingo","Coyote","Fox","Hyena","Giant Forest Hog","Bush Pig","Feral Pig","Mountain Gazelle","Whitetail Gazelle","Okhotsk Snow Sheep","Eastern Turkey","Zebra","Antelope","Spiral Horn Antelope","Rhino","Mouflon Sheep","Markhor","Giraffe","Caribou","Elephant","Buffalo","Blue Sheep"]
  RRADS_SPECIES_LIST = []
  for trsl in tRRADS_SPECIES_LIST
    RRADS_SPECIES_LIST.push trsl.toLowerCase()

  NRADS_RRADS_MAPPING = {
    'deer': "North American Deer"
    'bighorn sheep': "Rocky Mountain Bighorn Sheep"
    'sheep': "North American Sheep"
    'mountain lion': "Cougar"
    'aoudad (barbary) sheep': "Aoudad Sheep"
    'coues deer': "Coues Whitetail Deer"
    #'mountain goat': ""
    'blacktail deer': "Sitka Blacktail Deer"
    #'wolf': ""
    'duck': "waterfowl"
  }

  skipList = "5bd7607b02c467db3f70eda2,570419ee2ef94ac9688392b0" #TEST ENV clientId: 'VD2', LIVE clientID: RB1'

  console.log "DEBUG: process.argv: ", process.argv

  processApp = (hfs, done) ->
    userAppCount++
    console.log "****************************************Processing #{userAppCount} of #{userAppTotal}, ClientId: #{hfs.client_id}, UserId: #{hfs.userId}, Year: #{hfs.year}"
    if skipList.indexOf(hfs._id.toString()) > -1
      console.log "SKIPPING HFS app from skip list!"
      return done null

    keys = Object.keys(hfs)
    for key in keys
      if key.indexOf("species_picked") > -1
        tSpecies = hfs[key]
        for ts in tSpecies
          master_species_list.push ts if master_species_list.indexOf(ts) == -1
          #console.log "DEBUG: master_species_list: ", master_species_list.length
    return done null, hfs



  getApps = (tenantId, cb) ->
    conditions = {
      tenantId: tenantId
    }
    console.log "DEBUG: query conditions", JSON.stringify(conditions)
    HuntinFoolState.find(conditions).lean().exec (err, results) ->
      cb err, results

  async.waterfall [
    # Get apps
    (next) ->
      getApps TENANTID, (err, apps) ->
        return next err, apps

    # For each app, do stuff
    (apps, next) ->
      apps = [apps] unless typeIsArray apps
      console.log "found #{apps.length} apps"
      userAppTotal = apps.length
      async.mapSeries apps, processApp, (err, results) ->
        return next err, results

    (results, next) ->
      #RUN MAPPING on NRADS list so it will match RRADS list
      t_master_species_list = []
      for ms in master_species_list
        if NRADS_RRADS_MAPPING[ms.toLowerCase()]
          t_master_species_list.push NRADS_RRADS_MAPPING[ms.toLowerCase()]
        else
          t_master_species_list.push ms
      master_species_list = t_master_species_list

      return next null, results

    (results, next) ->
      for ms in master_species_list
        if RRADS_SPECIES_LIST.indexOf(ms.toLowerCase()) == -1 and master_missing_species_list.indexOf(ms) == -1
          master_missing_species_list.push ms
      return next null, results

  ], (err, results) ->
    console.log "Finished"
    console.log "NRADS Species List: ", master_species_list
    console.log "NRADS Species List Length: ", master_species_list.length
    console.log "RADS Species List: ", RRADS_SPECIES_LIST
    console.log "RADS Species List Length: ", RRADS_SPECIES_LIST.length
    console.log "Missing Species List: ", master_missing_species_list
    console.log "Missing Species List Length: ", master_missing_species_list.length
    if err
      logger.error "Found an error", err
      process.exit(1)
    else
      console.log "Done"
      process.exit(0)
