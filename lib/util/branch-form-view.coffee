FormView = require './form-view'

class BranchFormView extends FormView

  constructor: () ->

  initialize: (branches) ->
    # console.log "BranchFormView::initialize", branches
    super
    @addRow @createFieldRow("branch", "select", "Choose your branch", branches)

module.exports = document.registerElement('awe-branch-form-view', prototype: BranchFormView.prototype, extends: 'div')
