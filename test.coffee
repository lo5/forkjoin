test = require 'tape'
fj = require './forkjoin.js'

isFunction = (f) -> 'function' is typeof f

test 'async', (t) ->
  t.plan 2
  add = fj.async (a, b) -> a + b
  t.ok isFunction add
  add 36, 6, (error, result) -> t.equal 42, result

test 'async - failure', (t) ->
  t.plan 1
  add = fj.async (a, b) -> throw new Error 'meh'
  add 36, 6, (error, result) -> t.equal error.message, 'meh'

test 'isFuture', (t) ->
  t.plan 7

  t.notOk fj.isFuture undefined
  t.notOk fj.isFuture null
  t.notOk fj.isFuture {}
  t.notOk fj.isFuture 42
  t.notOk fj.isFuture 'foo'
  t.notOk fj.isFuture new Date()

  add = fj.task (a, b, go) -> go null, a + b
  sum = add 36, 6
  t.ok fj.isFuture sum

test 'fork non-function', (t) ->
  t.plan 1
  t.throws -> fj.fork undefined

test 'task non-function', (t) ->
  t.plan 1
  t.throws -> fj.task undefined

test 'task - fulfilled', (t) ->
  t.plan 26

  add = fj.task (a, b, go) -> go null, a + b
  sum = add 36, 6

  t.ok isFunction sum.method
  t.deepEqual sum.args, [ 36, 6 ]
  t.ok sum.error is undefined
  t.ok sum.result is undefined
  t.equal sum.isFuture, yes
  t.equal sum.fulfilled, no
  t.equal sum.rejected, no
  t.equal sum.settled, no
  t.equal sum.pending, yes

  # evaluate
  sum (error, result) ->
    t.equal error, null
    t.equal 42, result
  t.ok sum.error is undefined
  t.ok sum.result is 42
  t.equal sum.fulfilled, yes
  t.equal sum.rejected, no
  t.equal sum.settled, yes
  t.equal sum.pending, no

  # evaluate again
  sum (error, result) ->
    t.equal error, null
    t.equal 42, result
  t.ok sum.error is undefined
  t.ok sum.error is undefined
  t.ok sum.result is 42
  t.equal sum.fulfilled, yes
  t.equal sum.rejected, no
  t.equal sum.settled, yes
  t.equal sum.pending, no

test 'task - rejected', (t) ->
  t.plan 25

  add = fj.task (a, b, go) -> go new Error 'meh'
  sum = add 36, 6

  t.ok isFunction sum.method
  t.deepEqual sum.args, [ 36, 6 ]
  t.ok sum.error is undefined
  t.ok sum.result is undefined
  t.equal sum.isFuture, yes
  t.equal sum.fulfilled, no
  t.equal sum.rejected, no
  t.equal sum.settled, no
  t.equal sum.pending, yes

  # evaluate
  sum (error, result) -> 
    t.equal error.message, 'meh'
    t.ok result is undefined

  t.ok sum.error.message, 'meh'
  t.ok sum.result is undefined
  t.equal sum.fulfilled, no
  t.equal sum.rejected, yes
  t.equal sum.settled, yes
  t.equal sum.pending, no
  
  # evaluate again
  sum (error, result) -> 
    t.equal error.message, 'meh'
    t.ok result is undefined

  t.ok sum.error.message, 'meh'
  t.ok sum.result is undefined
  t.equal sum.fulfilled, no
  t.equal sum.rejected, yes
  t.equal sum.settled, yes
  t.equal sum.pending, no

test 'join - empty', (t) ->
  t.plan 2
  fj.join (error, result) ->
    t.equal error, null
    t.deepEqual result, []

test 'task - futures', (t) ->
  t.plan 2

  uppercase = fj.task (a, go) -> go null, a.toUpperCase()
  concat = fj.task (a, b, go) -> go null, a + b

  foo = uppercase 'foo'
  bar = uppercase 'bar'
  foobar = concat foo, bar

  foobar (error, result) ->
    t.equal error, null
    t.equal result, 'FOOBAR'

test 'task - failing futures', (t) ->
  t.plan 1

  uppercase = fj.task (a, go) -> go new Error 'meh'
  concat = fj.task (a, b, go) -> go null, a + b

  foo = uppercase 'foo'
  bar = uppercase 'bar'
  foobar = concat foo, bar

  foobar (error, result) ->
    t.equal error.message, 'meh'
  

test 'seq', (t) ->
  t.plan 2

  words = [ 'qux', 'quux', 'quuux' ]
  lengthOf = fj.task (a, go) -> go null, a.length
  wordAt = fj.task (i, go) -> go null, words[i]

  wordLengths = fj.seq (lengthOf wordAt i for i in [0 ... 3])

  wordLengths (error, wordLengths) ->
    t.equal error, null
    t.deepEqual wordLengths, [ 3, 4, 5 ]


test 'collect', (t) ->
  t.plan 2

  words = [ 'qux', 'quux', 'quuux' ]
  lengthOf = fj.task (a, go) -> go null, a.length
  wordAt = fj.task (i, go) -> go null, words[i]

  wordLengths = fj.collect (lengthOf wordAt i for i in [0 ... 3])

  wordLengths (error, wordLengths) ->
    t.equal error, null
    t.deepEqual wordLengths, [ 3, 4, 5 ]


test 'seq - failing futures', (t) ->
  t.plan 1

  words = [ 'qux', 'quux', 'quuux' ]
  lengthOf = fj.task (a, go) -> go null, a.length
  wordAt = fj.task (i, go) -> go new Error 'meh'

  wordLengths = fj.seq (lengthOf wordAt i for i in [0 ... 3])

  wordLengths (error, wordLengths) ->
    t.equal error.message, 'meh'


test 'collect - failing futures', (t) ->
  t.plan 1

  words = [ 'qux', 'quux', 'quuux' ]
  lengthOf = fj.task (a, go) -> go null, a.length
  wordAt = fj.task (i, go) -> go new Error 'meh'

  wordLengths = fj.collect (lengthOf wordAt i for i in [0 ... 3])

  wordLengths (error, wordLengths) ->
    t.equal error.message, 'meh'