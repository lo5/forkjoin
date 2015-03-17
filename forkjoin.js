// Generated by CoffeeScript 1.9.1
(function() {
  var async, collect, createTask, fork, forkjoin, isFunction, isFuture, join, seq,
    slice = [].slice;

  isFunction = function(f) {
    return 'function' === typeof f;
  };

  isFuture = function(a) {
    if (a != null ? a.isFuture : void 0) {
      return true;
    } else {
      return false;
    }
  };

  fork = function(f, args) {
    var self;
    if (!isFunction(f)) {
      throw new Error("Not a function.");
    }
    self = function(go) {
      var hasContinuation;
      hasContinuation = isFunction(go);
      if (self.settled) {
        if (self.rejected) {
          if (hasContinuation) {
            return go(self.error);
          }
        } else {
          if (hasContinuation) {
            return go(null, self.result);
          }
        }
      } else {
        return join(args, function(error, args) {
          if (error) {
            self.error = error;
            self.fulfilled = false;
            self.rejected = true;
            if (hasContinuation) {
              return go(error);
            }
          } else {
            return f.apply(null, args.concat(function(error, result) {
              if (error) {
                self.error = error;
                self.fulfilled = false;
                self.rejected = true;
                if (hasContinuation) {
                  go(error);
                }
              } else {
                self.result = result;
                self.fulfilled = true;
                self.rejected = false;
                if (hasContinuation) {
                  go(null, result);
                }
              }
              self.settled = true;
              return self.pending = false;
            }));
          }
        });
      }
    };
    self.method = f;
    self.args = args;
    self.fulfilled = false;
    self.rejected = false;
    self.settled = false;
    self.pending = true;
    self.isFuture = true;
    return self;
  };

  join = function(args, go) {
    var arg, i, j, len, resultCount, results, settled, tasks;
    if (args.length === 0) {
      return go(null, []);
    }
    tasks = [];
    results = [];
    for (i = j = 0, len = args.length; j < len; i = ++j) {
      arg = args[i];
      if (arg != null ? arg.isFuture : void 0) {
        tasks.push({
          future: arg,
          resultIndex: i
        });
      } else {
        results[i] = arg;
      }
    }
    if (tasks.length === 0) {
      return go(null, results);
    }
    resultCount = 0;
    settled = false;
    tasks.forEach(function(task) {
      return task.future.call(null, function(error, result) {
        if (settled) {
          return;
        }
        if (error) {
          settled = true;
          go(error);
        } else {
          results[task.resultIndex] = result;
          resultCount++;
          if (resultCount === tasks.length) {
            settled = true;
            go(null, results);
          }
        }
      });
    });
  };

  createTask = function(f) {
    if (!isFunction(f)) {
      throw new Error("Not a function.");
    }
    return function() {
      var args;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      return fork(f, args);
    };
  };

  async = function(f) {
    return function() {
      var args, error, go, j;
      args = 2 <= arguments.length ? slice.call(arguments, 0, j = arguments.length - 1) : (j = 0, []), go = arguments[j++];
      try {
        return go(null, f.apply(null, args));
      } catch (_error) {
        error = _error;
        return go(error);
      }
    };
  };

  seq = function(_futures) {
    return function(go) {
      var futures, next, results;
      futures = _futures.slice(0);
      results = [];
      next = function() {
        var future;
        future = futures.shift();
        if (future) {
          future(function(error, result) {
            if (error) {
              return go(error);
            } else {
              results.push(result);
              return next();
            }
          });
        } else {
          go(null, results);
        }
      };
      next();
    };
  };

  collect = function(futures) {
    return function(go) {
      var future, i, resultCount, results, settled, tasks;
      tasks = (function() {
        var j, len, results1;
        results1 = [];
        for (i = j = 0, len = futures.length; j < len; i = ++j) {
          future = futures[i];
          results1.push({
            index: i,
            future: future
          });
        }
        return results1;
      })();
      results = new Array(tasks.length);
      resultCount = 0;
      settled = false;
      tasks.forEach(function(task) {
        task.future(function(error, result) {
          if (settled) {
            return;
          }
          if (error) {
            settled = true;
            return go(error);
          } else {
            results[task.index] = result;
            resultCount++;
            if (resultCount === tasks.length) {
              settled = true;
              return go(null, results);
            }
          }
        });
      });
    };
  };

  forkjoin = {
    fork: function() {
      var args, f;
      f = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      return fork(f, args);
    },
    join: function() {
      var args, go, j;
      args = 2 <= arguments.length ? slice.call(arguments, 0, j = arguments.length - 1) : (j = 0, []), go = arguments[j++];
      return join(args, go);
    },
    task: createTask,
    async: async,
    isFuture: isFuture,
    seq: seq,
    collect: collect
  };

  if (typeof window !== "undefined" && window !== null) {
    window.forkjoin = forkjoin;
  } else {
    module.exports = forkjoin;
  }

}).call(this);
