API_URL = 'https://api.bitbucket.org/2.0/repositories/'

request = require 'request'
q = require 'q'

PAGE_SIZE = 50

transformResponse = (body) ->
  if !body
    return []
  return body.values.map (x) ->
    return {
      author: x.author.username
      from: x.source.branch.name
      to: x.destination.branch.name
      title: x.title
      state: x.state
      close_source_branch: x.close_source_branch
    }

transformBranchResponse = (body) ->
  if !body
    return []
  return body.values.map (x) -> x.name

class BitBucketManager

  constructor: (@bitBucketUsername, @bitBucketPassword) ->
    # console.log "BitBucketManager::constructor", @bitBucketUsername, @bitBucketPassword

  buildAuth: () ->
    return {
      "user": @bitBucketUsername
      "pass": @bitBucketPassword
      "sendImmediately": true
    }

  _get: (url) ->
    deferred = q.defer()
    options =
      url: url
      auth: @buildAuth()
      json: true

    request.get options, (error, response, body) ->
      try
        console.log "_get got", url, body
        if error
          deferred.reject "Error occurred, Resource #{url}"
        else if response && response.statusCode != 200
          deferred.reject "HTTP error #{response.statusCode}, Resource #{url}"
        else
          deferred.resolve body
      catch e
        deferred.reject e

    return deferred.promise

  invokeTillHasNext: (url, transformFunction) ->
    deferred = q.defer()
    location= "#{url}?pagelen=#{PAGE_SIZE}"

    #First invocation to know how many items we have
    @_get(location)
      .then (body) =>
        firstPage = transformFunction(body)
        if !body.next
          deferred.resolve firstPage
        else
          pages = Math.ceil(body.size / PAGE_SIZE)
          promises = []
          promises.push(@_get(location + "&page=#{i}")) for i in [2 .. pages]

          q.all(promises).then (resultBodies) ->
            results = resultBodies.map (x) -> transformFunction(x)
            toMerge = firstPage.concat(results)
            deferred.resolve [].concat.apply([], toMerge)
      .fail (error) ->
        deferred.reject error

      return deferred.promise

  # /maprtech/mapr.com-content/pullrequests
  getPullRequests: (repoOwner, repoName) ->
    deferred = q.defer()
    url = "#{API_URL}#{repoOwner}/#{repoName}/pullrequests"

    @invokeTillHasNext(url, transformResponse).then (result) ->
      deferred.resolve result
    .fail (error) ->
      deferred.reject error

    return deferred.promise

  createPullRequest: (title, description, repoOwner, repoName, fromBranch, toBranch) ->
    deferred = q.defer()
    url = "#{API_URL}#{repoOwner}/#{repoName}/pullrequests"

    options =
      url: url
      auth: @buildAuth()
      json: true
      body:
        title: title
        description: description
        source:
          branch:
            name: fromBranch
          repository:
            full_name: "#{repoOwner}/#{repoName}"
        destination:
          branch:
            name: toBranch
        close_source_branch: true

    console.log "BitBucketManager::createPullRequest", options

    request.post options, (error, response, body) ->
      try
        console.log "API returned:", body
        deferred.resolve body
      catch error
        deferred.reject error

    return deferred.promise

  getBranches: (repoOwner, repoName) ->
    deferred = q.defer()
    url = "#{API_URL}#{repoOwner}/#{repoName}/refs/branches"

    @invokeTillHasNext(url, transformBranchResponse).then (result) ->
      deferred.resolve result
    .fail (error) ->
      deferred.reject error

    return deferred.promise

  getRepoSize: (repoOwner, repoName) ->
    # console.log "BitBucketManager::getRepoSize", repoOwner, repoName
    deferred = q.defer()
    url = "#{API_URL}#{repoOwner}/#{repoName}"
    options =
      url: url
      auth: @buildAuth()
      json: true

    request.get options, (error, response, body) ->
      console.log options, error, response, body
      try
        console.log "API returned:", body
        deferred.resolve body.size
      catch e
        deferred.reject e

    return deferred.promise

module.exports = BitBucketManager
