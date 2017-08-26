class FormView extends HTMLElement

  initialize: () ->
    @classList.add("awe-configuration")
    # panel body
    panelBody = document.createElement("div")
    panelBody.classList.add("panel-body")
    @appendChild(panelBody)

    # table
    table = document.createElement("table")
    panelBody.appendChild(table)

    # table body
    @tableBody = document.createElement("tbody")
    table.appendChild(@tableBody)

    @fields = []
    @rows = []

  addRow: (row) ->
    @tableBody.appendChild row

  createFieldRow: (id, type, label, options) ->
    row = document.createElement("tr")
    row.classList.add("native-key-bindings") # workaround Atom bug
    row.appendChild @createLabel(id, label)
    row.appendChild @createField(id, type, null, options)
    return row

  createLabel: (id, caption, cssClass) ->
    td = document.createElement("td")
    label = document.createElement("label")
    label.innerText = caption
    label.classList.add(cssClass) if cssClass?
    label.setAttribute "for", id
    td.appendChild label
    return td

  # For type == "select", expect options as array of
  # {value: 123, text: "XXXX"}
  createField: (id, type, cssClass, options) ->
    td = document.createElement("td")
    field = document.createElement("input") if type != "select"
    field = document.createElement("select") if type == "select"
    field.id = id

    @fields.push field

    field.setAttribute("type", if type != "directory" then type else "text")
    field.classList.add(cssClass) if cssClass?

    if type == "directory"
      field.setAttribute "readonly", true
      field.addEventListener "click", () ->
        atom.pickFolder (folder) ->
          if(folder)
            field.value = folder

    if type == "select"
      # console.log "Adding options"
      options.forEach (option) ->
        # console.log "Adding option", option
        opt = document.createElement("option")
        opt.value = option
        opt.text = option
        field.appendChild opt

    td.appendChild field
    # console.log "Created field", field, field.id
    return td

  reset: ->
    @fields.forEach (x) ->
      type = x.getAttribute("type")
      x.value = "" if type in ["text","password"]
      x.checked = false if type in ["checkbox"]

  setValues: (data) ->
    @reset()
    Object.keys(data).forEach (k) =>
      field = @fields.find (x) -> x.id == k
      field?.value = data[k] if field?.getAttribute("type") in ["text","password","select"]
      field?.checked = data[k] if field?.getAttribute("type") == "checkbox"

  getValues: () ->
    values = {}
    @fields.forEach (x) ->
      type = x.getAttribute("type")
      values[x.id] = x.value if type in ["text","password","select"]
      values[x.id] = (x.checked == true) if type == "checkbox"
    # console.log values
    return values

module.exports = FormView
