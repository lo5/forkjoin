
isFunction = (f) -> 'function' is typeof f

isFuture = (a) -> if a?.isFuture then yes else no

fork = (f, args) ->
  throw new Error "Not a function." unless isFunction f
  self = (go) ->
    hasContinuation = isFunction go
    if self.settled
      # proceed with cached error/result
      if self.rejected
        go self.error if hasContinuation
      else
        go null, self.result if hasContinuation
    else
      join args, (error, args) ->
        if error
          self.error = error
          self.fulfilled = no
          self.rejected = yes
          go error if hasContinuation
        else
          f.apply null,
            args.concat (error, result) ->
              if error
                self.error = error
                self.fulfilled = no
                self.rejected = yes
                go error if hasContinuation
              else
                self.result = result
                self.fulfilled = yes
                self.rejected = no
                go null, result if hasContinuation
              self.settled = yes
              self.pending = no

  self.method = f
  self.args = args
  self.fulfilled = no
  self.rejected = no
  self.settled = no
  self.pending = yes

  self.isFuture = yes

  self

join = (args, go) ->
  return go null, [] if args.length is 0

  tasks = [] 
  results = []

  for arg, i in args
    if arg?.isFuture
      tasks.push future: arg, resultIndex: i
    else
      results[i] = arg

  return go null, results if tasks.length is 0

  resultCount = 0
  settled = no

  tasks.forEach (task) ->
    task.future.call null, (error, result) ->
      return if settled
      if error
        settled = yes
        go error
      else
        results[task.resultIndex] = result
        resultCount++
        if resultCount is tasks.length
          settled = yes
          go null, results
      return
  return

createTask = (f) ->
  throw new Error "Not a function." unless isFunction f
  (args...) ->
    fork f, args

async = (f) ->
  (args..., go) ->
    try 
      go null, f.apply null, args
    catch error
      go error

seq = (_futures) ->
  (go) ->
    futures = _futures.slice 0
    results = [] 
    next = ->
      future = futures.shift()
      if future
        future (error, result) ->
          if error
            go error
          else
            results.push result
            do next
      else
        go null, results
      return
    do next
    return

collect = (futures) ->
  (go) ->
    tasks = for future, i in futures
      index: i
      future: future

    results = new Array tasks.length
    resultCount = 0
    settled = no
    tasks.forEach (task) ->
      task.future (error, result) ->
        return if settled
        if error
          settled = yes
          go error
        else
          results[task.index] = result
          resultCount++
          if resultCount is tasks.length
            settled = yes
            go null, results
      return
    return

forkjoin =
  fork: (f, args...) -> fork f, args
  join: (args..., go) -> join args, go
  task: createTask
  async: async
  isFuture: isFuture
  seq: seq
  collect: collect

if window? then window.forkjoin = forkjoin else module.exports = forkjoin

