---
name: weather
description: "Get current weather and forecasts via Open-Meteo (primary) or wttr.in (fallback). Use when: user asks about weather, temperature, or forecasts for any location. NOT for: historical weather data, severe weather alerts, or detailed meteorological analysis. No API key needed."
homepage: https://open-meteo.com/
metadata: { "openclaw": { "emoji": "🌤️", "requires": { "bins": ["curl"] } } }
---

# Weather Skill

Get current weather conditions and forecasts using Open-Meteo API (primary) with wttr.in as fallback.

## When to Use

✅ **USE this skill when:**

- "What's the weather?"
- "Will it rain today/tomorrow?"
- "Temperature in [city]"
- "Weather forecast for the week"

## When NOT to Use

❌ **DON'T use this skill when:**

- Historical weather data → use weather archives/APIs
- Severe weather alerts → check official NWS sources

## Location

Always include a city, region, or coordinates in weather queries.

## Commands

### Open-Meteo (PRIMARY - Always Available)

```bash
# Get coordinates for city first, then weather
# Using geocoding API
curl "https://geocoding-api.open-meteo.com/v1/search?name=London&count=1&language=en&format=json"

# Current weather (replace lat/lon from geocoding)
curl "https://api.open-meteo.com/v1/forecast?latitude=51.5085&longitude=-0.1257&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m&timezone=auto"

# Daily forecast (7 days)
curl "https://api.open-meteo.com/v1/forecast?latitude=51.5085&longitude=-0.1257&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max&timezone=auto"
```

### wttr.in (FALLBACK - if Open-Meteo unavailable)

```bash
curl -s "wttr.in/London?format=%l:+%c+%t+(feels+like+%f),+%w+wind,+%h+humidity"
```

## Quick Response Template

**"What's the weather in [city]?"**

1. Get coordinates:

```bash
CITY="London"
curl -s "https://geocoding-api.open-meteo.com/v1/search?name=$CITY&count=1&format=json" | jq '.results[0] | {lat: .latitude, lon: .longitude, name: .name, country: .country}'
```

2. Get weather:

```bash
curl -s "https://api.open-meteo.com/v1/forecast?latitude=51.5085&longitude=-0.1257&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&timezone=auto"
```

## Notes

- No API key needed for Open-Meteo
- Open-Meteo is more reliable and not rate-limited
- wttr.in may be blocked on some networks
