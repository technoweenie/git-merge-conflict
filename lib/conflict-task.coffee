{exec} = require 'child_process'
path   = require 'path'
Git    = require 'git-utils'

repo = null

module.exports = (projectPath) ->
  @async()
  if repo = Git.open(projectPath)
    process.on 'message', (message) ->
      checkForConflicts() if message is 'check-for-conflicts'

checkForConflicts = ->
  workingDirectory = repo.getWorkingDirectory()
  head = repo.getShortHead()

  cmd = "git merge-tree `git merge-base master #{head}` #{head} master"
  opt = cwd: workingDirectory
  exec cmd, opt, (error, stdout, stderr) ->
    parseMergeTree(stdout) unless error?

modes =
  1: (merge, line) ->
    if line.indexOf("@@") is 0
      @[2](merge, line)
    else
      merge.current or= {head: [], lines: {}, pos: 0, content: []}
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

hunkModes =
  1: (conflicted, lineNum, line) ->
    if line.indexOf("+<<<<<<<") is 0
      return 2
    1
  2: (conflicted, lineNum, line) ->
    if line.indexOf("+=======") is 0
      return 3
    conflicted.push lineNum - 1
    2
  3: (conflicted, lineNum, line) ->
    if line.indexOf("+>>>>>>>") is 0
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
  hunk.conflicted = conflicted
  hunk

finishMergeTree = (merge) ->
  delete merge.current
  for entry in merge.hunks
    lines = entry.head.split('\n')
    segments = lines[lines.length - 1].split(' ')
    name = segments[segments.length - 1]
    conflict =
      conflicted: entry.conflicted
      path: path.join(repo.getWorkingDirectory(), name)
    @emit('merge-conflict', conflict)
