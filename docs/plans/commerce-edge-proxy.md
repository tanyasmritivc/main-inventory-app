# FindEZ commerce callbacks: remaining edge-proxy change

For the operator of the public Caddy proxy. Prepared November 10, 2026; not applied.

The Shopify/Amazon foundation and Gmail candidate are deployed; all imports remain disabled.
The deployed Next callback pages return
`Referrer-Policy: no-referrer` and `Cache-Control: no-store` on the application VM.
Public HTTPS preserves `no-store` but replaces the referrer policy with
`same-origin`. OAuth remains disabled pending this correction and provider setup.

## Response headers

In the existing Caddy configuration serving `www.findez.ai` and `findez.ai`, remove
the unconditional `Referrer-Policy same-origin` assignment for those sites and
replace it with the following mutually exclusive rules. Preserve the existing
upstream, TLS, other headers and unrelated sites. If the assignment lives in an
imported shared snippet or `header_down`, exclude these callback paths there too;
there must not be a second unconditional assignment that overwrites this one.

```caddyfile
@findezCommerceCallback path /connect/shopify/callback /connect/amazon/callback /connect/gmail/callback
@findezOtherPages not path /connect/shopify/callback /connect/amazon/callback /connect/gmail/callback
header @findezCommerceCallback >Referrer-Policy no-referrer
header @findezOtherPages >Referrer-Policy same-origin
```

Named matchers scope each rule, and `>` applies the header when sending the
response. See the official [Caddy header documentation](https://caddyserver.com/docs/caddyfile/directives/header).

## Access-log filtering

If edge access logs are enabled, redact OAuth parameters and referrer headers in
their existing formatter. Merge these fields into the existing filter; preserve
the log output, retention and other filters. This filters log records only; the
upstream application still needs the complete signed query.

```caddyfile
format filter {
    wrap json
    fields {
        request>uri query {
            delete code
            delete state
            delete hmac
            delete spapi_oauth_code
            delete amazon_state
            delete selling_partner_id
        }
        request>headers>Referer delete
    }
}
```

Keep Caddy's default credential-header redaction enabled. Reference:
[Caddy log filters](https://caddyserver.com/docs/caddyfile/directives/log#filter).
The application VM's nginx callback log already omits query strings and referrers
for Shopify/Amazon/Gmail, retaining method, path, status, timestamp, size and user
agent. The matcher was extended to `(shopify|amazon|gmail)` after validation;
reload and synthetic query/referrer omission checks passed. The separate Caddy
changes described here remain pending.

## Validate and verify

Back up the active configuration, validate it with the installed Caddy version
and actual config path, then reload using the operator's existing deployment
method. Do not replace the whole configuration with the snippets above.

```sh
curl -sSI https://www.findez.ai/connect/shopify/callback
curl -sSI https://www.findez.ai/connect/amazon/callback
curl -sSI https://www.findez.ai/connect/gmail/callback
```

Each must return `200`, `Referrer-Policy: no-referrer`, and `Cache-Control: no-store`.
Check the equivalent bare-domain routes too. Verify log filtering using synthetic
values only, then confirm normal pages and other hosted services still work.

Access attempts: the application VM can reach SSH at `192.168.1.60`, but the
available `ubuntu` and `vinodrex` logins were rejected. The alternate screenshot-provided
`vinodrex@openstack.ftctools.com:23223` also rejected authentication from the VM.
Its identity as the proxy machine is unconfirmed. No private key was copied from
the supplied screenshot, and no proxy configuration was changed.

Public Shopify callback recheck on November 11 at 05:42 UTC still returned
`Referrer-Policy: same-origin`; the edge override remains unresolved.
