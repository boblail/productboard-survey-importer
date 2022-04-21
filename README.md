# productboard-survey-importer

## How to use this

1. Generate an API Token (Click **Integrations** and add an **Access token**) and copy it to your clipboard.
2. Set it as an environment variable
    ```
    export PRODUCTBOARD_API_TOKEN="$(pbpaste)"
    ```
3. Clone this repo and run it
    ```
    git clone https://github.com/boblail/productboard-survey-importer.git
    cd productboard-survey-importer

    bundle
    bundle exec puma
    ```
4. Visit the importer in your browser: http://0.0.0.0:9292/

