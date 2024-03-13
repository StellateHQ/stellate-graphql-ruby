# stellate-graphql-ruby

This is a Ruby Gem that allows you to integrate Stellate with your existing [GraphQL Ruby](https://github.com/rmosolgo/graphql-ruby) API with just a few lines of code.

## Installation

Start by adding the `stellate` gem to your `Gemfile`:

```Gemfile
gem 'stellate'
```

Then run `bundle install`.

## Set Up

Before you can make use of this gem, you need to [set up a Stellate service](https://stellate.co/docs/quickstart#1-create-stellate-service) and [create a logging token](https://stellate.co/docs/graphql-metrics/metrics-get-started#create-your-own-logging-token).

The `stellate` gem integrates directly into your `GraphQL::Schema` class, make sure to require the gem and then place the following somewhere inside the class:

```rb
require 'stellate'

class MySchema < GraphQL::Schema
  # ...

  # The name of your Stellate service
  @stellate_service_name = 'my-service'
  # The logging token for your Stellate service
  @stellate_token = 'stl8_xyz'

  # Automatically sync the schema with your Stellate service
  use Stellate::SchemaSyncing

  # Extend this class with a `execute_with_logging` class method that wraps the
  # `execute` method and logs information about the request and execution to
  # your Stellate service.
  extend Stellate::MetricsLogging

  # ...
end
```

The last thing to do is to replace all calls to `MySchema.execute()` with `MySchema.execute_with_logging()`. Both these function accept the same arguments.

Stellate can provide you with even more insights if you also provive the `execute_with_logging` method with the map of HTTP headers (of type `ActionDispatch::Http::Headers`). An example for a call to this function would look like this:

```rb
MySchema.execute_with_logging(
  # GraphQL-specific arguments
  query,
  variables:, context:, operation_name:,
  # Stellate-specific arguments
  headers: request.headers
)
```
