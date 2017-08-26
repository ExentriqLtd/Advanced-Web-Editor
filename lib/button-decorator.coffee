
class ButtonDecorator

  constructor: (formView, buttons) ->
    @element = document.createElement('div')
    @element.classList.add('advanced-web-editor')
    @form = formView
    @element.appendChild @form
    @element.appendChild document.createElement('hr')
    buttonsDiv = document.createElement('div')
    buttonsDiv.classList.add("awe-buttons")

    buttons.forEach (b) =>
      buttonsDiv.appendChild @createButton(b.label, b.callback)

    @element.appendChild buttonsDiv

  createButton: (label, callback) ->
    @button = document.createElement('input')
    @button.setAttribute("type", "button")
    @button.classList.add("awe-button")
    @button.value = label
    @button.addEventListener "click", callback if callback?
    return @button

  getElement: ->
    @element

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

module.exports = ButtonDecorator
