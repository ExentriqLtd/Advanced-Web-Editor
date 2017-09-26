FormView = require './form-view'

class ProgressView extends FormView

  constructor: () ->

  initialize: (label) ->
    super
    if !label
      label = "Downloading repository..."
    @label = label
    @addRow @createFieldRow("progress", "progress", @label)

  setProgress: (valuePercent) ->
    progress = @fields.find (f) -> f.getAttribute("type") == "progress"
    label = @fields.find (f) -> f.id == progress.id + "_label"

    if !progress
      return
    # console.log @fields, progress
    valuePercent = Math.min(valuePercent, 100.0)
    if valuePercent > progress.value
      progress.value = valuePercent

      if label
        label.innerText = @formatProgress(valuePercent)

module.exports = document.registerElement 'awe-progress-view',
  prototype: ProgressView.prototype, extends: 'div'
