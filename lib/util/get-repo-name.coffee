module.exports = (uri) ->
  tmp = uri.split('/')
  name = tmp[tmp.length-1]
  tmp = name.split('.')
  [..., last] = tmp
  if last is 'git'
    name = tmp[...-1].join('.')
  else
    name
