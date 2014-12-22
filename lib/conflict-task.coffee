{exec} = require 'child_process'
path   = require 'path'
Git    = require 'git-utils'
MergeParser = require 'git-merge-parser'

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
    if error?
      console.log "ERROR: #{error}"
      return

    conflicts = MergeParser.parse stdout
    for name, file of conflicts.files
      event =
        conflicted: []
        path: path.join(workingDirectory, name)
      for num in file.conflictedLines
        event.conflicted.push num - 1
      @emit 'merge-conflict', event
