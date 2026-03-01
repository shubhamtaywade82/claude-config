# Rails Best Practices — Security, Timeouts, Performance, Views & Routes

## SECURITY

**Never `rescue Exception` — only `rescue StandardError`:**
```ruby
# Bad — swallows Ctrl+C, SIGTERM, NoMemoryError
rescue Exception => e

# Good
rescue StandardError => e
rescue ActiveRecord::RecordNotFound, ArgumentError => e  # specific is better
```

**Always check or use `save!` — never silently discard failures:**
```ruby
# Bad — silent failure
@order.save

# Good
@order.save!  # raises ActiveRecord::RecordInvalid

# or
unless @order.save
  Rails.logger.error("Order save failed: #{@order.errors.full_messages}")
  raise OrderSaveError
end
```

**Use `Time.current`/`Time.zone.now` — never `Time.now`:**
```ruby
Time.current          # Good — respects configured timezone
Time.zone.now         # Good
Time.zone.parse(str)  # Good
Time.now              # Bad — system timezone
Time.parse(str)       # Bad — system timezone
'2024-01-01'.to_time  # Bad — system timezone
```

**Use Brakeman for static security analysis:**
```bash
gem install brakeman
brakeman -A  # all checks
```

**Strong Parameters — always whitelist:**
```ruby
def order_params
  params.require(:order).permit(:quantity, :price, :symbol)
  # Never: params[:order]  or  params.require(:order).permit!
end
```

---

## TIMEOUTS

An unresponsive service is worse than a down one — it causes cascading failures.

**Never use Ruby's `Timeout` module** — it uses unsafe thread interruption that corrupts state.
Use library-specific timeouts instead.

**Database statement timeouts (PostgreSQL):**
```yaml
# config/database.yml
production:
  variables:
    statement_timeout: 5s
  connect_timeout: 1
  checkout_timeout: 1
```

**Database statement timeouts (MySQL):**
```yaml
production:
  variables:
    max_execution_time: 5000  # milliseconds
  connect_timeout: 1
  read_timeout: 1
  write_timeout: 1
  checkout_timeout: 1
```

**HTTP clients — always set timeouts:**
```ruby
# Faraday
Faraday.new(url, request: { open_timeout: 2, timeout: 5 })

# HTTParty
class BrokerClient
  include HTTParty
  open_timeout 2
  read_timeout 5
end

# Net::HTTP
Net::HTTP.start(host, port, open_timeout: 2, read_timeout: 5) { |http| ... }
```

**Redis:**
```ruby
Redis.new(connect_timeout: 1, timeout: 1)
```

**Puma worker timeout:**
```ruby
# config/puma.rb
worker_timeout 15
worker_shutdown_timeout 8
```

**Rack::Timeout / Slowpoke for request-level timeouts:**
```ruby
# config/initializers/slowpoke.rb
Slowpoke.timeout = 10  # Safer than raw Rack::Timeout

# Or Rack::Timeout with process termination (safer)
use Rack::Timeout, service_timeout: 15, term_on_timeout: true
```

**ActionMailer SMTP:**
```ruby
ActionMailer::Base.smtp_settings = { open_timeout: 2, read_timeout: 5 }
```

**Always send emails in background jobs — never inline in requests.**

**Regexp timeout (ReDoS prevention, Ruby 3.2+):**
```ruby
Regexp.timeout = 1.0  # global guard against catastrophic backtracking
```

---

## PERFORMANCE

**Memoize expensive calls with `||=` (or `defined?` for nil results):**
```ruby
def risk_engine
  @risk_engine ||= RiskEngine.new(account)
end

def current_user_preference
  return @preference if defined?(@preference)
  @preference = current_user.preferences.find_by(key: 'theme')
end
```

**`select` specific columns — avoid `SELECT *` when possible:**
```ruby
# Bad — loads full objects including large text columns
User.all.map(&:email)

# Good — minimal data transfer
User.pluck(:id, :email)
User.select(:id, :email).map { |u| [u.id, u.email] }
```

**Use fragment/Russian doll caching for expensive view segments:**
```erb
<% cache [@post, @post.updated_at] do %>
  <%= render @post %>
<% end %>
```

**Use `after_commit` not `after_save` for cache invalidation:**
```ruby
after_commit :expire_cache
```

---

## VIEWS

**Use `render collection:` for iteration — faster than loops:**
```ruby
render @posts              # Good — shorthand, batched rendering
render partial: 'post', collection: @posts  # Also good
@posts.each { |p| render p }               # Bad — slow
```

**No model layer calls in views — use helpers/decorators:**
```ruby
# Bad
<% User.active.each do |u| %>

# Good — controller sets @active_users
<% @active_users.each do |u| %>
```

**HTTP status symbols — self-documenting:**
```ruby
render status: :forbidden   # Good
render status: :unprocessable_entity
render status: 403          # Bad
```

---

## ROUTES

**Restrict generated routes with `:only`/`:except`:**
```ruby
resources :comments, only: [:create, :destroy]   # Good
resources :comments  # Bad — exposes 7 routes when you need 2
```

**Avoid deep nesting — use `shallow: true`:**
```ruby
resources :posts do
  resources :comments, shallow: true  # Good
end

resources :posts do
  resources :comments do
    resources :likes  # Bad — 3 levels deep, unwieldy helpers
  end
end
```

**Custom routes signal a missing resource (> 2–3 = red flag):**
```ruby
# Bad — too many custom actions on posts
resources :posts do
  member do
    get :preview
    patch :publish
    patch :archive
    patch :feature
  end
end

# Good — extract to new resources
resources :posts do
  resource :publication, only: [:create, :destroy]
  resource :archive, only: [:create, :destroy]
end
```

**Split large route files:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  draw :api
  draw :admin
  draw :webhooks
end
# config/routes/api.rb, config/routes/admin.rb, etc.
```

---

## MISCELLANEOUS

**Use `find_or_create_by!` in seeds and idempotent operations:**
```ruby
Role.find_or_create_by!(name: 'admin')
```

**Remove empty helper files — they add startup overhead:**
```ruby
# config/application.rb
config.generators.helper = false
```

**Annotate models with schema comments:**
```bash
gem 'annotate'
bundle exec annotate --models
```

**Monitor background workers separately from web processes:**
```
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```
