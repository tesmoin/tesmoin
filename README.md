# Tesmoin

Tesmoin is a self-hosted ratings, reviews, and Questions & Answers platform for ecommerce.

The product goal is to offer capabilities comparable to Bazaarvoice, Judge.me, Yotpo, and similar platforms while keeping ownership on the merchant side. Each ecommerce installs and runs its own Tesmoin instance, called a node.

The name Tesmoin is pronounced like temoin in French.

## Product Vision

Tesmoin is built around a decentralized model.

- Each merchant runs its own node.
- The node handles the operational features needed to collect, manage, and expose customer feedback.
- In a later phase, nodes can connect to a central hub called the sentinel.
- The sentinel does not replace the node. It augments it with registry, integrity, moderation, and syndication capabilities.

This architecture gives merchants control over hosting, data locality, and operational autonomy while still allowing an optional shared network layer later.

## Core Concepts

### The Node

The node is the self-hosted Tesmoin application deployed by a merchant.

Its responsibilities include:

- registering transactions or order events
- generating one-time review request tokens and secure review links
- serving hosted review and Q&A submission forms
- reducing fraud through verification flows and browser fingerprint checks
- storing and moderating reviews and questions locally
- exposing APIs and embeddable endpoints for storefront display
- providing near real-time analytics and operational dashboards
- managing merchant configuration, authentication, and plan status

The node must remain useful as a fully standalone product, even without any sentinel connectivity.

### The Sentinel

The sentinel is a future central public network service connected to many nodes.

Its intended responsibilities include:

- public registry of participating nodes
- activity reporting and health visibility
- tamper-evidence to ensure reviews are not secretly deleted or edited
- integrity proofs, potentially via Merkle-tree-based attestations
- AI-powered moderation services
- peer-to-peer or hub-assisted review syndication across nodes

The sentinel is phase two. Phase one should treat it as an optional future integration point, not a dependency.

## Business Model

Tesmoin has two pricing tiers.

### Free

The free tier includes almost all node capabilities, including the core collection, hosting, storage, moderation workflows, analytics, and display APIs.

### Pro - 29 EUR per month

The paid tier unlocks services tied to the sentinel and the broader network layer, such as:

- AI moderation from the hub
- review and Q&A syndication between participating nodes
- additional trust, audit, and network services over time

This pricing model keeps the node highly valuable on its own while making the shared network economically optional.

## Authentication and Activation Model

The authentication workflow is simple and self-hosting friendly.

- Tesmoin is magic-link-only for admin authentication (no passwords).
- On first boot, use `/setup` to create the first admin.
- Authentication for the node admin panel remains local to the node.
- If the merchant activates the paid plan, the Tesmoin website generates a license key.
- The node stores and validates the license key locally and can later sync plan entitlements with the sentinel or licensing service.

This is deliberately similar to the self-hosted n8n onboarding model: local ownership first, hosted activation second.

## Phase 1 Goal

Phase one should focus only on building a strong standalone node.

That means:

- no dependency on the sentinel to install or operate
- no requirement for inter-node networking
- no early investment in distributed trust features before the core product works
- clear boundaries so sentinel integration can be added later without rewriting the node

The success criterion for phase one is straightforward: a merchant can self-host Tesmoin, connect their ecommerce events, collect trustworthy reviews and questions, moderate them, and display them back on their storefront.

## Recommended Stack

Elixir is a strong fit for Tesmoin because the node needs concurrency, fault tolerance, background processing, real-time dashboards, and a clean path toward distributed features later.

### Phoenix

Use Phoenix.

Reasons:

- it gives a robust web foundation for APIs, admin UI, hosted forms, and webhooks
- Phoenix LiveView is well suited for internal back-office screens and real-time analytics dashboards
- Phoenix Channels or PubSub can support live operational updates and future event streaming
- it keeps the architecture cohesive instead of splitting the product across multiple runtimes

Recommendation: Phoenix should be the main application framework.

### PostgreSQL

Use PostgreSQL.

Reasons:

- reviews, questions, submissions, transactions, and moderation actions are relational data
- strong indexing and query support will matter for analytics and storefront retrieval
- transactional consistency is useful for token generation, submission flows, and audit trails
- it leaves room for advanced features such as full-text search, JSONB payloads, and partitioning later

Recommendation: PostgreSQL should be the primary datastore from day one.

### Oban

Use Oban for background jobs.

Reasons:

- sending review requests asynchronously
- ingesting transaction events
- processing fraud signals
- running analytics aggregation tasks
- handling future license checks or sentinel sync work

Recommendation: Oban is a better fit than building a custom job runner.

### Phoenix LiveView

Use LiveView for the admin application.

Reasons:

- fast delivery for dashboards, moderation queues, settings, and analytics
- fewer moving parts than a separate SPA frontend
- good fit for a small team building a product-heavy back office

Recommendation: default to LiveView for internal tooling, and expose JSON APIs for storefront and external integrations.

### REST API First

The storefront-facing integration should start API-first.

Recommended interfaces:

- JSON APIs for reviews, aggregate ratings, Q&A, and submission status
- signed or tokenized public endpoints where needed
- optional embeddable widgets later, but not as the first implementation priority

GraphQL is not necessary in phase one.

### Browser Fingerprinting and Trust Signals

Do not make browser fingerprinting the sole trust mechanism.

Use a layered anti-fraud approach:

- transaction verification or order linkage
- one-time tokenized submission links
- IP and user-agent metadata
- rate limiting
- browser fingerprinting as one signal among several
- audit logs for moderation decisions

### Docker

Treat Docker as a first-class deployment target.

Reasons:

- self-hosted distribution becomes simpler
- initial admin credentials and license configuration can be environment-driven
- the install experience becomes much closer to the intended product model

Recommendation: support local development with standard mix tooling, but design deployment around Docker and docker-compose style workflows from the start.

## Suggested Phase 1 Architecture

The first version of the node can be organized into these modules or bounded contexts:

- Accounts: local admin authentication, magic-link login, installation bootstrap
- Billing or Licensing: local plan state and license key handling
- Catalog: products, product metadata, imported references
- Orders: transaction ingestion and verification references
- Invitations: one-time review request tokens and delivery records
- Reviews: review creation, moderation, publication, edits, audit trail
- Questions: question creation, answer workflows, moderation, publication
- Trust: fraud checks, fingerprints, rate limits, risk signals
- Analytics: counters, aggregates, funnels, dashboard views
- Public API: storefront-facing read APIs and submission endpoints

These boundaries make later sentinel integration easier because network concerns can be added around existing contexts instead of mixed into them.

## Suggested Data Model Direction

At minimum, phase one likely needs entities such as:

- merchants or installation settings
- admin users
- products
- orders or transactions
- review invitations
- one-time tokens
- reviews
- review revisions or moderation events
- questions
- answers
- fraud signals
- analytics events or rollups
- licenses

Not every table needs to be fully modeled on day one, but the schema should assume strong auditability.

## What Not To Build First

To keep phase one realistic, avoid these until the standalone node is solid:

- cross-node syndication
- Merkle-tree integrity proofs in production form
- AI moderation pipelines
- public network registry and node discovery
- complicated embeddable widget builders
- multi-tenant SaaS assumptions inside the node

Those are phase two multipliers, not phase one foundations.

## Recommended First Milestones

### Milestone 1: Installable Node Skeleton

- Phoenix app with LiveView
- PostgreSQL and Ecto setup
- Docker-based local deployment
- initial setup wizard for first admin email and magic-link login
- basic authentication and settings pages

### Milestone 2: Transaction and Invitation Pipeline

- transaction ingestion endpoint
- product and order linkage
- one-time token generation
- hosted review request URLs
- background jobs for invitation processing

### Milestone 3: Review Submission and Moderation

- hosted review form
- token validation flow
- anti-fraud signal capture
- review persistence and moderation states
- admin moderation queue

### Milestone 4: Public Display API

- aggregate rating endpoints
- review listing endpoints
- product-level filtering and pagination
- basic Q&A read and write flows

### Milestone 5: Analytics and Licensing

- submission funnel metrics
- moderation metrics
- dashboard views
- local license key activation for paid plan readiness

## Recommendation Summary

For phase one, the right stack is:

- Elixir
- Phoenix
- Phoenix LiveView
- PostgreSQL
- Ecto
- Oban
- Docker

This is enough to build a serious standalone node without overcommitting to phase two infrastructure too early.

## Immediate Next Step

Start by initializing the node as a Phoenix application with PostgreSQL, LiveView, and Oban, and define the core bounded contexts around orders, invitations, reviews, questions, trust signals, analytics, and licensing.

If that first slice is done well, the sentinel can later become an additive integration layer rather than a structural dependency.

## Authentication and Mailer Setup

### Authentication

Tesmoin uses **magic-link-only authentication**. There are no passwords. Admins log in by requesting a one-time sign-in link sent to their email address.

#### First-run setup

On a fresh installation with no admin account, every route redirects to `/setup`. Fill in an email address and a magic link is sent to that address. Click it to log in and start using the node.

### Mailer

#### Development

In development, emails are not delivered externally. They are stored in memory and can be inspected at:

```
http://localhost:4000/dev/mailbox
```

#### Production

Production requires a real SMTP server. Set at minimum `SMTP_HOST`. All other variables are optional and have defaults.

| Variable | Required | Default | Description |
|---|---|---|---|
| `SMTP_HOST` | Yes | — | SMTP relay hostname |
| `SMTP_PORT` | No | `587` | SMTP port (587 = STARTTLS, 465 = SSL, 25 = plain) |
| `SMTP_USER` | No | — | SMTP username or API token |
| `SMTP_PASS` | No | — | SMTP password or API secret |
| `SMTP_FROM` | No | `SMTP_USER` | From address for outgoing emails |
| `SMTP_TLS` | No | `if_available` | TLS mode: `always`, `never`, or `if_available` |
| `SMTP_AUTH` | No | `if_available` | Auth mode: `always`, `never`, or `if_available` |

Any standard SMTP provider works: Postmark, Mailgun, Resend, AWS SES, or your own mail server. Example for Postmark:

```env
SMTP_HOST=smtp.postmarkapp.com
SMTP_PORT=587
SMTP_USER=your-postmark-api-token
SMTP_PASS=your-postmark-api-token
SMTP_FROM=noreply@yourdomain.com
SMTP_TLS=always
SMTP_AUTH=always
```

If `SMTP_HOST` is not set in production, the application will refuse to start with a descriptive error.

## Production Deployment Checklist

Use this list before exposing Tesmoin publicly.

### Required

- `HOSTNAME` set to your public host name
- `SECRET_KEY_BASE` set to a strong secret
- `DATABASE_URL` set and reachable
- `SMTP_HOST` configured (plus SMTP credentials as needed)
- `force_ssl` enabled (already configured in `config/prod.exs`)
- HTTPS termination correctly configured in your proxy/load balancer

### Strongly Recommended

- `TRUSTED_PROXIES` set to the IP(s) of your reverse proxy so rate limits and audit logs use real client IPs
- Monitor Oban queue health and SMTP delivery failures

### Auth/Cookie Security Notes

- Session and remember-me cookies are `HttpOnly` and `Secure` in production (`session_secure: true` in `config/prod.exs`)
- Magic-link email delivery is asynchronous via Oban
- Magic-link token is generated at worker delivery time to avoid stale links from queue delay

### Deliberate Trade-offs

- CSP currently keeps `script-src 'unsafe-inline'` for Phoenix LiveView compatibility
- Rate limiting uses Hammer ETS backend and is intended for self-hosted single-node deployments

