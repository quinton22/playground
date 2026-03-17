# Estate Sale Monitor

A tool to monitor estate sale websites, scrape images from listed sales, and alert you when items matching your search criteria are found.

## Features

- **Alert configuration**: Define search queries with keywords, categories, price ranges, and location filters
- **Web scraping**: Monitors popular estate sale listing sites (EstateSales.NET, GSALR, EstateSales.org)
- **Image scraping**: Downloads item images from matching estate sale listings
- **Image analysis**: Detects matching items using:
  - EXIF metadata inspection
  - Color histogram and dominant color analysis
  - Image feature characterization (brightness, contrast, texture)
- **Alerting**: Sends email notifications or saves matches to a local file when items are found

## Installation

```bash
pip install -e .
```

Or install dependencies directly:

```bash
pip install -r requirements.txt
```

## Usage

### Configure your alerts

Create a YAML configuration file (e.g., `alerts.yaml`):

```yaml
alerts:
  - name: "Antique Furniture"
    keywords:
      - "antique"
      - "victorian"
      - "dresser"
    category: "furniture"
    max_price: 500
    location:
      zip_code: "90210"
      radius_miles: 50

  - name: "Vintage Cameras"
    keywords:
      - "camera"
      - "vintage"
      - "leica"
      - "kodak"
    max_price: 300

notification:
  method: "email"            # "email" or "file"
  email: "you@example.com"
  smtp_host: "smtp.gmail.com"
  smtp_port: 587
  smtp_user: "you@gmail.com"
  smtp_password: "app_password"

output_dir: "./matches"
```

### Run the monitor

```bash
# Run once
estate-sale-monitor --config alerts.yaml

# Run on a schedule (every 6 hours)
estate-sale-monitor --config alerts.yaml --interval 6

# Scrape a specific estate sale URL
estate-sale-monitor --config alerts.yaml --url "https://www.estatesales.net/CA/Los-Angeles/90001/5678"

# Limit scraping to a specific site
estate-sale-monitor --config alerts.yaml --site estatesales
```

### CLI options

```
usage: estate-sale-monitor [-h] --config CONFIG [--url URL] [--site {estatesales,gsalr,estatesalesorg}]
                           [--interval INTERVAL] [--output OUTPUT] [--verbose]

options:
  -h, --help            Show this help message and exit
  --config CONFIG       Path to YAML alert configuration file
  --url URL             Scrape a specific estate sale URL instead of searching
  --site SITE           Limit monitoring to a specific site
  --interval INTERVAL   Run repeatedly every N hours (omit for a single run)
  --output OUTPUT       Directory to save matched images and results (overrides config)
  --verbose             Enable verbose logging
```

## Architecture

```
estate-sale-monitor/
├── estate_sale_monitor/
│   ├── __init__.py
│   ├── cli.py            # Command-line interface
│   ├── config.py         # Alert/configuration loading and validation
│   ├── scraper.py        # Web scraping for estate sale sites
│   ├── image_analyzer.py # Image metadata + characterization
│   ├── alerter.py        # Notification/alert delivery
│   └── monitor.py        # Main orchestrator
└── tests/
    ├── test_config.py
    ├── test_scraper.py
    ├── test_image_analyzer.py
    └── test_alerter.py
```

## Supported Sites

| Site | Search | Image Scraping |
|------|--------|----------------|
| [EstateSales.NET](https://www.estatesales.net) | ✅ | ✅ |
| [GSALR](https://gsalr.com) | ✅ | ✅ |
| [EstateSales.org](https://estatesales.org) | ✅ | ✅ |

## Image Analysis

The image analyzer uses three complementary techniques:

1. **Metadata inspection**: Reads EXIF tags (camera model, date taken, GPS location, description keywords) to find contextual clues about items in photos.

2. **Image characterization**: Analyzes visual properties of images including:
   - Dominant colors (to find items matching a color description)
   - Brightness and contrast profiles
   - Edge density (rough proxy for complexity/texture)
   - Aspect ratio and size characteristics

3. **ViT image classification**: Uses Google's [Vision Transformer (ViT)](https://huggingface.co/google/vit-base-patch16-224) model via the `transformers` library to predict object/scene labels for each image. The predicted labels (e.g. `"rocking chair"`, `"tabby cat"`) are included in keyword matching, enabling image-based discovery even when listings lack descriptive text.

Match scores are computed per-alert and items above a configurable threshold are included in notifications.

## Requirements

- Python 3.9+
- See `requirements.txt` for package dependencies

## Civic Message Hub (website)

This repository also includes a lightweight website for civic outreach:

- Finds local lawmaker/politician contact emails by ZIP code
- Generates AI-style outreach draft messages for current/relevant community issues
- Collects user-submitted issue subjects and displays them to other users

Run it locally:

```bash
civic-message-web --host 127.0.0.1 --port 8000
```

Then open `http://127.0.0.1:8000` in your browser.

Optional: set `GOOGLE_CIVIC_API_KEY` to retrieve live representative data; otherwise fallback local contacts are used.
