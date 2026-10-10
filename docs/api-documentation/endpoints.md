# Endpoints

Everything CIPP does in the interface is backed by an API endpoint, and the full reference for them now lives inside your own CIPP instance rather than on this site. It is generated from the source of the exact version you are running, so it always describes the deployment in front of you.

## Opening the endpoint reference

Go to **CIPP → Integrations → CIPP-API** and open the **API Documentation** tab.

Every endpoint your deployment exposes is listed there. Expand one to see the parameters it accepts, the body it expects, and the responses it returns. The filter box at the top narrows the list by name.

{% hint style="warning" %}
This reference is in beta. It is generated automatically from the CIPP source, and request and response schemas are inferred, so some fields may be missing, loosely typed, or described only in part. Treat it as a strong guide rather than a guarantee, and report anything that looks wrong.
{% endhint %}

## Trying an endpoint

Each operation has a **Try it out** button that sends the call to the instance you are signed in to, using your existing session. There is no client ID, secret or token to paste in.

{% hint style="danger" %}
Your own permissions apply, and write operations really do write. A call sent from this tab changes the same tenants CIPP manages, exactly as if you had performed the action in the interface.
{% endhint %}

## Using the specification in your own tools

The description behind the page is an OpenAPI 3.1 document, published by your instance at:

```
https://<your-cipp-url>/openapi.json
```

Open it while signed in to CIPP and save the file, then import it into Postman, Insomnia, or a client generator to scaffold your automation. It is rebuilt with every release, so pull a fresh copy after an upgrade to pick up new and changed endpoints.

## Finding the endpoint behind a page

If you are not sure which call sits behind something you do in CIPP, open your browser's developer tools, switch to the Network tab, and perform the action. The request name matches the endpoint in the reference, so you can look it up there and see its full parameters.

## Setting up access

{% content-ref url="setup-and-authentication.md" %}
[setup-and-authentication.md](setup-and-authentication.md)
{% endcontent-ref %}

{% content-ref url="../user-documentation/cipp/integrations/cipp-api.md" %}
[cipp-api.md](../user-documentation/cipp/integrations/cipp-api.md)
{% endcontent-ref %}

{% include "../../.gitbook/includes/feature-request.md" %}
