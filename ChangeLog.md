1.97.0
======

  * Added new option `timeout` to configure backend response timeout.

  * Changed default random key length to 64 bytes (from 32).


1.96.0
======

  * Added support for Yandex (https://tech.yandex.com/oauth/).

  * Encode full URL (including protocol) into the state parameter,
    not just path.  This makes it possible to work with OAuth2 providers
    that do not support multiple callback URL, like Yandex.

  * Fixed POST requests for tokens with Google and LinkedIn. They
    were mistakenly using URL paramaters instead of URL-encoded bodies.


1.95.0
======

  * Add end-point for checking access in a bunch (`/.sproxy/access`).

  * Respond with 502 (Bad Gateway) on any backend error.
    Previously it was 500 (Internal Server Error).


1.94.1
======

  * Fixed a typo introduced in version 1.94.0 in SQL query:
    `... WHERE domain = domain ...` -> `... WHERE domain = :domain ...`


1.94.0
======

  * BREAKING: Disregard possible port in the Host HTTP header.
    Previously, Sproxy took possible port number into account when
    looking for backend and privileges. Now it ignores port and considers
    domain name only.  This also gets Sproxy in line with browsers and SSL
    certificates: certificates do not include port numbers, browsers ignore
    ports when sending cookies.

  * BREAKING: no SQL wildcards (`%` or `_`) in domain names when looking up
    for privileges.  This feature was ambiguous (in the same way as paths are)
    and never used anyway.


1.93.0
======

  * BREAKING: Allow `!include` in config file.
    This changes semantics of options `key` and `oauth2.<provider>.client_secret`.
    They are no longer files, but strings.  To read content from files, use
    !include.  The point of being files or read from files is to segregate secrets
    from non-sensitive easily discoverable settings.  With `!include` it is much more
    simple and flexible.


1.92.0
======

  * Allow running in plain HTTP mode (no SSL). Useful when Sproxy is behind some
    other proxy or load-balancer. Added two more options: `ssl` (defaults to true)
    and `https_port` (defaults to like `listen`). Options `ssl_key` and `ssl_cert`
    are required only if `ssl == true`. SSL-terminations is still required at upstream
    proxies, because the cookie is set for HTTPS only.

  * Added "user" table into `sproxy.sql`. No action is required, but PostgreSQL database
    built after this file will be incompatible with Sproxy Web ( <= 0.4.1 at least).


1.91.0
======

  * In addition to good old PostgreSQL data source, made it possible
    to import permission data from a YAML file. This means that Sproxy2
    can work without any PostgreSQL database, just using file-only configuration.
    Useful for development or trivial deployments. Added new `datafile` option
    in configuration file.


1.90.2
======

  * Make sure all Sproxy-specific HTTP headers are UTF8-encoded.

  * `/.sproxy/logout` just redirects if no cookie. Previously
    it was returning HTTP 404 to unauthenticated users, and redirecting
    authenticated users with removal of the cookie. The point is not to
    reveal cookie name.

  * Made Warp stop printing exceptions, mostly "client closed connection",
    which happens outside of our traps.


1.90.1
======

  * Fixed headers processing. Wrong headers were making Chromium drop connection in HTTP/2.
    Firefox sometimes couldn't handle gzipped and chunked responses in HTTP/1.1.

  * After authenticating, redirect to original path with query parameters if
    method was GET.  Otherwise redirect to "/". Previously, when unauthenticated
    users click on "https://example.net/foo?bar", they are redirected to
    "https://example.net/foo" regardless of the method.



1.90.0 (Preview Release)
========================

Sproxy2 is overhaul of original [Sproxy](https://github.com/zalora/sproxy)
(see also [Hackage](https://hackage.haskell.org/package/sproxy)).
Here are the key differences (with Sproxy 0.9.8):

  * Sproxy2 can work with remote PostgreSQL database. Quick access to the database is essential
    as sproxy does it on every HTTP request. Sproxy2 pulls data into local SQLite3 database.

  * At this release Sproxy2 is compatible with Sproxy database with one exception:
    SQL wildcards are not supported for HTTP methods. I. e. you have to change '%' in
    the database to specific methods like GET, POST, etc.

  * OAuth2 callback URLs changed: Sproxy2 uses `/.sproxy/oauth2/:provider`,
    e. g. `/.sproxy/oauth2/google`. Sproxy used `/sproxy/oauth2callback` for Google
    and `/sproxy/oauth2callback/linkedin` for LinkedIn.

  * Sproxy2 does not allow login with email addresses not known to it.

  * Sproxy2: OAuth2 callback state is serialized, signed and passed base64-encoded.
    Of course it's used to verify the request is legit.

  * Sproxy2: session cookie is serialized, signed and sent base64-encoded.

  * Path `/.sproxy` belongs to Sproxy2 completely. Anything under this path is never passed to backends.

  * Sproxy2 supports multiple backends. Routing is based on the Host HTTP header.

  * Sproxy2 uses [WAI](https://hackage.haskell.org/package/wai) / [Warp](https://hackage.haskell.org/package/warp)
    for incoming connections. As a result Sproxy2 supports HTTP2.

  * Sproxy2 uses [HTTP Client](https://hackage.haskell.org/package/http-client) to talk to backends.
    As a result Sproxy2 reuses backend connections instead of closing them after each request to the backend.

  * Sproxy2 optionally supports persistent key again (removed in Sproxy 0.9.2).
    This can be used in load-balancing multiple Sproxy2 instances.

  * Configuration file has changed. It's still YAML, but some options are renamed, removed or added.
    Have a look at well-documented [sproxy.example.yml](./sproxy.example.yml)

