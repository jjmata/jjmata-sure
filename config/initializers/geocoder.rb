Geocoder.configure(
  # Geocoding service (see https://github.com/alexreisner/geocoder#geocoding-services)
  # Use ip-api.com for IP geolocation (free, no API key required)
  ip_lookup: :ipapi_com,

  # Request timeout
  timeout: 3,

  # Cache configuration
  cache: Redis.new,
  cache_prefix: "geocoder:",

  # Handle lookup failures gracefully
  always_raise: [],

  # Units
  units: :km
)
