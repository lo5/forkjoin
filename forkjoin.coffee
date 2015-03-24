
isFunction = (f) -> 'function' is typeof f

isFuture = (a) -> if a?.isFuture then yes else no

head = (a) ->
  if a
    a[0]
  else
    undefined

async = (f) ->
  (args..., go) ->
    try 
      go null, f.apply null, args
    catch error
      go error

fork = (continuable, args=[]) ->
  throw new Error "Not a function." unless isFunction continuable

  _continuations = []

  link = (go) ->
    if isFunction go
      found = no
      for continuation in _continuations
        if continuation is go
          found = yes
      unless found
        _continuations.push go
    return

  propagate = ->
    while go = _continuations.shift()
      if self.rejected
        go self.error
      else
        go null, self.result
    return

  self = (go) ->
    join [ self ], (error, results) ->
      if error
        go error
      else
        go null, head results

  self.evaluate = (go) ->
    link go
    if self.settled
      # proceed with cached error/result
      do propagate
    else if self.evaluating
      # no op
    else
      self.evaluating = yes
      join args, (error, args) ->
        if error
          self.error = error
          self.fulfilled = no
          self.rejected = yes
          self.evaluating = no
          do propagate
        else
          continuable.apply null, args.concat (error, result) ->
            if error
              self.error = error
              self.fulfilled = no
              self.rejected = yes
              self.evaluating = no
              do propagate
            else
              self.result = result
              self.fulfilled = yes
              self.rejected = no
              self.evaluating = no
              do propagate
            self.settled = yes
            self.pending = no

  self.method = continuable
  self.args = args
  self.fulfilled = no
  self.rejected = no
  self.settled = no
  self.pending = yes
  self.evaluating = no
  self.isFuture = yes

  self

join = (args, go) ->
  return go null, [] if args.length is 0

  tasks = [] 
  results = []

  for arg, i in args
    if isFuture arg
      tasks.push future: arg, resultIndex: i
    else
      results[i] = arg

  return go null, results if tasks.length is 0

  resultCount = 0
  settled = no

  tasks.forEach (task) ->
    task.future.evaluate (error, result) ->
      return if settled
      if error
        settled = yes
        go error
      else
        join [ result ], (error, localResults) ->
          if error
            settled = yes
            go error
          else
            results[task.resultIndex] = head localResults
            resultCount++
            if resultCount is tasks.length
              settled = yes
              go null, results
      return
  return

resolve = (args..., go) ->
  join args, (error, results) ->
    go.apply null, [error].concat results

createTask = (continuable) ->
  throw new Error "Not a function." unless isFunction continuable
  (args...) ->
    fork continuable, args

# [ Future<T> ] -> Future<[T]>
seq = (_futures) ->
  fork (go) ->
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

# [ Future<T> ] -> Future<[T]>
collect = (futures) ->
  fork join, [ futures ]

# ([T], ((T) -> Future<T>)) -> Future<[T]>
map = (array, defer) ->
  collect (defer element for element in array)

# ([T], ((T) -> Future<T>)) -> Future<[T]>
forEach = (array, defer) ->
  seq (defer element for element in array)

lift = (futures..., f) ->
  fork (go) ->
    join futures, (error, results) ->
      if error
        go error
      else
        go null, f.apply null, results

forkjoin =
  async: async
  task: createTask
  fork: (continuable, args...) -> fork continuable, args
  join: join
  isFuture: isFuture
  resolve: resolve
  seq: seq
  collect: collect
  map: map
  forEach: forEach
  lift: lift

if window? then window.forkjoin = forkjoin else module.exports = forkjoin

