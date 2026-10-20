# Minimal Streamlit Template

A barebones streamlit template for multi-page apps.

It ships with a small set of convenience components (components.py):
- Page: A class you can use as a context manager to create pages with common components, e.g. header, footer, error messages, state requirements.
- app_css: Custom CSS that gets automatically added to every page
- app_js: Custom JS that gets automatically added to every page

That's it!

## Installation

Run `uv sync --all-groups` to install streamlit  alongside other extras.
Run `uv sync --group ui` to install just the UI stack

## Usage

Run from the top-level folder with
```sh
streamlit run project_name_to_change/streamlit/app.py
```

## I don't want this

```
rm -rf project_name_to_change/streamlit
uv remove streamlit
```

Boom, it's gone!


## Streamlit Docs

https://docs.streamlit.io/
