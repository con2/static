# Con2 multi-site static file serving

We have a whole host of archived static sites we want to host until the end of time. This is the Way.

## Building and deploying

    export SKAFFOLD_DEFAULT_REPO=harbor.con2.fi/con2
    mc mirror con2/static static
    emsk -E production -- run -n static
