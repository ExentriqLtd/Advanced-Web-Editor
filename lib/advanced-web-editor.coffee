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

    @lifeCycle = new LifeCycle()
    if !@lifeCycle.isConfigurationValid()
      console.log "Configuration required"
      @configure()
    else
      if @lifeCycle.haveToClone()
        @askForClone()
      else
        @lifeCycle.openProjectFolder()

  deactivate: ->
    @panel.destroy()
    @panel = null
    @subscriptions.dispose()
    @advancedWebEditorView.destroy()

  serialize: ->
    # advancedWebEditorViewState: @advancedWebEditorView.serialize()

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.getConfiguration().read() #reset configuration

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
      config.save()
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
      .then (output) ->
        console.log output
        atom.notifications.addSuccess("Repository cloned succesfully")
        @lifeCycle.openProjectFolder()
      .fail (e) =>
        console.log e
        atom.confirm
          message: 'Error occurred'
          detailedMessage: "An error occurred during git clone:\n#{e.message}\n\nYou may want to try again or check out your configuration."
          buttons:
            Configure: => @configure()
            Retry: => @doClone()
