BranchFormView = require './util/branch-form-view'
ButtonDecorator = require './button-decorator'

class BranchView extends ButtonDecorator
  constructor: (branches, existingBranchCallback, newBranchCallback) ->
    @form = new BranchFormView()
    console.log "In branch view", branches
    @form.initialize branches

    buttons = [
      {label: "Use Existing Branch", callback: (name) => existingBranchCallback @form.getValues().branch}
      {label: "Create New Branch", callback: newBranchCallback}
    ]

    super @form, buttons

module.exports = BranchView
