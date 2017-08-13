AdvancedWebEditorView = require './advanced-web-editor-view'
{CompositeDisposable} = require 'atom'

module.exports = AdvancedWebEditor =
  advancedWebEditorView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @advancedWebEditorView = new AdvancedWebEditorView(state.advancedWebEditorViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @advancedWebEditorView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @advancedWebEditorView.destroy()

  serialize: ->
    advancedWebEditorViewState: @advancedWebEditorView.serialize()

  toggle: ->
    console.log 'AdvancedWebEditor was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
