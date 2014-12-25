ES = require('event-stream')
baseStream = require('stream')

###
# Taps into the pipeline and allows user to easily route data through
# another stream or change content.
###
module.exports = (lambda) ->
  utils = (tapStream, file) ->

    ###
    # Routes through another stream. The filter must not be
    # created. This will create the filter as needed and
    # cache when it can.
    #
    # @param filter {stream}
    # @param args {Array} Array containg arguments to apply to filter.
    #
    # @example
    #   t.through coffee, [{bare: true}]
    ###
    through: (filter, args) ->
      stream = filter.apply(null, args)
      stream.on "error", (err) ->
        tapStream.emit "error", err

      stream.write file
      stream.pipe tapStream
      stream

  modifyFile = (file) ->
    inst = file: file
    obj = lambda(inst.file, utils(this, inst.file), inst)

    # if user returned a stream
    # passthrough when the stream is ended
    if obj instanceof baseStream then this.emit('end', => this.emit('data', inst.file)) else this.emit('data', inst.file)

  return ES.through(modifyFile, ->)
