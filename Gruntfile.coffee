module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON "package.json"

    coffeelint:
      app: ["coffee/**/*.coffee", "GruntFile.coffee"]
      options:
        no_unnecessary_fat_arrows:
          level: "error"

    coffee:
      compileSource:
        files:
          "dist/js/core-celestrium.js": ["coffee/**/*.coffee"]

    less:
      development:
        files:
          "dist/css/celestrium.css": "less/**/*.less"

    concat:
      "coffee-files":
        src: [
          "lib/jquery.js",
          "lib/jquery.typeahead.js",
          "lib/underscore.js",
          "lib/backbone.js",
          "lib/d3.js",
          "dist/js/core-celestrium.js",
          ],
        dest: "dist/js/celestrium.js"

    watch:
      coffee:
        files: ["coffee/**/*.coffee"]
        tasks: ["compile-coffee"]
      less:
        files: ["less/**/*.less"]
        tasks: ["less"]

  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-less'
  grunt.loadNpmTasks 'grunt-contrib-concat'

  grunt.registerTask "compile-coffee", ["coffee", "concat"]
  grunt.registerTask "test", ["coffeelint", "compile-coffee", "less"]
  grunt.registerTask "default", ["test"]
