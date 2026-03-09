require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [ :method, :path ]
  }

  config.filter_sensitive_data("<BILLING_API_KEY>") { |interaction|
    interaction.request.headers["Authorization"]&.first
  }

  config.before_record do |interaction|
    interaction.request.uri = interaction.request.uri.sub(%r{https?://[^/]+}, "http://localhost:8000")
  end
end
