FormView = require './form-view'

class PleaseWaitView extends FormView

  constructor: () ->

  initialize: (label) ->
    super
    @addRow @createTitleRow label


module.exports = document.registerElement 'awe-please-wait-view',
  prototype: PleaseWaitView.prototype, extends: 'div'
