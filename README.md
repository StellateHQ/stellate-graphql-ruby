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

The last thing to do is to change all `MySchema.execute()` calls to `MySchema.execute_with_logging()`. Both these function accept the same arguments.

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

### (Non-)Blocking HTTP requests

By default, this plugin performs blocking HTTP requests to log requests or sync the schema. Stellate does run at the Edge in dozens of locations around the world, but these additional response times still negatively affect the response times for your API.

We allow you to move these blocking HTTP requests into any non-blocking process. This can be achieved by passing a callback function like so:

```rb
# Define a method that will set up a non-blocking process
def my_callback(stellate_request)
  # `stellate_request` is a hash that contains all the information you need to
  # build up a POST request
  stellate_request[:url] # The URL for the POST request
  stellate_request[:headers] # The headers for the POST request
  stellate_request[:body] # The body of the POST request

  # You can either create the HTTP POST request yourself, or use the following
  # utility from the `Stellate` module to run it.
  Stellate.run_stellate_request(stellate_request)
end

# Pass the callback to the schema syncing like so:
class MySchema < GraphQL::Schema
  # ...

  use Stellate::SchemaSyncing, callback: :my_callback

  # ...
end

# Pass the callback to the request logging like so:
MySchema.execute_with_logging(
  # GraphQL-specific arguments
  query,
  variables:, context:, operation_name:,
  # Stellate-specific arguments
  headers: request.headers, callback: :my_callback
)
```

#### Example: Sidekiq

[Sidekiq](https://sidekiq.org/) is a popular job system for Ruby application that allows you to run tasks asynchronously. You can use it to make the HTTP requests sent to Stellate non-blocking.

First, create a Sidekiq job that takes in a `stellate_request` hash (the one shown above) and passes it to `Stellate.run_stellate_request`:

```rb
class StellateJob
  include Sidekiq::Job

  def perform(stellate_request)
    Stellate.run_stellate_request(stellate_request)
  end
end
```

You can then schedule a run of `StellateJob` for each request by using the callback argument:

```rb
# Pass the callback to the schema syncing like so:
class MySchema < GraphQL::Schema
  # ...

  use Stellate::SchemaSyncing, callback: StellateJob.method(:perform_async)

  # ...
end

# Pass the callback to the request logging like so:
MySchema.execute_with_logging(
  # GraphQL-specific arguments
  query,
  variables:, context:, operation_name:,
  # Stellate-specific arguments
  headers: request.headers, callback: StellateJob.method(:perform_async)
)
```
