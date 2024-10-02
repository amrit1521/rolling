APP = window.APP
APP.Controllers.controller('Sportsmans', ['$scope',  '$location', 'Storage', 'User', 'Utah', ($scope,  $location, Storage, User, Utah) ->
#  $scope.sportsmanHunts = [
#    {id: 'ctl00_CPH1_dgChoices_ctl02_Answer1', hcHunt: 9000, hcChoice: 7900, description: 'Black Bear Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl03_Answer1', hcHunt: 1500, hcChoice: 1900, description: 'Deer Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl04_Answer1', hcHunt: 2500, hcChoice: 5900, description: 'Pronghorn Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl05_Answer1', hcHunt: 3500, hcChoice: 3900, description: 'Elk Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl06_Answer1', hcHunt: 8500, hcChoice: 6490, description: 'Moose Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl07_Answer1', hcHunt: 9600, hcChoice: 7950, description: 'Cougar Permit', season: 'Season Authorized in the 2013-2014 Cougar Guidebook', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl08_Answer1', hcHunt: 4500, hcChoice: 6690, description: 'Desert Bighorn Sheep Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl08_Answer1', hcHunt: 6500, hcChoice: 6590, description: 'Bison Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl10_Answer1', hcHunt: 7500, hcChoice: 6890, description: 'Rocky Mountain Goat Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl11_Answer1', hcHunt: 5500, hcChoice: 6790, description: 'Rocky Mountain Sheep Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'},
#    {id: 'ctl00_CPH1_dgChoices_ctl12_Answer1', hcHunt: 100, hcChoice: 9900, description: 'Wild Turkey Permit', season: '2014 Season Authorized by the Wildlife Board', fee: '10.00'}
#  ]

  $scope.init = () ->
    sportsmanHunts = Utah.eligibility ->
      console.log "sportsmanHunts:", sportsmanHunts
      $scope.sportsmanHunts = sportsmanHunts

  $scope.init.call(@)
])
