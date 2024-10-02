APP = window.APP
APP.Directives.directive('mobileDatePicker', ['$rootScope', '$parse', ($rootScope, $parse) ->
  {
    restrict : 'A'
    require: '?ngModel'

    link: (scope, element, attrs, ngModel) ->
      return unless ngModel

      pickDOB = ->

        options =
          date: new Date(1980, 0, 1, 0, 0, 0, 0)
          mode: "date"

        datePicker.show options, (date) ->

          scope.$apply ->
            theDate = moment(date).format('MM/DD/YYYY')
            $parse(attrs.ngModel).assign(scope, theDate);
            element.blur()

      checkDatePicker = (gadget) ->
        gadget ?= scope.device

        doPicker = false
        if gadget?.platform?.toLowerCase() is 'android'
          try
            doPicker = true if datePicker
          catch err

        if doPicker
          element.on 'click', pickDOB
        else
          element.attr 'type', 'date'

      if not scope.device and scope.isPhonegap
        $rootScope.$on 'deviceready', ($event, gadget) ->
          checkDatePicker gadget
      else
        checkDatePicker()

  }
])
