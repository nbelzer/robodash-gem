# Robodash

This is a Ruby gem to easily send pings to Robodash.
```ruby
gem 'robodash'
```

```ruby
Robodash.api_token = # your dashboard API token

# Pinging
Robodash.ping("Some bg job")

# Counting things
Robodash.count("Something to track", 10)

# Tracking measurements
Robodash.measure("Puma Backlog", Puma.stats_hash[:backlog])
```

## Puma plugin

Report measurements from Puma to Robodash:

```ruby
# config/puma.rb

extra_runtime_depedencies "robodash"
plugin :robodash

# Set the Robodash api_token specifically for the Puma process.
# You can use ENV.fetch("ROBODASH_API_TOKEN") if you prefer.
::Robodash.api_token = "..."
```
