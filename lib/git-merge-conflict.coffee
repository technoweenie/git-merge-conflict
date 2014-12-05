GitMergeConflictView = require './git-merge-conflict-view'
{CompositeDisposable} = require 'atom'
exec = require('child_process').exec

module.exports = GitMergeConflict =
  gitMergeConflictView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @gitMergeConflictView = new GitMergeConflictView(state.gitMergeConflictViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @gitMergeConflictView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'git-merge-conflict:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @gitMergeConflictView.destroy()

  serialize: ->
    gitMergeConflictViewState: @gitMergeConflictView.serialize()

  toggle: ->
    repo = atom.project.getRepositories()[0]
    dir = atom.project.getDirectories()[0]
    head = repo.getShortHead()

    cmd = "git merge-tree `git merge-base master #{head}` #{head} master"
    opt =
      cwd: dir.getRealPathSync()
    exec cmd, opt, (error, stdout, stderr) ->
      if error
        console.log "ERROR"
        console.log error
      else
        parseMergeTree stdout

modes =
  1: (merge, line) ->
    merge.current or= {head: [], lines: {}, pos: 0, content: []}
    if line.startsWith "@@"
      @[2](merge, line)
    else
      merge.current.head.push line
      1

  # @@ -1,4 +1,8 @@
  2: (merge, line) ->
    match = line.match /@@ -(\d+)(,(\d+))? \+(\d+)(,(\d+))? @@/
    if !match
      console.log "BAD:", line
      return 1
    merge.current.lines =
      minus: {lower: parseInt(match[1] or 0), upper: parseInt(match[3]) or 0}
      plus: {lower: parseInt(match[4] or 0), upper: parseInt(match[6]) or 0}
    3

  3: (merge, line) ->
    merge.current.content.push line
    merge.current.pos += 1
    if merge.current.pos >= merge.current.lines.plus.upper
      merge.hunks.push finishMergeHunk(merge.current)
      merge.current = null
      1
    else
      3

parseMergeTree = (text) ->
  merge = {hunks: []}
  mode = 1
  for line in text.split "\n"
    mode = modes[mode](merge, line)
  finishMergeTree merge
  console.log merge

hunkModes =
  1: (conflicted, lineNum, line) ->
    if line.startsWith "+<<<<<<<"
      return 2
    1
  2: (conflicted, lineNum, line) ->
    if line.startsWith "+======="
      return 3
    conflicted.push lineNum
    2
  3: (conflicted, lineNum, line) ->
    if line.startsWith "+>>>>>>>"
      return 1
    3

finishMergeHunk = (hunk) ->
  hunk.head = hunk.head.join("\n")
  hunk.content = hunk.content.join("\n")
  mode = 1
  lineNum = hunk.lines.minus.lower
  conflicted = []
  for line in hunk.content.split "\n"
    console.log mode, lineNum, line
    nextMode = hunkModes[mode](conflicted, lineNum, line)
    if mode != nextMode
      mode = nextMode
    else
      lineNum = lineNum + 1
  console.log conflicted
  hunk

finishMergeTree = (merge) ->
  merge.current = null
