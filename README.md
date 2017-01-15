# Sproxy2

HTTP proxy for authenticating users via OAuth2.


## Motivation

This is overhaul of original [Sproxy](https://hackage.haskell.org/package/sproxy).
See [ChangeLog.md](./ChangeLog.md) for the differences.

Why use a proxy for doing OAuth2? Isn't that up to the application?

 * sproxy is secure by default.  No requests make it to
   the web server if they haven't been explicitly whitelisted.
 * sproxy is independent.  Any web application written in
   any language can use it.

## Use cases

 * Existing web applications with concept of roles. For example,
   [Mediawiki](https://www.mediawiki.org), [Jenkins](https://jenkins.io),
   [Icinga Web 2](https://www.icinga.org/products/icinga-web-2/). In
   this case you configure Sproxy to allow unrestricted access
   to the application for some groups defined by Sproxy. These
   groups are mapped to the application roles.  There is a [plugin for
   Jenkins](https://wiki.jenkins-ci.org/display/JENKINS/Reverse+Proxy+Auth+Plugin)
   which can be used for this. Mediawiki and Icinga Web 2 were also
   successfully deployed in this way, though it required changes to their
   source code.

 * New web applications designed to work specifically behind Sproxy. In this case
   you define Sproxy rules to control access to the
   application's API.  It would likely be [a single-page
   application](https://en.wikipedia.org/wiki/Single-page_application).
   Examples are [MyWatch](https://hackage.haskell.org/package/mywatch) and
   [Juan de la Cosa](https://hackage.haskell.org/package/juandelacosa).

 * Replace HTTP Basic authentication.


How it works
============

When an HTTP client makes a request, Sproxy checks for a *session cookie*.
If it doesn't exist (or it's invalid, expired), it responses with [HTTP
status 511](https://tools.ietf.org/html/rfc6585) with the page, where the
user can choose an [OAuth2](https://tools.ietf.org/html/rfc6749) provider to
authenticate with.  Finally, we store the the email address in a session
cookie: signed with a hash to prevent tampering, set for HTTP only (to prevent
malicious JavaScript from reading it), and set it for secure (since we don't
want it traveling over plaintext HTTP connections).

From that point on, when sproxy detects a valid session cookie it extracts the
email, checks it against the access rules, and relays the request to the
back-end server (if allowed).


Permissions system
------------------
Permissions are stored in internal SQLite3 database and imported
from data sources, which can be a PostgreSQL database or a file.  See
[sproxy.sql](./sproxy.sql) and [datafile.example.yml](./datafile.example.yml)
for details.

Do note that Sproxy2 fetches only `group_member`, `group_privilege`
and `privilege_rule` tables, because only these tables are used for
authorization. The other tables in PostgreSQL schema serve for data
integrity. Data integrity of the data file is not verfied, though import
may fail due to primary key restrictions.

Only one data source can be used. The data in internal database, if any,
is fully overwritten by the data from a data source. If no data source is
specified, the data in internal database remains unchanged, even between
restarts.  Broken data source is _not_ fatal. Sproxy will keep using existing
internal database, or create a new empty one if missed. Broken data source
means inability to connect to PostgreSQL database, missed datafile, etc.

The data from a PostgreSQL database are periodically fetched into the internal
database, while the data file is read once at startup.

Here are the main concepts:

- A `group` is identified by a name. Every group has
  - members (identified by email address, through `group_member`) and
  - associated privileges (through `group_privilege`).
- A `privilege` is identified by a name _and_ a domain. It has associated rules
  (through `privilege_rule`) that define what the privilege gives access to.
- A `rule` is a combination of sql patterns for a `domain`, a `path` and an
  HTTP `method`. A rule matches an HTTP request, if all of these components
  match the respective attributes of the request. However of all the matching
  rules only the rule with the longest `path` pattern will be used to determine
  whether a user is allowed to perform a request. This is often a bit
  surprising, please see the following example:


Privileges example
------------------

Consider this `group_privilege` and `privilege_rule` relations:

group            | privilege | domain
---------------- | --------- | -----------------
`readers`        | `basic`   | `wiki.example.com`
`readers`        | `read`    | `wiki.example.com`
`editors`        | `basic`   | `wiki.example.com`
`editors`        | `read`    | `wiki.example.com`
`editors`        | `edit`    | `wiki.example.com`
`administrators` | `basic`   | `wiki.example.com`
`administrators` | `read`    | `wiki.example.com`
`administrators` | `edit`    | `wiki.example.com`
`administrators` | `admin`   | `wiki.example.com`

privilege   | domain             | path           | method
----------- | ------------------ | -------------- | ------
`basic`     | `wiki.example.com` | `/%`           | `GET`
`read`      | `wiki.example.com` | `/wiki/%`      | `GET`
`edit`      | `wiki.example.com` | `/wiki/edit/%` | `GET`
`edit`      | `wiki.example.com` | `/wiki/edit/%` | `POST`
`admin`     | `wiki.example.com` | `/admin/%`     | `GET`
`admin`     | `wiki.example.com` | `/admin/%`     | `POST`
`admin`     | `wiki.example.com` | `/admin/%`     | `DELETE`

With this setup, everybody (that is `readers`, `editors` and `administrators`s)
will have access to e.g. `/imgs/logo.png` and `/favicon.ico`, but only
administrators will have access to `/admin/index.php`, because the longest
matching path pattern is `/admin/%` and only `administrator`s have the `admin`
privilege.

Likewise `readers` have no access to e.g. `/wiki/edit/delete_everything.php`.


Keep in mind that:

- Domains are converted into lower case (coming from a data source or HTTP requests).
- Emails are converted into lower case (coming from a data source or OAuth2 providers).
- Groups are case-sensitive and treated as is.
- HTTP methods are *case-sensitive*.
- HTTP query parameters are ignored when matching a request against the rules.
- Privileges are case-sensitive and treated as is.
- SQL wildcards (`_` and `%`) are supported for emails, paths (this _will_ change in future versions).


HTTP headers passed to the back-end server
------------------------------------------

All Sproxy headers are UTF8-encoded.


header               | value
-------------------- | -----
`From:`              | visitor's email address, lower case
`X-Groups:`          | all groups that granted access to this resource, separated by commas (see the note below)
`X-Given-Name:`      | the visitor's given (first) name
`X-Family-Name:`     | the visitor's family (last) name
`X-Forwarded-Proto:` | the visitor's protocol of an HTTP request, always `https`
`X-Forwarded-For`    | the visitor's IP address (added to the end of the list if header is already present in client request)


`X-Groups` denotes an intersection of the groups the visitor belongs to and the groups that granted access:

Visitor's groups | Granted groups | `X-Groups`
---------------- | -------------- | ---------
all              | all, devops    | all
all, devops      | all            | all
all, devops      | all, devops    | all,devops
all, devops      | devops         | devops
devops           | all, devops    | devops
devops           | all            | Access denied


Logout
------

Hitting the endpoint `/.sproxy/logout` will invalidate the session cookie.
The user will be redirected to `/` after logout.


Robots
------

Since all sproxied resources are private, it doesn't make sense for web
crawlers to try to index them. In fact, crawlers will index only the login
page. To prevent this, sproxy returns the following for `/robots.txt`:

```
User-agent: *
Disallow: /
```


Requirements
============
Sproxy2 is written in Haskell with [GHC](http://www.haskell.org/ghc/).
All required Haskell libraries are listed in [sproxy2.cabal](sproxy2.cabal).
Use [cabal-install](http://www.haskell.org/haskellwiki/Cabal-Install)
to fetch and build all pre-requisites automatically.


Configuration
=============

By default `sproxy2` will read its configuration from `sproxy.yml`.  There is
example file with documentation [sproxy.example.yml](sproxy.example.yml). You
can specify a custom path with:

```
sproxy2 --config /path/to/sproxy.yml
```

