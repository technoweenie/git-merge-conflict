{exec} = require 'child_process'
path   = require 'path'
Git    = require 'git-utils'
MergeParser = require 'git-merge-parser'

DEFAULT_BRANCH = "master"

module.exports = (projectPath) ->
  @async()
  if repo = Git.open(projectPath)
    process.on 'message', (message) ->
      checkForConflicts(repo) if message is 'check-for-conflicts'

checkForConflicts = (repo) ->
  workingDirectory = repo.getWorkingDirectory()
  head = repo.getShortHead()

  if head == DEFAULT_BRANCH
    return

  cmd = "git merge-tree `git merge-base #{DEFAULT_BRANCH} #{head}` #{head} #{DEFAULT_BRANCH}"
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
