APP = window.APP
APP.Services.factory('KendoFiles', [ 'User', (User) ->

  class KendoFiles
    files: []
    maxFileSize: 10485760 #10MB
    onSuccessCB: null


    init: (elementId, tFiles, saveUrl, removeUrl, maxFileSize, onSuccessCB) ->
      @files = []
      @onSuccessCB = onSuccessCB
      @maxFileSize = maxFileSize if maxFileSize
      if tFiles?.length
        for tFile in tFiles
          tFile.name = tFile.originalName
          @files.push tFile

      angular.element(elementId).kendoUpload
        async:
          saveUrl: saveUrl
          removeUrl: removeUrl
          autoUpload: false
        dropZone: ".dropZone"
        cancel: @onCancel
        complete: @onComplete
        error: @onError
        progress: @onProgress
        remove: @onRemove
        select: @onSelect
        success: @onSuccess
        upload: @onUpload
        files: @files if @files
        validation: {
          maxFileSize: @maxFileSize
        }
      return

    getFileInfo = (e) ->
      $.map(e.files, (file) ->
        info = file.name
        # File size is not available in all browsers
        if file.size > 0
          info += ' (' + Math.ceil(file.size / 1024) + ' KB)'
        info
      ).join ', '

    onSelect = (e) ->
      console.log 'Select :: ' + getFileInfo(e)
      return

    onUpload = (e) ->
      console.log 'Upload :: ' + getFileInfo(e)
      return

    onSuccess = (e) ->
      console.log 'Success (' + e.operation + ') :: ' + getFileInfo(e)
      @onSuccess() if @onSuccess
      return

    onError = (e) ->
      console.log 'Error (' + e.operation + ') :: ' + getFileInfo(e)
      return

    onComplete = (e) ->
      console.log 'Complete'
      return

    onCancel = (e) ->
      console.log 'Cancel :: ' + getFileInfo(e)
      return

    onRemove = (e) ->
      console.log 'Remove :: ' + getFileInfo(e)
      return

    onProgress = (e) ->
      console.log 'Upload progress :: ' + e.percentComplete + '% :: ' + getFileInfo(e)
      return

  kendoFiles = new KendoFiles()
  return kendoFiles
])
