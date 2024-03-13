# How to develop this gem

## Running locally

If you want to use the local files with your local GraphQL Ruby API, you can simply add a path to the line in your `Gemfile` that installs `stellate`:

```Gemfile
gem 'stellate', path: '/path/to/this/repo'
```

## Publishing

The version of this plugin is declared as constant in the `Stellate` module in `stellate.rb`. In order to publish a new version you need to first bump this version.

Next, build the gem with this command:

```sh
gem build stellate.gemspec
```

This will create a `stellate-x.y.z.gem` file with the version you just specified. This can now be published to rubygems.org with this command:

```sh
gem push stellate-x.y.z.gem
```

Note that you have to be authenticated to be able to push the gem. If you are not, the command will prompt you for username, password, and OTP code, all of which can be found in our shared 1password (named "RubyGems").
