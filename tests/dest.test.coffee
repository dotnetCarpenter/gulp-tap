fs    = require 'fs'
path  = require 'path'
gulp  = require 'gulp'
tap   = require '../lib/tap'

deleteDirectory = (p) ->
  if fs.existsSync p
    fs.readdirSync(p).forEach (file) ->
      curP = (p + "/" + file)
      if fs.lstatSync(curP).isDirectory()
        deleteDirectory curP
      else
        fs.unlinkSync curP
    fs.rmdirSync p

exports.tapTest =

  tearDown: (callback) ->
    deleteDirectory "assets"
    deleteDirectory "scripts"
  #  deleteDirectory "sass"
    callback()

  'gulp-tap can change dest in the middle of stream': (test) ->
    destinations =
      "scss": "sass"
      "js":   "scripts"
      "img":  "assets/images"

    # helper function to get a path relative to the root
    getPath = (rel) -> path.resolve __dirname, "..", rel

    fixturePath = getPath "tests/fixtures/"

    fs.readdir fixturePath, (err, files) ->
      test.expect 2
      if err
        test.ok no, "Can not read fixtures"
        test.done(err)

      gulp.src files.map (p) -> (fixturePath + "/" + p)
        .pipe tap where
        .on "end", ->
          test.ok fs.existsSync getPath "assets/images/img.png"
          test.ok fs.existsSync getPath "scripts/js.js"
    #      test.ok fs.existsSync getPath "sass/s.scss"
          test.done()
        .on "error", (err) -> test.done(err)

    where = (file, t) ->
      match = (p) ->
        ext = (path.extname p)
          .substr 1 # remove leading "."
        if( ext in ["jpg", "png", "svg", "gif"] )
          ext = "img"
        destinations[ext] or false

      destPath = match file.path

    #  console.log "destPath", destPath, file.path

      if destPath
        t.through gulp.dest, [destPath]
