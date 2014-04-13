module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON "package.json"

    coffeelint:
      plugins: ["src/**/*.coffee", "GruntFile.coffee"]
      options:
        no_unnecessary_fat_arrows:
          level: "error"

    coffee:
      plugins:
        files:
          "celestrium.js": ["src/**.coffee"]
      options:
        sourceMap: true

    watch:
      coffee:
        files: ["src/**/*.coffee"]
        tasks: ["default"]

  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.registerTask "default", ["coffeelint", "coffee"]
