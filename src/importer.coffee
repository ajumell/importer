path = require 'path'

# The regular expression used to find import statements
IMPORT_RE = /(?:#|\/\/)import (".+"|<.+>);?$/gm
exports.IMPORT_RE = IMPORT_RE

# These are the supported languages. Each language should
# return either a compiled string or an object containing the
# compiled JavaScript and a source map. CoffeeScript and JavaScript
# files are supported out of the box, though CoffeeScript is not a 
# required npm dependency. Install if you need it.
exports.extensions = 
    '.coffee': (code, sourceMap) ->
        # The CoffeeScript compiler doesn't support preserving comments, which 
        # makes it impossible to know where the original import statements were.
        # We use the `backtick` embedded JS feature to preserve import statements.
        code = code.replace(IMPORT_RE, '`//import $1`')
        ret = require('coffee-script').compile code,
            bare: yes
            sourceMap: sourceMap
            filename: 'item'
            
        if typeof ret isnt 'string'
            return code: ret.js, map: JSON.parse(ret.v3SourceMap)
            
        return ret
            
    '.js': (code) -> 
        return code
    
Package = require './package'
exports.createPackage = (main, options) ->
    return new Package main, options
    
# This synchronously compiles and executes a package directly in Node
exports.require = (main, options = {}) ->
    pkg = new Package main, options
    return pkg.require()
    
# Connect/Express middleware
exports.middleware = (main, options = {}) ->
  options.url ?= "/#{path.basename(main, path.extname(main))}.js"
  options.sourceMap = "#{options.url}.map" unless options.sourceMap is false
  pkg = new Package main, options
  
  return (req, res, next) ->
    return next() unless req.url in [options.url, options.sourceMap]
    
    pkg.build (err, built) ->
        res.type('.js')
        
        if err
            res.end 'throw "' + err.message.replace(/"/g, "\\\"") + '"'
        else if req.url is options.sourceMap
            res.end built.map
        else
            res.end built.code