{CompositeDisposable, Task} = require 'atom'

subscriptions = null
conflictsTask = null
markers = []
editors = {}

module.exports =
  activate: ->
    subscriptions = new CompositeDisposable()
    subscriptions.add atom.workspace.observeTextEditors (editor) ->
      editors[editor.getPath()] = editor
      subscriptions.add editor.onDidStopChanging ->
        checkMergeConflicts()
      subscriptions.add editor.onDidChangePath ->
        editors[editor.getPath()] = editor

    checkMergeConflicts()

  deactivate: ->
    subscriptions?.dispose()
    conflictsTask?.terminate()
    destroyMarkers()

destroyMarkers = ->
  marker.destroy() for marker in markers
  markers = []

createTask = ->
  unless conflictsTask?
    [projectPath] = atom.project.getPaths()
    if projectPath
      conflictsTask = new Task(require.resolve('./conflict-task'))
      conflictsTask.start(projectPath)
      conflictsTask.on('merge-conflict', addConflict)
  conflictsTask.send('check-for-conflicts')

addConflict = (conflict) ->
  editor = editors[conflict.path]
  return unless editor?

  for lineNumber in conflict.conflicted
    conflictRange = [[lineNumber, 0], [lineNumber, 0]]
    marker = editor.markBufferRange(conflictRange, invalidate: 'never', persistent: false)
    markers.push(marker)
    editor.decorateMarker(marker, type: 'gutter', class: 'git-merge-conflict')

checkMergeConflicts = ->
  destroyMarkers()
  createTask()
