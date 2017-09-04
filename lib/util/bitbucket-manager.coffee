API_URL = 'https://api.bitbucket.org/2.0/repositories/'

request = require 'request'
q = require 'q'

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

  buildAuth: () ->
    return {
      "user": @bitBucketUsername
      "pass": @bitBucketPassword
      "sendImmediately": true
    }


  # /maprtech/mapr.com-content/pullrequests
  getPullRequests: (repoOwner, repoName) ->
    deferred = q.defer()
    url = "#{API_URL}#{repoOwner}/#{repoName}/pullrequests?pagelen=50"
    options =
      url: url
      auth: @buildAuth()
      json: true

    request.get options, (error, response, body) ->
      try
        console.log "API returned:", body
        deferred.resolve transformResponse(body)
      catch error
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
    url = "#{API_URL}#{repoOwner}/#{repoName}/refs/branches?pagelen=100"
    options =
      url: url
      auth: @buildAuth()
      json: true

    request.get options, (error, response, body) ->
      try
        console.log "API returned:", body
        deferred.resolve transformBranchResponse(body)
      catch error
        deferred.reject error

    return deferred.promise

  getRepoSize: (repoOwner, repoName) ->
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
      catch error
        deferred.reject error

    return deferred.promise

module.exports = BitBucketManager
