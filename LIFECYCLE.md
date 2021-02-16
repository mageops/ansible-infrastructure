# Delivery Lifecycle

## Build Release Source Artifact

0. Checkout Project Root
    - `git clone m2c/m2c`
      > Must contain:
      > * `composer.json`
      > * `auth.json.encrypted`
1. Build Backend Dist
    - `ansible-vault --output=auth.json decrypt auth.json.encrypted`
    - `composer update`
2. Build Frontend Dist
    - `yarn --frozen-lockfile`
    - `yarn build`
3. Run Tests
    - 

## Build Release Instance Image

## Update Live Instances with New Image

## Execute Post Deploy Actions on [single] New Instance