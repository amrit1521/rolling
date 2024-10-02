APP = window.APP
APP.Controllers.controller('ViewReceipts', ['$scope', '$sce', '$modalInstance', 'application', 'State', ($scope, $sce, $modalInstance, application, State) ->
  $scope.showCreditCard = false

  $scope.init = ->
    $scope.application = application
    receiptIndex = {}
    licenses = []
    licensesYearIndex = {}

    if application.hunts?.length
      for hunt in application.hunts
        if hunt.receipt?.length
          receiptIndex[hunt.receipt] ?= []
          receiptIndex[hunt.receipt].push hunt.name

        if hunt.license?.length
          receiptIndex[hunt.license] ?= []
          receiptIndex[hunt.license].push {name: hunt.name, year: hunt.year}

        if hunt.licenses?.length
          for license in hunt.licenses
            licenses.push license if license?.length and not ~licenses.indexOf(license)
            licensesYearIndex[license] = hunt.year


    if application.receipts?.length
      for receipt in application.receipts
        receiptIndex[receipt.receipt] ?= [{year: receipt.year, name: 'Receipt'}] if receipt.receipt?.length
        receiptIndex[receipt.license] ?= [{year: receipt.year, name: 'License'}] if receipt.license?.length

        if receipt.licenses?.length
          for license in receipt.licenses
            # name = if license then license else 'License'
            licenses.push license if license?.length and not ~licenses.indexOf(license)
            licensesYearIndex[license] = receipt.year

        for hunt in application.hunts
          if hunt._id is receipt.huntId or (receipt.huntIds?.length and hunt._id in receipt.huntIds)
            receiptIndex[receipt.receipt].push {name: hunt.name, year: receipt.year} if receipt.receipt?.length
            if receipt.license?.length
              name = if hunt.name then hunt.name else 'License'
              receiptIndex[receipt.license].push {name, year: receipt.year}

    receipts = []
    for receipt, data of receiptIndex
      animals = []
      year = ''
      data.map (animal) ->
        if animal.name
          animals.push animal.name
        year = animal.year if animal.year
        return

      receipts.push {
        name: animals.shift() + ': ' + animals.join(', ')
        year: year
        url: receipt
      }

    $scope.receipts = receipts
    $scope.licenses = licenses
    $scope.licensesYearIndex = licensesYearIndex

  $scope.cancel = ->
    $modalInstance.dismiss('cancel')

  $scope.init.call(@)
])
