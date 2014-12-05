GitMergeConflictView = require './git-merge-conflict-view'
{CompositeDisposable} = require 'atom'

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
    console.log 'GitMergeConflict was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
