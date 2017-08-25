ConfigurationView = require './advanced-web-editor-view'
{CompositeDisposable} = require 'atom'
LifeCycle = require './util/lifecycle'
Configuration = require './util/configuration'
git = require './util/git'

module.exports = AdvancedWebEditor =
  configurationView: null
  panel: null
  subscriptions: null

  consumeToolBar: (getToolBar) ->
    @toolBar = getToolBar('advanced-web-editor')

  initialize: ->

  activate: (state) ->
    console.log "AdvancedWebEditor::activate", state

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:configure': => @configure()

    # Register publishing commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:start': => @commandStartEditing()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:save': => @commandSaveLocally()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:publish': => @commandPublish()

    # @subscriptions.add atom.workspace.observeTextEditors (editor) ->
    #   console.log editor.getPath()

    @subscriptions.add atom.workspace.observeActivePane (pane) ->
      console.log pane

    @subscriptions.add atom.project.onDidChangePaths (paths) ->
      console.log "Atom projects path changed", paths
      console.log atom.project.getRepositories()

    # Check configuration first
    @lifeCycle = new LifeCycle()
    if !@lifeCycle.isConfigurationValid()
      console.log "Configuration required"
      @configure()
    else
      if @lifeCycle.haveToClone()
        @askForClone()
      else
        @doPreStartCheck()
          .then () =>
            @lifeCycle.setupToolbar(@toolBar)
          .fail (e) ->
            console.log e.message, e.stdout
            atom.notifications.addError "Error occurred during initialization",
              description: e.message + "\n" + e.stdout


  deactivate: ->
    @subscriptions.dispose()
    @configurationView?.destroy()
    @panel?.destroy()
    @panel = null
    @toolBar?.removeItems()
    @toolBar = null

  serialize: ->
    # advancedWebEditorViewState: @configurationView.serialize()

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.reloadConfiguration() #reset configuration

  configure: ->
    console.log 'AdvancedWebEditor shown configuration'
    @configurationView = new ConfigurationView(@lifeCycle.getConfiguration(),
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @panel = atom.workspace.addTopPanel(item: @configurationView.getElement(), visible: false) if !@panel?
    @panel.show()

  saveConfig: ->
    console.log "Save configuration"
    confValues = @configurationView.readConfiguration()
    config = @lifeCycle.getConfiguration()
    config.set(confValues)
    validationMessages = config.validateAll().map (k) ->
      Configuration.reasons[k]
    if validationMessages.length == 0
      @lifeCycle.saveConfiguration()
      @hideConfigure()
      if @lifeCycle.haveToClone()
        @askForClone()
    else
      validationMessages.forEach (msg) ->
        atom.notifications.addError(msg)

  askForClone: () ->
    atom.confirm
      message: 'Do you want to clone the repository now?'
      detailedMessage: 'Your repository will be downloaded.'
      buttons:
        Yes: => @doClone()
        No: -> () -> {}

  doClone: () ->
    console.log "doClone"
    configuration = @lifeCycle.getConfiguration()
    git.promisedClone configuration.assembleCloneUrl(), @lifeCycle.whereToClone()
      .then (output) =>
        console.log output
        atom.notifications.addSuccess("Repository cloned succesfully")
        @lifeCycle.openProjectFolder()
      .fail (e) =>
        console.log e
        atom.confirm
          message: 'Error occurred'
          detailedMessage: "An error occurred during git clone:\n#{e.message}\n#{e.stdout}\n\nYou may want to try again or check out your configuration."
          buttons:
            Configure: => @configure()
            Retry: => @doClone()

  checkUncommittedChanges: () ->
    console.log "checkUncommittedChanges"
    return git.promisedStatus(@lifeCycle.whereToClone())
      .then (output) ->
        return output && output.length > 0

  checkUnpublishedChanges: () ->
    console.log "checkUnpublishedChanges"
    git.setProjectIndex @lifeCycle.indexOfProject()
    return git.promisedUnpushedCommits(@lifeCycle.whereToClone())

  doSaveOrPublish: (action) ->
    if action == "commit"
      @lifeCycle.doCommit()
    else if action == "publish"
      @lifeCycle.doPublish()

  commandStartEditing: () ->
    console.log "Command: Start Editing"

  commandSaveLocally: () ->
    console.log "Command: Save Locally"

  commandPublish: () ->
    console.log "Command: Publish"

  doPreStartCheck: () ->
    @lifeCycle.openProjectFolder()
    @checkUncommittedChanges()
      .then (state) =>
        if state
          return {
            state: "unsaved"
          }
        else
          @checkUnpublishedChanges()
            .then (unpublishedBranches) ->
              # console.log unpublishedBranches
              if unpublishedBranches.length > 0
                return {
                  state: "unpublished"
                  branches: unpublishedBranches
                }
              else
                return{
                  state: "ok"
                }
      .then (state) =>
        console.log state
        if state.state != "ok"
          action = 'commit' if state.state == 'unsaved'
          action = 'publish' if state.state == 'unpublished'
          branches = ''
          branches = "Involved branches: " + state.branches.join(",") + ".\n" if state.branches?
          if state != "ok"
            atom.confirm
              message: "Detected #{state.state} changes."
              detailedMessage: "#{branches}Do you want to #{action} them now?"
              buttons:
                Yes: () =>
                  console.log this
                  @doSaveOrPublish(action)
                'Keep editing': -> #do Nothing
        else
          @lifeCycle.updateDevelop()
          @lifeCycle.suggestNewBranchName()
            .then (branch) -> atom.notifications.addInfo "TODO: create branch "+ branch
