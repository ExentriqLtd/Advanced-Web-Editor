fs = require 'fs'
path = require 'path'
moment = require 'moment'

{ File } = require 'atom'

git = require 'git-promise'
q = require 'q'
AsyncLock = require 'async-lock'
lock = new AsyncLock()

LOCK_POLL_INTERVAL = 500
LOCK_MAX_RETRIES = 20
FORBIDDEN_BRANCHES = ["master", "develop"]

logcb = (log, error) ->
  console[if error then 'error' else 'log'] log

repo = undefined
cwd = undefined
projectIndex = 0

now = -> moment().format("MMM DD YYYY")

noop = -> q.fcall -> true

lockFile = () -> path.join(cwd, '.git', 'index.lock')

lockFileExists = () ->
  if !cwd
    return false
  lockF = new File(lockFile())
  return lockF.existsSync()

checkLockFileDoesntExist = () ->
  deferred = q.defer()
  retries = 0
  interval = window.setInterval () ->
    # console.log "Lock file exists?"
    if retries >= LOCK_MAX_RETRIES
      # console.log "Giving up"
      window.clearInterval interval
      deferred.reject()
      return

    if !lockFileExists()
      # console.log "No"
      window.clearInterval interval
      deferred.resolve()
    # else
      # console.log "Yes"

    retries++
  , LOCK_MAX_RETRIES

  return deferred.promise

atomRefresh = ->
  # Disabled:
  # repo.refreshStatus() # not public/in docs
  return

getBranches = ->
  branches = local: [], remote: [], tags: []
  return repo.refreshStatus().then () ->
    refs = repo.getReferences()

    for h in refs.heads
      branches.local.push h.replace('refs/heads/', '')

    for h in refs.remotes
      branches.remote.push h.replace('refs/remotes/', '')

      return branches

setProjectIndex = (index) ->
  repo = undefined
  cwd = undefined
  projectIndex = index
  if atom.project
    repo = atom.project.getRepositories()[index]
    cwd = if repo then repo.getWorkingDirectory() #prevent startup errors if repo is undefined
  return
setProjectIndex(projectIndex)

parseDiffBranch = (data) -> q.fcall ->
  return data.split("\n")
    .filter (x) -> x && x.trim && x.trim().length > 0

parseDiff = (data) -> q.fcall ->
  diffs = []
  diff = {}
  for line in data.split('\n') when line.length
    switch
      when /^diff --git /.test(line)
        diff =
          lines: []
          added: 0
          removed: 0
        diff['diff'] = line.replace(/^diff --git /, '')
        diffs.push diff
      when /^index /.test(line)
        diff['index'] = line.replace(/^index /, '')
      when /^--- /.test(line)
        diff['---'] = line.replace(/^--- [a|b]\//, '')
      when /^\+\+\+ /.test(line)
        diff['+++'] = line.replace(/^\+\+\+ [a|b]\//, '')
      else
        diff['lines'].push line
        diff['added']++ if /^\+/.test(line)
        diff['removed']++ if /^-/.test(line)

  return diffs

parseStatus = (data) -> q.fcall ->
  files = []
  for line in data.split('\n') when line.length
    # [type, name] = line.replace(/\ \ /g, ' ').trim().split(' ')
    type = line.substring(0, 2)
    name = line.substring(2).trim().replace(new RegExp('\"', 'g'), '')
    files.push
      name: name
      selected: switch type[type.length - 1]
        when 'C','M','R','D','A' then true
        else false
      type: switch type[type.length - 1]
        when 'A' then 'added'
        when 'C' then 'modified' #'copied'
        when 'D' then 'deleted'
        when 'M' then 'modified'
        when 'R' then 'modified' #'renamed'
        when 'U' then 'conflict'
        when '?' then 'new'
        else 'unknown'

  return files

parseDefault = (data) -> q.fcall ->
  return true

returnAsIs = (data) -> q.fcall ->
  return data

callGit = (cmd, parser, nodatalog) ->
  logcb "> git #{cmd}"

  deferred = q.defer()
  console.log "lock", lock
  lock.acquire "git", (callback) ->
    checkLockFileDoesntExist()
      .then () ->
        git(cmd, {cwd: cwd})
          .then (data) ->
            logcb data unless nodatalog
            deferred.resolve parser(data)
            callback null, true
          .fail (e) ->
            logcb e.stdout, true
            logcb e.message, true
            deferred.reject e
            callback null, true
      .fail () ->
        deferred.reject message: "Git project directory is locked. You may try to delete #{lockFile()} manually"
        callback null, true

  return deferred.promise

module.exports =
  isInitialised: ->
    return cwd

  alert: (text) -> #making the console available elsewhere
    logcb text
    return

  setLogger: (cb) ->
    logcb = cb
    return

  setProjectIndex: setProjectIndex

  getProjectIndex: ->
    return projectIndex

  getRepository: ->
    return repo

  count: (branch) ->
    return repo.getAheadBehindCount(branch)

  getLocalBranch: ->
    return repo.getShortHead()

  getRemoteBranch: ->
    return repo.getUpstreamBranch()

  isMerging: ->
    return fs.existsSync(path.join(repo.path, 'MERGE_HEAD'))

  getBranches: getBranches

  hasRemotes: ->
    refs = repo.getReferences()
    return refs and refs.remotes and refs.remotes.length

  hasOrigin: ->
    return repo.getOriginURL() isnt null

  add: (files) ->
    return noop() unless files.length
    return callGit "add -- #{files.join(' ')}", (data) ->
      atomRefresh()
      return parseDefault(data)

  commitAll: () ->
    message = now()
    return  callGit("add --all", parseDefault).then () ->
      callGit "commit -a -m \"#{message}\"", parseDefault

  commit: (message) ->
    message = message or now()
    message = message.replace(/"/g, '\\"')

    return callGit "commit -m \"#{message}\"", (data) ->
      atomRefresh()
      return parseDefault(data)

  clone: (repo, target, branch) ->
    return callGit "clone -q #{repo} \"#{target}\"", parseDefault if !branch
    return callGit "clone -q -b #{branch} --single-branch #{repo} \"#{target}\"", parseDefault if branch

  checkout: (branch, remote) ->
    return callGit "checkout #{if remote then '--track ' else ''}#{branch}", (data) ->
      atomRefresh()
      return parseDefault(data)

  createBranch: (branch) ->
    return callGit "branch #{branch}", (data) ->
      return callGit "checkout #{branch}", (data) ->
        atomRefresh()
        return parseDefault(data)

  deleteBranch: (branch) ->
    return callGit "branch -d #{branch}", (data) ->
      atomRefresh()
      return parseDefault

  forceDeleteBranch: (branch) ->
    return callGit "branch -D #{branch}", (data) ->
      atomRefresh()
      return parseDefault

  diff: (file) ->
    return callGit "--no-pager diff #{file or ''}", parseDiff, true

  diffBranches: (branch1, branch2) ->
    return callGit "--no-pager diff --name-only #{branch1} #{branch2}", parseDiffBranch

  fetch: ->
    return callGit "fetch --prune", parseDefault

  merge: (branch,noff) ->
    noffOutput = if noff then "--no-ff" else ""
    return callGit "merge #{noffOutput} #{branch}", (data) ->
      atomRefresh()
      return parseDefault(data)

  ptag: (remote) ->
    return callGit "push #{remote} --tags", (data) ->
      atomRefresh()
      return parseDefault(data)

  pullup: ->
    return callGit "pull upstream $(git branch | grep '^\*' | sed -n 's/\*[ ]*//p')", (data) ->
      atomRefresh()
      return parseDefault(data)

  pull: ->
    return callGit "pull", returnAsIs
      # atomRefresh()
      # return parseDefault(data)

  flow: (type,action,branch) ->
    return callGit "flow #{type} #{action} #{branch}", (data) ->
      atomRefresh()
      return parseDefault(data)

  push: (remote,branch,force, setUpstream)->
    forced = if force then "-f" else ""
    upstream = if setUpstream then "--set-upstream" else ""
    cmd = "-c push.default=simple push #{upstream} #{remote} #{branch} #{forced} --porcelain"
    return callGit cmd, noop
      # atomRefresh()
      # return noop(data)

  log: (branch) ->
    return callGit "log origin/#{repo.getUpstreamBranch() or 'master'}..#{branch}", parseDefault

  rebase: (branch) ->
    return callGit "rebase #{branch}", (data) ->
      atomRefresh()
      return parseDefault(data)

  midrebase: (contin,abort,skip) ->
    if contin
      return callGit "rebase --continue", (data) ->
        atomRefresh()
        return parseDefault(data)
    else if abort
      return callGit "rebase --abort", (data) ->
        atomRefresh()
        return parseDefault(data)
    else if skip
      return callGit "rebase --skip", (data) ->
        atomRefresh()
        return parseDefault(data)

  reset: (files) ->
    return callGit "checkout -- #{files.join(' ')}", (data) ->
      atomRefresh()
      return parseDefault(data)

  resetHard: () ->
    return callGit "reset --hard HEAD^", parseDefault

  remove: (files) ->
    return noop() unless files.length
    return callGit "rm -- #{files.join(' ')}", (data) ->
      atomRefresh()
      return parseDefault(true)

  status: ->
    return callGit 'status --porcelain --untracked-files=all', parseStatus

  unpushedCommitBranch: (branch) ->
    return callGit "log origin/#{branch}..#{branch} --oneline", returnAsIs
      .then (output) ->
        return output != ""

  unpushedCommits: () ->
    # get all local branches
    return getBranches().then (branches) =>
      return q.all(branches.local.filter (x) -> x not in FORBIDDEN_BRANCHES
        .map((branch) =>
          return @unpushedCommitBranch(branch)
            .then (hasCommits) ->
              return if hasCommits then branch else undefined
              )).then (branches)->
                return branches.filter (x) -> x

  isCurrentBranchForbidden: () ->
    return repo.getShortHead() in FORBIDDEN_BRANCHES

  getCurrentBranch: () ->
    return repo?.getShortHead()

  pushAll: () ->
    return callGit "-c push.default=simple push --all origin --porcelain", parseDefault

  #Git, create a branch and publish immediately:
  createAndCheckoutBranch: (branch) ->
    return callGit "checkout -b \"#{branch}\"", parseDefault
      .then () ->
        return callGit "push --set-upstream origin \"#{branch}\"", parseDefault

  tag: (name,href,msg) ->
    return callGit "tag -a #{name} -m \"#{msg}\" #{href}", (data) ->
      atomRefresh()
      return parseDefault(data)

  setRemoteUrl: (name, url) ->
    return callGit "remote set-url #{name} #{url}", () ->
      # Do Nothing since no response occur

  gitConfig: (fullName, email) ->
    return callGit "config --global user.name \"#{fullName}\"", parseDefault
      .then () -> callGit "config --global user.email #{email}", parseDefault
      .then () -> callGit "config --global push.default simple", parseDefault
