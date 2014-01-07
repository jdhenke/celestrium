### Recommend Workflow

1. [Fork](https://github.com/jdhenke/celestrium/fork) this repo.
2. Embed your fork as a [git submodule](http://git-scm.com/book/en/Git-Tools-Submodules) in your project.
3. Run `grunt watch`, symlink the js/css files in `./dist` to where they're needed and make changes to Celestrium as you see fit.

You should branch from develop `develop`.

> TODO - Link to example repo using Celestrium as submodule.

### Pull Request Instructions

1. Make sure `grunt test` passes
2. Make a pull request to `develop`
3. Provide a comment which includes
  - what the change is
  - why it's necessary
  - a link to a working interface which uses it

If using Celestrium as a git submodule, remember to commit and push your changes to Celestrium **before** committing and pushing to your outer project.

Keep changes small, data set agnostic and carefully considered.
