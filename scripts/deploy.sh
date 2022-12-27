#!/usr/bin/env bash

set -xeEou pipefail

hugo --baseUrl=https://moqueries.org --destination=public
hugo deploy -v
