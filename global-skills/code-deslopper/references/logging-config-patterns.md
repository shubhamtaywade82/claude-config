# Logging, Observability & Configuration — AI Slop Patterns & Idiomatic Fixes

This reference covers two tightly related failure categories that AI-generated code gets wrong constantly:

1. **Logging / Observability** — debug noise, PII leakage, missing context
2. **Configuration / Environment** — hardcoded secrets, silent nil, 12-factor violations

Risk scores are 1–5 where **5 = production incident waiting to happen**.

---

## PART 1: LOGGING / OBSERVABILITY ANTI-PATTERNS

---

## Ruby / Rails — Logging Anti-Patterns

---

### 1. `puts` / `p` / `pp` in Production Code
**Risk: 3**
**Smell:** AI adds `puts` for "debugging" during generation and never removes it. Goes straight to stdout, bypasses Rails logger, survives to production.

```ruby
# BEFORE (AI slop)
def process_payment(order)
  puts "Processing order #{order.id}"
  result = PaymentGateway.charge(order)
  p result
  result
end
```

```ruby
# AFTER
def process_payment(order)
  Rails.logger.info("payment.processing", order_id: order.id)
  result = PaymentGateway.charge(order)
  Rails.logger.info("payment.complete", order_id: order.id, status: result.status)
  result
end
```

**Safety:** `grep -rn 'puts\|^\s*p ' app/` before every deploy. CI lint rule: `rubocop --only Style/StdoutPuts`.

---

### 2. `Rails.logger.debug` with No Level Discipline
**Risk: 2**
**Smell:** AI logs everything at `.debug` regardless of criticality, or mixes `.debug` and `.info` randomly. In production with `LOG_LEVEL=info`, debug lines disappear — including lines that should be visible.

```ruby
# BEFORE — critical path logs at debug, chatty noise at info
def authenticate_user(token)
  Rails.logger.debug "Authenticating user"          # disappears in prod
  user = User.find_by(token: token)
  Rails.logger.info  "JWT decoded: #{token}"        # WRONG: PII + wrong level
  Rails.logger.debug "Auth complete, user: #{user}" # wrong level AND full object
  user
end
```

```ruby
# AFTER — intentional level discipline
LEVEL GUIDE:
  debug  → internal state useful only when diagnosing a specific bug
  info   → normal lifecycle events (request received, job started, payment charged)
  warn   → degraded but recoverable (cache miss, retry, fallback used)
  error  → something failed that requires attention
  fatal  → app cannot continue

def authenticate_user(token)
  Rails.logger.info("auth.attempt", request_id: Current.request_id)
  user = User.find_by(token: token)

  if user
    Rails.logger.info("auth.success", user_id: user.id, request_id: Current.request_id)
  else
    Rails.logger.warn("auth.failure", request_id: Current.request_id)
  end

  user
end
```

**Safety:** Never change log level in a method body. Set it once in `config/environments/*.rb`.

---

### 3. Logging Full User / Model Objects (PII Exposure)
**Risk: 5**
**Smell:** AI logs the entire AR model or params hash. Email, phone, SSN, tokens, passwords — all in your log aggregator.

```ruby
# BEFORE — catastrophic PII leakage
def create_user(params)
  Rails.logger.info "Creating user with params: #{params}"
  user = User.new(params)
  Rails.logger.debug "User object: #{user.inspect}"
  user.save!
  Rails.logger.info "Created: #{user}"
end
```

```ruby
# AFTER — only stable, non-PII identifiers
SAFE LOG FIELDS: id, uuid, role, account_id, plan, created_at
NEVER LOG: email, name, phone, ssn, dob, ip_address, token, password, card_number

def create_user(params)
  Rails.logger.info("user.create.start", request_id: Current.request_id)
  user = User.new(params)
  user.save!
  Rails.logger.info(
    "user.create.success",
    user_id:    user.id,
    role:       user.role,
    request_id: Current.request_id
  )
end
```

**Safety:** Add a `LogSanitizer` concern that whitelists loggable fields. Audit log aggregator for PII quarterly.

---

### 4. No Structured Logging — String Interpolation Only
**Risk: 3**
**Smell:** AI uses string interpolation for every log line. Log aggregators (Datadog, Splunk, CloudWatch) cannot parse key-value pairs from freeform strings; alerting and dashboards break.

```ruby
# BEFORE — unstructured, unsearchable
Rails.logger.info "User #{user.id} placed order #{order.id} for $#{order.total} at #{Time.current}"
Rails.logger.error "Payment failed for user #{user.id}: #{e.message}"
```

```ruby
# AFTER — structured key-value logging
# Option A: lograge gem (Rails)
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled    = true
  config.lograge.formatter  = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    { request_id: event.payload[:request_id], user_id: event.payload[:user_id] }
  end
end

# Option B: semantic_logger gem
Rails.logger.info "order.placed",
  user_id:    user.id,
  order_id:   order.id,
  total_cents: order.total_cents  # store money as integers

# Option C: plain structured hash (works with any JSON logger)
Rails.logger.info({
  event:      "order.placed",
  user_id:    user.id,
  order_id:   order.id,
  total_cents: order.total_cents,
  request_id: Current.request_id
}.to_json)
```

**Safety:** Log lines with no parseable key=value or JSON structure are a smell. Treat them as tech debt.

---

### 5. Missing Request ID in Log Lines
**Risk: 3**
**Smell:** AI omits the request/correlation ID. You cannot trace a single user request through multiple log lines in production.

```ruby
# BEFORE — impossible to trace across lines
Rails.logger.info "Processing payment"
Rails.logger.error "Payment failed: #{e.message}"
```

```ruby
# AFTER — request_id threaded through every log call

# config/initializers/request_store.rb (uses request_store gem or ActiveSupport::CurrentAttributes)
class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id
end

# app/middleware/request_id_middleware.rb
class RequestIdMiddleware
  def call(env)
    Current.request_id = env["HTTP_X_REQUEST_ID"] || SecureRandom.uuid
    env["HTTP_X_REQUEST_ID"] = Current.request_id
    @app.call(env).tap do |_status, headers, _body|
      headers["X-Request-Id"] = Current.request_id
    end
  end
end

# In any service or model:
Rails.logger.info("payment.processing",
  order_id:   order.id,
  request_id: Current.request_id
)
```

**Safety:** Add `request_id` to every structured log hash. Middleware must set it before any log call fires.

---

### 6. Exception Logging Without Backtrace
**Risk: 4**
**Smell:** AI rescues exceptions and logs only `e.message`. The backtrace — the only thing that tells you where the error actually happened — is silently dropped.

```ruby
# BEFORE — backtrace lost forever
rescue => e
  Rails.logger.error "Something went wrong: #{e.message}"
  nil
end

# ALSO BAD — Airbrake/Sentry not called
rescue PaymentError => e
  Rails.logger.error e.message
end
```

```ruby
# AFTER — full context preserved
rescue => e
  Rails.logger.error(
    "payment.error",
    error_class:   e.class.name,
    error_message: e.message,
    backtrace:     e.backtrace&.first(10)&.join("\n"),
    order_id:      order.id,
    request_id:    Current.request_id
  )
  Sentry.capture_exception(e, extra: { order_id: order.id })
  raise  # or return safe default — document which and why
end
```

**Safety:** Never silently swallow exceptions. Always: log full backtrace OR re-raise OR report to Sentry/Bugsnag. Doing none of the three is a bug.

---

## Python — Logging Anti-Patterns

---

### 7. `print()` in Production Code
**Risk: 3**
**Smell:** AI uses `print()` for everything. Goes to stdout only, no level, no timestamp, no context, no aggregation.

```python
# BEFORE (AI slop)
def create_user(data: dict) -> User:
    print(f"Creating user: {data}")
    user = User(**data)
    db.add(user)
    print(f"User created: {user}")
    return user
```

```python
# AFTER
import structlog

logger = structlog.get_logger(__name__)

def create_user(data: dict) -> User:
    logger.info("user.create.start", request_id=get_request_id())
    user = User(**data)
    db.add(user)
    logger.info("user.create.success", user_id=user.id, role=user.role)
    return user
```

**Safety:** `grep -rn 'print(' app/ src/` in CI. Flake8 rule: `flake8 --select=T20` with `flake8-print`.

---

### 8. `logging.basicConfig()` in Library Code
**Risk: 4**
**Smell:** AI calls `logging.basicConfig()` at module level in a library or shared module. This permanently configures the root logger — any application importing the library gets its logging clobbered. Side effects survive across test runs.

```python
# BEFORE — library code poisoning the root logger
# mypackage/utils.py
import logging

logging.basicConfig(level=logging.DEBUG, format="%(message)s")  # NEVER in a library

logger = logging.getLogger("mypackage")

def do_thing():
    logger.debug("doing thing")
```

```python
# AFTER — library code is config-neutral
# mypackage/utils.py
import logging

# Named logger only — never touch root logger configuration
logger = logging.getLogger(__name__)  # "mypackage.utils"

def do_thing():
    logger.debug("doing thing")

# basicConfig() belongs ONLY in application entry points:
# main.py / app.py / manage.py / conftest.py (test setup)
```

**Safety:** Grep your library packages for `basicConfig`. Add a lint check. Configure logging in exactly one place: the application entry point or a dedicated `logging_config.py`.

---

### 9. Root Logger Usage — Missing `getLogger(__name__)`
**Risk: 3**
**Smell:** AI uses `logging.info()` / `logging.error()` directly (the root logger) instead of a named module logger. You lose the module name from log output, cannot silence specific modules, and cannot configure hierarchy-based filtering.

```python
# BEFORE — root logger, no module context
import logging

def process_payment(order_id: str) -> dict:
    logging.info(f"Processing {order_id}")   # root logger
    logging.error("Payment failed")           # root logger — which module? no idea
```

```python
# AFTER — named module logger
import logging

logger = logging.getLogger(__name__)  # one line, top of module, always

def process_payment(order_id: str) -> dict:
    logger.info("payment.processing", extra={"order_id": order_id})
    logger.error("payment.failed",    extra={"order_id": order_id})
```

**Safety:** Every Python file that logs must have `logger = logging.getLogger(__name__)` at module scope. Add a custom flake8 rule or pre-commit hook to enforce it.

---

### 10. No Log Level Discipline — Everything at INFO
**Risk: 2**
**Smell:** AI logs every function entry, loop iteration, and branch at `INFO`. In production this creates log spam that masks real signals. Operators disable logging entirely just to survive.

```python
# BEFORE — INFO flood
def sync_products(products: list[dict]) -> None:
    logger.info("Starting product sync")
    for product in products:
        logger.info(f"Processing product {product['id']}")  # N lines per sync
        update_product(product)
        logger.info(f"Product {product['id']} done")        # N more lines
    logger.info("Sync complete")
```

```python
# AFTER — right level for each signal
LEVEL GUIDE (Python):
  DEBUG    → per-item loop progress, internal state, verbose tracing
  INFO     → job started/completed, user actions, state transitions
  WARNING  → retried, fell back, degraded — recoverable
  ERROR    → failed operation, requires attention but app continues
  CRITICAL → app cannot continue, immediate page

def sync_products(products: list[dict]) -> None:
    logger.info("product_sync.start", count=len(products))
    for product in products:
        logger.debug("product_sync.item", product_id=product["id"])
        update_product(product)
    logger.info("product_sync.complete", count=len(products))
```

**Safety:** If you find yourself writing `logger.info` inside a for loop, ask whether `logger.debug` is more appropriate.

---

### 11. Missing Exception Info in `logger.error()`
**Risk: 4**
**Smell:** AI calls `logger.error(str(e))` without `exc_info=True` or `logger.exception()`. The traceback — the only way to find the line that failed — is permanently lost.

```python
# BEFORE — traceback discarded
try:
    result = call_payment_api(order)
except PaymentError as e:
    logger.error(f"Payment failed: {e}")  # message only, no traceback
    return None

# ALSO WRONG — catching Exception and logging message only
except Exception as e:
    logger.error("Unexpected error")  # not even the message
    return {}
```

```python
# AFTER — full traceback preserved

# Option A: logger.exception() — automatically includes exc_info
try:
    result = call_payment_api(order)
except PaymentError as e:
    logger.exception("payment.failed", order_id=order.id)
    raise  # or return safe fallback — document which and why

# Option B: logger.error() with exc_info=True (same result, more explicit)
except PaymentError as e:
    logger.error("payment.failed", exc_info=True, order_id=order.id)

# Option C: structlog
except PaymentError as e:
    logger.error("payment.failed", exc_info=e, order_id=order.id)
```

**Safety:** `logger.exception()` is almost always correct inside `except` blocks. If you find `logger.error()` inside an `except` block without `exc_info=True`, treat it as a bug.

---

### 12. Correct Python Logging Pattern (Reference)

```python
# logging_config.py — configure once at app entry point
import logging
import logging.config
import sys

LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(name)s %(levelname)s %(message)s",
        },
    },
    "handlers": {
        "stdout": {
            "class":     "logging.StreamHandler",
            "stream":    sys.stdout,
            "formatter": "json",
        },
    },
    "root": {
        "handlers": ["stdout"],
        "level":    "INFO",
    },
    "loggers": {
        "myapp": {"level": "DEBUG"},   # verbose for your own code
        "sqlalchemy.engine": {"level": "WARNING"},  # silence chatty deps
    },
}

logging.config.dictConfig(LOGGING_CONFIG)

# OR with structlog (preferred):
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
)

# In every module:
logger = structlog.get_logger(__name__)

# Bind request context once per request (FastAPI middleware example):
import structlog.contextvars

@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        request_id=request.headers.get("x-request-id", str(uuid4())),
        path=request.url.path,
        method=request.method,
    )
    return await call_next(request)
```

---

## JavaScript / TypeScript — Logging Anti-Patterns

---

### 13. `console.log` / `console.debug` / `console.error` in Production Code
**Risk: 3**
**Smell:** AI scaffolds every function with `console.log`. No levels, no structured output, no way to disable, no aggregation.

```typescript
// BEFORE (AI slop)
async function createOrder(data: CreateOrderDTO) {
  console.log("Creating order:", data);          // PII in data
  const order = await db.orders.create(data);
  console.log("Order created:", order);
  console.error("Something might be wrong");     // not even a real error
  return order;
}
```

```typescript
// AFTER
import { logger } from "@/lib/logger";           // your pino/winston wrapper

async function createOrder(data: CreateOrderDTO) {
  logger.info({ event: "order.create.start", userId: data.userId });
  const order = await db.orders.create(data);
  logger.info({ event: "order.create.success", orderId: order.id, userId: order.userId });
  return order;
}
```

**Safety:** ESLint rule: `"no-console": "error"` in `.eslintrc`. Allow only in CLI scripts explicitly. CI enforces.

---

### 14. No Structured Logging — Plain String Messages
**Risk: 3**
**Smell:** AI uses `winston.info("User 123 did thing")` — freeform strings, nothing parseable. Log aggregators cannot alert on `userId` or `orderId`.

```typescript
// BEFORE — unsearchable strings
logger.info(`User ${userId} placed order ${orderId} for ${total}`);
logger.error(`Payment failed for user ${userId}: ${errorMessage}`);
```

```typescript
// AFTER — structured with pino (recommended for Node.js)
import pino from "pino";

export const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
  redact: {
    paths: ["req.headers.authorization", "*.password", "*.token", "*.email", "*.ssn"],
    censor: "[REDACTED]",
  },
  transport:
    process.env.NODE_ENV === "development"
      ? { target: "pino-pretty" }
      : undefined,   // JSON in production — no pretty-printing
});

// Usage — always an object, never a template string as the first arg
logger.info({ event: "order.placed", orderId, userId, totalCents });
logger.error({ event: "payment.failed", orderId, userId, err });  // pino serializes Error objects
```

**Safety:** Pino serializes `Error` objects correctly when passed as `{ err }`. Pass the Error object, not `err.message`.

---

### 15. Logging Full Request / Response Bodies (PII / Token Leakage)
**Risk: 5**
**Smell:** AI logs `req.body` or the full API response to debug auth issues. Access tokens, passwords, credit card numbers, and PII end up in Datadog / CloudWatch forever.

```typescript
// BEFORE — catastrophic
app.use((req, res, next) => {
  console.log("Request body:", req.body);   // passwords, tokens, PII
  next();
});

async function callPaymentAPI(payload: PaymentPayload) {
  const response = await fetch(PAYMENT_URL, { body: JSON.stringify(payload) });
  const data = await response.json();
  logger.debug("Payment API response:", data);  // card numbers in response
  return data;
}
```

```typescript
// AFTER — whitelist safe fields, redact everything else
import pino from "pino";
import { pinoHttp } from "pino-http";

// pino-http with redact — applied at the logger level, not per-call
export const httpLogger = pinoHttp({
  logger,
  customLogLevel: (res, err) => (err || res.statusCode >= 500 ? "error" : "info"),
  serializers: {
    req(req) {
      return {
        method:    req.method,
        url:       req.url,
        requestId: req.id,
        // NEVER: req.body, req.headers.authorization, req.headers.cookie
      };
    },
    res(res) {
      return { statusCode: res.statusCode };
    },
  },
});

// For outbound API calls — log metadata, never the body
async function callPaymentAPI(payload: PaymentPayload) {
  const start = Date.now();
  const response = await fetch(PAYMENT_URL, { body: JSON.stringify(payload) });
  logger.info({
    event:      "payment_api.call",
    statusCode: response.status,
    durationMs: Date.now() - start,
    orderId:    payload.orderId,
    // NEVER: payload itself (contains card data), response body
  });
}
```

**Safety:** Treat `req.body`, `req.headers.authorization`, and any external API response body as toxic until proven safe. Default to redaction.

---

### 16. Missing Correlation / Trace IDs
**Risk: 3**
**Smell:** AI logs events in isolation with no shared identifier. You cannot join log lines from a single HTTP request across services or even within a single request's lifecycle.

```typescript
// BEFORE — no way to correlate these three lines
logger.info("Starting checkout");
logger.warn("Inventory check slow");
logger.error("Checkout failed");
```

```typescript
// AFTER — correlation ID via AsyncLocalStorage (Node.js 12.17+)
import { AsyncLocalStorage } from "node:async_hooks";
import { randomUUID } from "node:crypto";

const requestContext = new AsyncLocalStorage<{ requestId: string; userId?: string }>();

// Express / Fastify middleware
export function correlationMiddleware(req: Request, res: Response, next: NextFunction) {
  const requestId = (req.headers["x-request-id"] as string) ?? randomUUID();
  res.setHeader("x-request-id", requestId);
  requestContext.run({ requestId, userId: req.user?.id }, next);
}

// Logger wrapper that auto-injects context
export function getLogger(module: string) {
  return {
    info:  (obj: object, msg?: string) => logger.info({ ...requestContext.getStore(), module, ...obj }, msg),
    warn:  (obj: object, msg?: string) => logger.warn({ ...requestContext.getStore(), module, ...obj }, msg),
    error: (obj: object, msg?: string) => logger.error({ ...requestContext.getStore(), module, ...obj }, msg),
  };
}

// Every log line now automatically includes requestId and userId
const log = getLogger("checkout");
log.info({ event: "checkout.start", orderId });
log.warn({ event: "inventory.slow", durationMs: 450 });
log.error({ event: "checkout.failed", err, orderId });
```

**Safety:** Forward `x-request-id` to all downstream service calls. Never generate a new ID mid-request.

---

### 17. Sync File Logging Blocking the Event Loop
**Risk: 4**
**Smell:** AI configures Winston with a `FileTransport` or writes to a file synchronously. Any I/O spike blocks the entire Node.js event loop.

```typescript
// BEFORE — sync file write blocks event loop
import winston from "winston";

const logger = winston.createLogger({
  transports: [
    new winston.transports.File({ filename: "app.log" }),  // async but unbuffered
    new winston.transports.File({
      filename: "app.log",
      options: { flags: "a" },
      // fs.writeFileSync under the hood in some versions — blocks
    }),
  ],
});

// ALSO BAD — writing to file at all in a 12-factor app
```

```typescript
// AFTER — write to stdout, let infrastructure handle log routing
import pino from "pino";

// pino writes to stdout asynchronously via pino-worker in pino v8+
// or use pino.destination() for buffered writes
export const logger = pino(
  { level: process.env.LOG_LEVEL ?? "info" },
  // In prod: stdout only. Let Docker/Kubernetes/systemd route logs.
  process.stdout
);

// If you truly need file output (local dev, legacy):
import { createWriteStream } from "node:fs";
import { join } from "node:path";
import pino from "pino";

const dest = pino.destination({
  dest: join(process.cwd(), "logs", "app.log"),
  sync: false,   // CRITICAL: async writes
  minLength: 4096, // buffer 4KB before flushing
});
export const logger = pino({ level: "info" }, dest);

// Flush on exit
process.on("exit", () => dest.flushSync());
```

**Safety:** In containerized environments: stdout only, always. Never write log files inside a container. Let your log shipper (Fluentd, Filebeat, Cloudwatch agent) handle it.

---

---

## PART 2: CONFIGURATION / ENVIRONMENT ANTI-PATTERNS

---

## All Stacks — Hardcoded Values

---

### 18. API Keys, Credentials, and Secrets in Source Code
**Risk: 5**
**Smell:** AI hardcodes secrets "to make the example work." These end up committed, pushed, and indexed by GitHub. Rotation requires code changes. One public repo exposure and you're rotated by your vendor.

```ruby
# BEFORE — Ruby (also seen in Python, JS identically)
STRIPE_SECRET = "sk_live_51HZz..."        # real key
DATABASE_URL   = "postgres://admin:s3cr3t@prod-db.internal/app"
OPENAI_API_KEY = "sk-proj-abc123..."
JWT_SECRET     = "my-super-secret-key"
```

```python
# BEFORE — Python
SENDGRID_API_KEY = "SG.abc123..."
AWS_SECRET_ACCESS_KEY = "wJalrXUt..."
```

```typescript
// BEFORE — TypeScript / Next.js
const STRIPE_SECRET = "sk_live_...";
const DB_PASSWORD = "hunter2";
```

```bash
# AFTER — for every stack: use environment variables
# .env.example (committed — shows shape, not values)
STRIPE_SECRET_KEY=
DATABASE_URL=
OPENAI_API_KEY=
JWT_SECRET=

# .env (never committed — real values, gitignored)
# .gitignore must include: .env, .env.local, .env.*.local
```

**Safety:** Run `git secrets --scan` or `truffleHog` in CI pre-merge. Add `detect-secrets` as a pre-commit hook. If a secret is ever committed: rotate it immediately — do not rely on history rewriting.

---

### 19. Magic Numbers Without Named Constants
**Risk: 2**
**Smell:** AI scatters literal numbers throughout business logic. The number has no name, no unit, no explanation.

```ruby
# BEFORE
sleep(30)
user.update(session_timeout: 3600)
if order.total > 10000
  apply_discount(0.15)
end
```

```python
# BEFORE
if len(results) > 100:
    paginate(results, 20)
time.sleep(5)
```

```typescript
// BEFORE
if (user.failedAttempts >= 5) lockAccount(user);
const token = jwt.sign(payload, secret, { expiresIn: 86400 });
```

```ruby
# AFTER — Ruby
MAX_CHECKOUT_WAIT_SECONDS    = 30
SESSION_TIMEOUT_SECONDS      = 1.hour.to_i
BULK_DISCOUNT_THRESHOLD_CENTS = 10_000_00
BULK_DISCOUNT_RATE            = 0.15

sleep(MAX_CHECKOUT_WAIT_SECONDS)
user.update(session_timeout: SESSION_TIMEOUT_SECONDS)
apply_discount(BULK_DISCOUNT_RATE) if order.total_cents > BULK_DISCOUNT_THRESHOLD_CENTS
```

```python
# AFTER — Python
MAX_RESULTS_PER_PAGE = 20
RESULTS_PAGINATION_THRESHOLD = 100
RETRY_DELAY_SECONDS = 5

if len(results) > RESULTS_PAGINATION_THRESHOLD:
    paginate(results, MAX_RESULTS_PER_PAGE)
```

```typescript
// AFTER — TypeScript
const MAX_FAILED_AUTH_ATTEMPTS = 5;
const JWT_EXPIRY_SECONDS = 86_400; // 24 hours

if (user.failedAttempts >= MAX_FAILED_AUTH_ATTEMPTS) lockAccount(user);
const token = jwt.sign(payload, secret, { expiresIn: JWT_EXPIRY_SECONDS });
```

**Safety:** Constants that come from environment config should still be named, but read from env: `MAX_RETRIES = Integer(ENV.fetch("MAX_RETRIES", 3))`.

---

### 20. Environment-Specific Logic in Business Code
**Risk: 3**
**Smell:** AI inlines `if Rails.env.production?` / `if process.env.NODE_ENV === "production"` inside service classes and models. Business logic and deployment logic become inseparable. Testing becomes impossible without faking env.

```ruby
# BEFORE — environment check buried in a service
class PaymentService
  def charge(order)
    if Rails.env.production?
      StripeGateway.charge(order)
    else
      FakeGateway.charge(order)   # what does staging use? nobody knows
    end
  end
end
```

```python
# BEFORE
def send_email(to: str, body: str):
    if os.environ.get("ENV") == "production":
        SendGrid().send(to, body)
    else:
        print(f"[DEV] Would send to {to}: {body}")
```

```ruby
# AFTER — inject the dependency; never check env in business code
# config/initializers/payment_gateway.rb
PAYMENT_GATEWAY = Rails.env.production? ? StripeGateway : FakeGateway

# Or better — drive it from config:
PAYMENT_GATEWAY = ENV.fetch("PAYMENT_GATEWAY", "fake") == "stripe" ? StripeGateway : FakeGateway

class PaymentService
  def initialize(gateway: PAYMENT_GATEWAY)
    @gateway = gateway
  end

  def charge(order)
    @gateway.charge(order)  # no env check here
  end
end
```

**Safety:** `grep -rn 'Rails.env\.\|NODE_ENV\|os.environ.*prod' app/` — every hit is a candidate for extraction.

---

## Ruby / Rails — ENV and Configuration Anti-Patterns

---

### 21. `ENV['KEY']` with No Default and No Validation (Silent Nil)
**Risk: 4**
**Smell:** AI uses bare `ENV['KEY']` which returns `nil` silently when the variable is missing. The nil propagates until it causes a confusing error far from the source.

```ruby
# BEFORE — silent nil, confusing downstream error
database_url = ENV['DATABASE_URL']           # nil in dev if not set
api_key      = ENV['STRIPE_SECRET_KEY']      # nil → NoMethodError on nil later
timeout      = ENV['REQUEST_TIMEOUT'].to_i   # nil.to_i == 0 — silent logic bug
```

```ruby
# AFTER — fail fast with context
# Required (no sensible default):
database_url = ENV.fetch("DATABASE_URL")
api_key      = ENV.fetch("STRIPE_SECRET_KEY")

# Optional with typed default:
timeout_secs = Integer(ENV.fetch("REQUEST_TIMEOUT_SECONDS", "30"))
log_level    = ENV.fetch("LOG_LEVEL", "info")
max_retries  = Integer(ENV.fetch("MAX_RETRIES", "3"))

# Validate at boot — use a config initializer:
# config/initializers/required_env.rb
REQUIRED_ENV_VARS = %w[
  DATABASE_URL
  STRIPE_SECRET_KEY
  REDIS_URL
  JWT_SECRET
].freeze

missing = REQUIRED_ENV_VARS.reject { |var| ENV[var].present? }
raise "Missing required environment variables: #{missing.join(', ')}" if missing.any?
```

**Safety:** `ENV.fetch` raises `KeyError` immediately at boot. `ENV[]` raises nothing — the error surfaces later, in a different place, with a misleading message.

---

### 22. `Rails.application.credentials` vs ENV — When to Use Each
**Risk: 3**
**Smell:** AI mixes credentials and ENV variables without a clear rule. Secrets end up in the wrong store, or the `master.key` is committed.

```ruby
# BEFORE — confused mixing
api_key = Rails.application.credentials.stripe[:secret_key]  # fine for some uses
db_pass = ENV['DB_PASSWORD']  # also fine — but which pattern wins?
redis_url = Rails.application.credentials.dig(:redis, :url)  # wrong: this is infra config
```

```ruby
# AFTER — clear rule
#
# USE Rails.application.credentials for:
#   - Third-party API secrets (Stripe, SendGrid, Twilio keys)
#   - OAuth client secrets
#   - JWT signing secrets
#   - Anything that is the SAME across all developer laptops but secret
#   - Values encrypted in credentials.yml.enc, key NOT in repo
#
# USE ENV variables for:
#   - Database URLs (change per environment / per deploy)
#   - Redis URLs, queue URLs
#   - Feature flags
#   - Infrastructure addresses (S3 bucket names, CDN URLs)
#   - Anything that DIFFERS per environment (dev / staging / prod)
#   - Anything managed by your deployment platform (Heroku, Fly.io, Render)
#
# NEVER commit master.key or config/credentials/*.key
# .gitignore must include: config/master.key config/credentials/*.key

# config/initializers/stripe.rb
Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) ||
                 ENV.fetch("STRIPE_SECRET_KEY")
```

---

### 23. `config/database.yml` with Hardcoded Passwords
**Risk: 5**
**Smell:** AI writes literal credentials into `config/database.yml`. This file is almost always committed.

```yaml
# BEFORE
production:
  adapter: postgresql
  database: myapp_production
  host: prod-db.internal
  username: myapp
  password: s3cr3tp@ssw0rd   # committed to git
```

```yaml
# AFTER — environment variable interpolation
production:
  adapter:  postgresql
  url:      <%= ENV.fetch("DATABASE_URL") %>
  pool:     <%= Integer(ENV.fetch("DB_POOL", "5")) %>
  timeout:  5000

# Or the expanded form if you need individual fields:
production:
  adapter:  postgresql
  host:     <%= ENV.fetch("DB_HOST") %>
  database: <%= ENV.fetch("DB_NAME") %>
  username: <%= ENV.fetch("DB_USERNAME") %>
  password: <%= ENV.fetch("DB_PASSWORD") %>
  pool:     <%= Integer(ENV.fetch("DB_POOL", "5")) %>
```

**Safety:** `git log --all -S 'password:' -- config/database.yml` — if this returns anything, rotate immediately. Prefer `DATABASE_URL` as a single atomic env var; it's easier to rotate and manage.

---

## Python — ENV and Configuration Anti-Patterns

---

### 24. `os.environ['KEY']` Without `.get()` or Default → KeyError in Production
**Risk: 4**
**Smell:** AI uses `os.environ['KEY']` which raises `KeyError` on missing vars. Unlike Rails `ENV.fetch`, this surfaces at runtime when the code path is hit — which might be hours after deploy.

```python
# BEFORE — KeyError surface delayed until code path is hit
import os

STRIPE_KEY = os.environ['STRIPE_SECRET_KEY']       # crashes at import if missing
DB_URL     = os.environ['DATABASE_URL']
TIMEOUT    = int(os.environ['TIMEOUT'])             # KeyError before int()

# ALSO WRONG — silent None, logic bug
DEBUG = os.environ.get('DEBUG')                     # None if missing, not False
```

```python
# AFTER — Option A: os.environ with explicit validation (stdlib, no deps)
import os

def require_env(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise RuntimeError(f"Required environment variable '{key}' is not set")
    return value

STRIPE_KEY = require_env("STRIPE_SECRET_KEY")
DB_URL     = require_env("DATABASE_URL")
TIMEOUT    = int(os.environ.get("TIMEOUT_SECONDS", "30"))
DEBUG      = os.environ.get("DEBUG", "false").lower() == "true"

# AFTER — Option B: Pydantic BaseSettings (preferred for FastAPI / any modern app)
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    stripe_secret_key: str                   # required — fails fast at startup
    database_url: str                         # required
    redis_url: str = "redis://localhost:6379" # optional with default
    debug: bool = False                       # type-coerced automatically
    timeout_seconds: int = 30
    log_level: str = "INFO"

settings = Settings()  # raises ValidationError at startup if required vars missing
```

**Safety:** Use Pydantic `BaseSettings` for any project with more than ~5 env vars. The startup validation and type coercion eliminate an entire class of production surprises.

---

### 25. `.env` File Loaded in Production
**Risk: 4**
**Smell:** AI adds `load_dotenv()` unconditionally in `main.py` or `settings.py`. In production, there is no `.env` file — but if there is, it overrides your actual environment variables, breaking 12-factor.

```python
# BEFORE — unconditional dotenv load
from dotenv import load_dotenv

load_dotenv()  # silently does nothing if .env absent; dangerous if .env present in prod

STRIPE_KEY = os.environ["STRIPE_SECRET_KEY"]
```

```python
# AFTER — dotenv only in development/test
import os
from dotenv import load_dotenv

# Only load .env in non-production environments
if os.environ.get("APP_ENV", "development") not in ("production", "staging"):
    load_dotenv(override=False)  # override=False: real env vars win over .env values

# OR with Pydantic BaseSettings — handles this automatically:
class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env" if os.environ.get("APP_ENV", "dev") == "dev" else None,
    )
```

**Safety:** In production, environment variables come from your platform (ECS task definition, Kubernetes Secret, Heroku config vars). `.env` should not exist on production hosts. If it does, it's a security risk.

---

## JavaScript / TypeScript — ENV and Configuration Anti-Patterns

---

### 26. `process.env.KEY` Without Validation Schema
**Risk: 4**
**Smell:** AI accesses `process.env.KEY` directly throughout the codebase. Types are always `string | undefined`. No validation at startup. Missing vars cause runtime failures at unpredictable points.

```typescript
// BEFORE — unvalidated, untyped, scattered
const stripeKey = process.env.STRIPE_SECRET_KEY;  // string | undefined
const port      = parseInt(process.env.PORT!);     // NaN if PORT is missing
const debug     = process.env.DEBUG === "true";    // works but not validated centrally
```

```typescript
// AFTER — zod schema validated at startup
// lib/env.ts
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV:           z.enum(["development", "test", "production"]),
  PORT:               z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL:       z.string().url(),
  STRIPE_SECRET_KEY:  z.string().startsWith("sk_"),
  REDIS_URL:          z.string().url().default("redis://localhost:6379"),
  LOG_LEVEL:          z.enum(["debug", "info", "warn", "error"]).default("info"),
  JWT_SECRET:         z.string().min(32),
  DEBUG:              z.coerce.boolean().default(false),
});

// Parse at module load — throws ZodError at startup if invalid
export const env = envSchema.parse(process.env);

// Usage — fully typed, no `| undefined`
import { env } from "@/lib/env";
const stripe = new Stripe(env.STRIPE_SECRET_KEY);
app.listen(env.PORT);
```

**Safety:** Import `env` from the central module everywhere. Never access `process.env` directly outside `lib/env.ts`. Add ESLint rule: `no-restricted-syntax` to ban `process.env` access outside the env module.

---

### 27. Next.js `publicRuntimeConfig` Exposing Server Secrets to Client
**Risk: 5**
**Smell:** AI puts server-side secrets in `publicRuntimeConfig` in `next.config.js`. Anything in `publicRuntimeConfig` is serialized into the client bundle and sent to every browser.

```javascript
// BEFORE — secret sent to every browser
// next.config.js
module.exports = {
  publicRuntimeConfig: {
    stripeSecretKey: process.env.STRIPE_SECRET_KEY,  // exposed to browsers
    databaseUrl:     process.env.DATABASE_URL,        // exposed to browsers
    jwtSecret:       process.env.JWT_SECRET,          // exposed to browsers
  },
};
```

```javascript
// AFTER — correct Next.js env variable routing
// next.config.js
module.exports = {
  // serverRuntimeConfig: available only on server (API routes, getServerSideProps)
  serverRuntimeConfig: {
    stripeSecretKey: process.env.STRIPE_SECRET_KEY,
    databaseUrl:     process.env.DATABASE_URL,
  },
  // publicRuntimeConfig: sent to client — ONLY non-secret, truly public values
  publicRuntimeConfig: {
    apiBaseUrl:  process.env.NEXT_PUBLIC_API_URL,
    appName:     "MyApp",
  },
};

// Better: use NEXT_PUBLIC_ prefix convention (no runtime config needed)
// NEXT_PUBLIC_* → available on client (use only for truly public values)
// Everything else → server only

// app/lib/env.ts (server-only)
import { z } from "zod";
import "server-only"; // Next.js 13+ — import fails if used in client component

export const serverEnv = z.object({
  STRIPE_SECRET_KEY: z.string(),
  DATABASE_URL:      z.string().url(),
}).parse(process.env);
```

**Safety:** Any env var not prefixed `NEXT_PUBLIC_` is server-only in Next.js App Router. Use the `server-only` package to enforce boundaries. Audit the client bundle with `next build --analyze` to verify no secrets leak.

---

### 28. Hardcoded `localhost` URLs
**Risk: 3**
**Smell:** AI hardcodes `http://localhost:3000` or `http://localhost:8080` in API clients and config files. Works only on the developer's machine. Breaks in CI, staging, production, and Docker containers.

```typescript
// BEFORE — machine-specific, works nowhere but your laptop
const API_BASE = "http://localhost:3000/api";
const REDIS_URL = "redis://localhost:6379";

fetch(`http://localhost:3000/api/users`);
new Redis({ host: "localhost", port: 6379 });
```

```typescript
// AFTER — driven by environment
// lib/env.ts (see pattern 26 for full schema)
const envSchema = z.object({
  API_BASE_URL: z.string().url().default("http://localhost:3000/api"),
  REDIS_URL:    z.string().url().default("redis://localhost:6379"),
});

// Usage
fetch(`${env.API_BASE_URL}/users`);
new Redis(env.REDIS_URL);

// .env.example
API_BASE_URL=http://localhost:3000/api

// .env.production (platform env vars, not committed)
API_BASE_URL=https://api.myapp.com
```

**Safety:** `grep -rn 'localhost' src/ --include='*.ts' --include='*.js'` — every hit outside test files and dev defaults is a candidate for environment configuration.

---

## Quick Reference — Risk Matrix

| # | Anti-Pattern | Stack | Risk |
|---|---|---|---|
| 1 | `puts`/`p` in production | Ruby | 3 |
| 2 | No log level discipline | Ruby | 2 |
| 3 | Logging full user objects (PII) | Ruby | **5** |
| 4 | No structured logging | Ruby | 3 |
| 5 | Missing request ID | Ruby | 3 |
| 6 | Exception without backtrace | Ruby | 4 |
| 7 | `print()` in production | Python | 3 |
| 8 | `basicConfig()` in library | Python | 4 |
| 9 | Root logger / missing `getLogger` | Python | 3 |
| 10 | Everything logged at INFO | Python | 2 |
| 11 | `logger.error()` without `exc_info` | Python | 4 |
| 13 | `console.log` in production | JS/TS | 3 |
| 14 | Unstructured log strings | JS/TS | 3 |
| 15 | Logging req/res bodies (PII) | JS/TS | **5** |
| 16 | Missing correlation IDs | JS/TS | 3 |
| 17 | Sync file logging | JS/TS | 4 |
| 18 | Secrets in source code | All | **5** |
| 19 | Magic numbers | All | 2 |
| 20 | Env-specific logic in business code | All | 3 |
| 21 | `ENV['KEY']` silent nil | Ruby | 4 |
| 22 | credentials vs ENV confusion | Ruby | 3 |
| 23 | Hardcoded password in database.yml | Ruby | **5** |
| 24 | `os.environ['KEY']` KeyError | Python | 4 |
| 25 | `.env` loaded in production | Python | 4 |
| 26 | `process.env` without zod schema | JS/TS | 4 |
| 27 | `publicRuntimeConfig` with secrets | JS/TS | **5** |
| 28 | Hardcoded `localhost` URLs | JS/TS | 3 |

---

## Deslopper Decision Rules

When reviewing AI-generated code, apply these checks in order:

1. **Secret scan first.** Any literal that looks like a key, password, or token → Risk 5, fix immediately before anything else.
2. **Check all `rescue`/`except`/`catch` blocks.** Missing backtrace/exc_info → silent incident.
3. **Check all log calls.** Full objects? PII fields? No request_id? String interpolation only?
4. **Check all env var access.** Bare `ENV[]` / `os.environ[]` / `process.env.X` with no validation?
5. **Check for env-specific conditionals in non-config files.** Any `Rails.env.production?` or `NODE_ENV === 'production'` outside `config/` → restructure.
6. **Check `console.log` / `puts` / `print`.** Every occurrence is a candidate for removal or replacement.
