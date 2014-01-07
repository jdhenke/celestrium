module.exports = (grunt) ->

  grunt.initConfig

    pkg: grunt.file.readJSON "package.json"

    coffeelint:
      app: ["coffee/**/*.coffee", "test/**/*.coffee", "GruntFile.coffee"]
      options:
        no_unnecessary_fat_arrows:
          level: "error"

    coffee:
      compileSrc:
        files:
          "dist/js/celestrium.js": ["coffee/**/*.coffee"]
      compileTest:
        files:
          "test/js/tests.js": ["test/**/*Spec.coffee"]
          "test/js/test-main.js": ["test/test-main.coffee"]

    karma:
      continuous:
        options:
          files: [
            "test/js/test-main.js",
            {pattern: "lib/**/*.js", included: false},
            {pattern: "dist/js/celestrium.js", included: false},
            {pattern: "test/js/tests.js", included: false},
          ]
          frameworks: ["jasmine", "requirejs"]
          singleRun: true
          browsers: ["PhantomJS"]
          captureTimeout: 60000

    uglify:
      minify:
        files:
          "dist/js/celestrium.min.js": ["dist/js/celestrium.js"]

    less:
      development:
        files:
          "dist/css/celestrium.css": "less/**/*.less"

    watch:
      coffee:
        files: ["coffee/**/*.coffee", "test/**/*.coffee"]
        tasks: ["coffee"]
      less:
        files: ["less/**/*.less"]
        tasks: ["less"]

    cssmin:
      minify:
        files:
          "dist/css/celestrium.min.css": "dist/css/celestrium.css"

  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-karma'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-less'
  grunt.loadNpmTasks 'grunt-contrib-cssmin'

  grunt.registerTask "test", ["coffeelint", "coffee", "less", "karma"]
  grunt.registerTask "default", ["test", "uglify:minify", "cssmin:minify"]
