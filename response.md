When using `through`, any function used as [filter](https://github.com/geejs/gulp-tap/blob/master/src/tap.coffee#L42) will be cached. The current caching scheme, simply add a `__tapId` property to the supplied filter function and assign an incremental integer for caching look-up.
```coffeescript
filter.__tapId = ""+id
cache[filter.__tapId] = stream
id += 1
```

If the [filter](https://github.com/geejs/gulp-tap/blob/master/src/tap.coffee#L28)  is used again, it has a `__tapId` property, so we can simply use that property to look-up the cached function.
```coffeescript
if filter.__tapId
  stream = cache[filter.__tapId]
```

### The issue with gulp.dest

`gulp.dest` is just a wrapper for vinyl.fs's [dest function](https://github.com/wearefractal/vinyl-fs/blob/master/lib/dest/index.js#L12). Let's say that we use `gulp.tap` the following way:
```coffeescript
path  = require 'path'
gulp  = require 'gulp'
tap   = require 'gulp-tap'

destinations =
  "scss": "sass"
  "js":   "scripts"
  "img":  "assets/images"

files = ["loongpath/s.scss", "loongpath/js.js", "loongpath/img.png"]

gulp.src files
  .pipe tap where

where = (file, t) ->
  match = (p) ->
    ext = (path.extname p)
      .substr 1 # remove leading "."
    if( ext in ["jpg", "png", "svg", "gif"] )
      ext = "img"
    destinations[ext] or false

  destPath = match file.path

  if destPath
    t.through gulp.dest, [destPath]
```

In the above code our *filter* function is `gulp.dest` and the argument is either **sass/s.scss**, **scripts/js.js** or **assets/images/img.png**. When `gulp.dest` is called and cached in `gulp-tap` the args are only applied once to `gulp.dest`.

```coffeescript
through: (filter, args) ->
  if filter.__tapId
    stream = cache[filter.__tapId]
    cache[filter.__tapId] = null unless stream

    if stream
      #stream.removeAllEvents "error"
    else
      stream = filter.apply(null, args)
      stream.on "error", (err) ->
        tapStream.emit "error", err

      filter.__tapId = ""+id
      cache[filter.__tapId] = stream
      id += 1
      stream.pipe tapStream

    stream.write file
    stream
```

When calling `gulp.dest` the first time, our arguments array is in the `outFolder` argument variable and since the `saveFile` function is returned, we can never change the `outFolder` variable if we catch the function.

```javascript
function dest(outFolder, opt) {
  ...
  var cwd = path.resolve(options.cwd);

  function saveFile (file, enc, cb) {
    var basePath;
    if (typeof outFolder === 'string') {
      basePath = path.resolve(cwd, outFolder);
    }
    ...  
  }
  var stream = through2.obj(saveFile);
  stream.resume();
  return stream;
```

One approach to solve this is by taking the arguments into account when caching. A naive implementation of this can be seen in [commit 00b77e9](https://github.com/dotnetCarpenter/gulp-tap/commit/00b77e922f17da3d099a9624f95208981c7af5ec).

```coffeescript
if filter.__tapId and filter.__tapId.match(/(?:@)(.*)/)[1] is args.join("")
  ...
  filter.__tapId = ""+id+"@"+args.join("")
```

By joining arguments into the `__tapId` we make sure that we never reuse a filter if the arguments has changed. This is of course not an optimal implementation as just we changed the `__tapId` on the *filter* function itself and are not reusing our cache if the arguments change back to something we have seen before. But it does high-light that, using arguments as part of the cache scheme solves the issue.
Another approach would be to remove the cache entirely. To see how much of an impact the cache has on our overall performance, we need to write some tests. I've begun this work in [the test branch](https://github.com/dotnetCarpenter/gulp-tap/tree/tests).

Unfortunately I'm running into problems with [node-debug](https://github.com/node-inspector/node-inspector) and `console.log` with the latest `nodejs` update, v0.10.35.
