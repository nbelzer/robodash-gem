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
