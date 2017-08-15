fs = require 'fs'

module.exports =
class AdvancedWebEditorView
  constructor: (serializedState, closeCallback) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('advanced-web-editor')
    #
    template = fs.readFileSync __dirname + '/template/configurationForm.html'
    @element.innerHTML = template

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element
