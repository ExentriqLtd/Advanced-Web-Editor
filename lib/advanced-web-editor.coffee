AdvancedWebEditorView = require './advanced-web-editor-view'
{CompositeDisposable} = require 'atom'
LifeCycle = require './util/lifecycle'
Configuration = require './util/configuration'
git = require './util/git'

module.exports = AdvancedWebEditor =
  advancedWebEditorView: null
  panel: null
  subscriptions: null

  initialize: ->

  activate: (state) ->
    console.log "AdvancedWebEditor::activate", state

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:configure': => @configure()

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
                  console.log unpublishedBranches
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
            action = 'commit' if state.state == 'unsaved'
            action = 'publish' if state.state == 'unpublished'
            branches = ''
            branches = "Involved branches: " + state.branches.join(",") + ". " if state.branches?
            if state != "ok"
              atom.confirm
                message: "Detected #{state.state} changes."
                detailedMessage: "#{branches}Do you want to #{action} them now?"
                buttons:
                  Yes: () =>
                    console.log this
                    @doSaveOrPublish(action)
                  No: -> #do Nothing

          .fail (e) ->
            console.log e.message, e.stdout
            #TODO: handle exception
            noop = () ->
              return


  deactivate: ->
    @subscriptions.dispose()
    @advancedWebEditorView?.destroy()
    @panel?.destroy()
    @panel = null

  serialize: ->
    # advancedWebEditorViewState: @advancedWebEditorView.serialize()

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.reloadConfiguration() #reset configuration

  configure: ->
    console.log 'AdvancedWebEditor shown configuration'
    @advancedWebEditorView = new AdvancedWebEditorView(@lifeCycle.getConfiguration(),
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @panel = atom.workspace.addTopPanel(item: @advancedWebEditorView.getElement(), visible: false) if !@panel?
    @panel.show()

  saveConfig: ->
    console.log "Save configuration"
    confValues = @advancedWebEditorView.readConfiguration()
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
    configuration = @lifeCycle.getConfiguration().get()
    git.promisedClone configuration["repoUrl"], @lifeCycle.whereToClone()
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
    #TODO: check project index if more than one directory is active
    git.setProjectIndex 0
    return git.promisedUnpushedCommits(@lifeCycle.whereToClone())

  doSaveOrPublish: (action) ->
    atom.notifications.addWarning("#{action} to be implemented")
