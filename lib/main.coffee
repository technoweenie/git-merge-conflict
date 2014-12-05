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
      editorSubscriptions = new CompositeDisposable()
      editorSubscriptions.add editor.onDidStopChanging ->
        checkMergeConflicts()
      editorSubscriptions.add editor.onDidChangePath ->
        editors[editor.getPath()] = editor
      editorSubscriptions.add editor.onDidDestroy ->
        delete editors[editor.getPath()]
        editorSubscriptions.dispose()

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
