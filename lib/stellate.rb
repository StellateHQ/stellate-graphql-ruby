# frozen_string_literal: true

require 'uri'
require 'net/http'

module Stellate
  VERSION = '1.0.0'

  # Extend your GraphQL::Schema with this module to enable easy Stellate
  # Metrics Logging.
  #
  # Add `extend Stellate::MetricsLogging` within your schema class. This will
  # add the class method `execute_with_logging`. Then replace the call to
  # `MySchema.execute()` with `MySchema.execute_with_logging()`.
  module MetricsLogging
    # Executes a given GraphQL query on the schema and logs details about the
    # request and execution to Stellate. This function accepts the same
    # arguments as `GraphQL::Schema.execute()`, and also the following:
    # - `headers` (`ActionDispatch::Http::Headers`): The HTTP headers from the
    #   incoming request
    # - `callback` (`Method`): If passed, this will be called with a lambda as
    #   argument. Calling the passed lambda will log the request to Stellate
    #   via HTTP. This is useful if you want to move this request into a non-
    #   blocking process (e.g. using Sidekiq) rather than the default behavior
    #   of performing a blocking HTTP request which can increase overall
    #   response times of your API.
    def execute_with_logging(query_str = nil, **kwargs)
      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = execute(query_str, **kwargs.except(:headers, :callback))

      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = (ending - starting) * 1000

      headers = kwargs[:headers]
      has_headers = headers.is_a?(ActionDispatch::Http::Headers)

      return result if has_headers && headers['Gcdn-Request-Id'].is_a?(String)

      unless @stellate_service_name.is_a?(String)
        puts 'Missing service name in order to log metrics to Stellate'
        return result
      end

      unless @stellate_token.is_a?(String)
        puts 'Missing token in order to log metrics to Stellate'
        return result
      end

      unless query_str.is_a?(String)
        puts 'Cannot log metrics to Stellate without a query string'
        return result
      end

      response = result.to_json
      payload = {
        'operation': query_str,
        'variableHash': create_blake3_hash(kwargs[:variables].to_json),
        'method': kwargs[:method].is_a?(String) ? kwargs[:method] : 'POST',
        'elapsed': elapsed.round,
        'responseSize': response.length,
        'responseHash': create_blake3_hash(response),
        'statusCode': 200,
        'operationName': kwargs[:operation_name]
      }

      errors = result['errors']
      payload[:errors] = errors if errors.is_a?(Array)

      if has_headers
        forwarded_for = headers['X-Forwarded-For']
        ips = forwarded_for.is_a?(String) ? forwarded_for.split(',') : []

        payload[:id] = ips[0] || headers['True-Client-Ip'] || headers['X-Real-Ip']
        payload[:userAgent] = headers['User-Agent']
        payload[:referer] = headers['referer']
      end

      stellate_request = {
        'url': "https://#{@stellate_service_name}.stellate.sh/log",
        'headers': {
          'Content-Type': 'application/json',
          'Stellate-Logging-Token': @stellate_token
        },
        'body': payload.to_json
      }

      callback = kwargs[:callback]
      # The former check handles methods, the latter handles lambdas
      if callback.is_a?(Method) || callback.respond_to?(:call)
        callback.call(stellate_request)
      # This handles symbols that contain methods
      elsif callback.is_a?(Symbol) && method(callback).is_a?(Method)
        method(callback).call(stellate_request)
      else
        run_stellate_request(stellate_request)
      end

      result
    end

    def stellate_service_name
      @stellate_service_name
    end

    def stellate_token
      @stellate_token
    end
  end

  # Use this plugin in your GraphQL::Schema to automatically sync your GraphQL
  # schema with your Stellate service.
  class SchemaSyncing
    # The first argument is the GraphQLSchema class that this plugin is used
    # on. It accepts the following names arguments:
    # - `callback` (`Method`): If passed, this will be called with a lambda as
    #   argument. Calling the passed lambda will sync the schema to Stellate
    #   via HTTP. This is useful if you want to move this request into a non-
    #   blocking process (e.g. using Sidekiq) rather than the default behavior
    #   of performing a blocking HTTP request which can increase overall
    #   response times of your API.
    def self.use(schema, **kwargs)
      unless schema.stellate_service_name.is_a?(String)
        puts 'Missing service name in order to sync schema to Stellate'
        return
      end

      unless schema.stellate_token.is_a?(String)
        puts 'Missing token in order to sync schema to Stellate'
        return
      end

      introspection = JSON.parse(schema.to_json)['data']

      stellate_request = {
        'url': "https://#{@stellate_service_name}.stellate.sh/schema",
        'headers': {
          'Content-Type': 'application/json',
          'Stellate-Schema-Token': schema.stellate_token
        },
        'body': { schema: introspection }.to_json
      }

      callback = kwargs[:callback]
      # The former check handles methods, the latter handles lambdas
      if callback.is_a?(Method) || callback.respond_to?(:call)
        callback.call(stellate_request)
      # This handles symbols that contain methods
      elsif callback.is_a?(Symbol) && method(callback).is_a?(Method)
        method(callback).call(stellate_request)
      else
        run_stellate_request(stellate_request)
      end
    end
  end

  def self.run_stellate_request(stellate_request)
    url = URI.parse(stellate_request[:url])
    http = Net::HTTP.new(url.host, url.port)
    req = Net::HTTP::Post.new(url)
    stellate_request[:headers].each do |key, value|
      req[key] = value
    end
    req.body = stellate_request[:body]
    res = http.request(req)
    puts "HTTP request to Stellate failed: #{res.body}" if res.code.to_i >= 300
  rescue StandardError => e
    puts "HTTP request to Stellate failed: #{e}"
  end
end

def create_blake3_hash(str)
  val = 0

  return val if str.empty?

  str.each_byte do |code|
    val = (val << 5) - val + code
    val &= 0xffffffff # Int32
  end

  val >> 0 # uInt32
end
