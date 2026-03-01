---
name: rails-best-practices
description: Rails best practices, antipatterns, and performance pitfalls. Covers controllers, models, views, routes, migrations, Active Record query optimization, timeout configuration, and common mistakes. Use when writing, reviewing, or refactoring Rails code. Sources: rails-bestpractices.com, rubocop/rails-style-guide, speedshop.co, ankane/the-ultimate-guide-to-ruby-timeouts.
---

# Rails Best Practices & Antipatterns

---

## CONTROLLERS

**Use scope access — enforce ownership at the query level:**
```ruby
# Bad — checks after load, IDOR risk
def show
  @post = Post.find(params[:id])
  return head :forbidden unless @post.user == current_user
end

# Good — raises RecordNotFound if not owned
def show
  @post = current_user.posts.find(params[:id])
end
```

**Never modify the params hash directly:**
```ruby
# Bad — breaks downstream filters and logging
params[:user][:role] = 'guest'

# Good
user_params = params.require(:user).permit(:name, :email).merge(role: 'guest')
```

**Extract shared logic into before_action:**
```ruby
# Bad — repeated in multiple actions
def show
  @post = current_user.posts.find(params[:id])
end
def edit
  @post = current_user.posts.find(params[:id])
end

# Good
before_action :set_post, only: [:show, :edit, :update, :destroy]
private
def set_post = @post = current_user.posts.find(params[:id])
```

**Create namespace base controllers to DRY shared logic:**
```ruby
class Admin::BaseController < ApplicationController
  before_action :require_admin
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  private
  def require_admin = redirect_to root_path unless current_user&.admin?
end

class Admin::UsersController < Admin::BaseController
  # inherits auth + rescue
end
```

**One meaningful method per action — keep actions thin:**
```ruby
# Bad
def create
  @order = Order.new(order_params)
  @order.user = current_user
  @order.calculate_total
  if @order.valid? && @order.payment_method.valid?
    @order.save
    OrderMailer.confirmation(@order).deliver_later
    redirect_to @order
  else
    render :new
  end
end

# Good — delegate to a service
def create
  result = Orders::Create.call(order_params, user: current_user)
  if result.success?
    redirect_to result.order
  else
    @order = result.order
    render :new
  end
end
```

**Use virtual model attributes instead of controller logic:**
```ruby
# Bad — controller splits/transforms form data
def create
  parts = params[:full_name].split
  @user = User.new(first_name: parts[0], last_name: parts[1])
end

# Good — model handles transformation
class User < ApplicationRecord
  attr_writer :full_name
  before_validation :split_full_name
  private
  def split_full_name
    return unless @full_name
    self.first_name, self.last_name = @full_name.split
  end
end
```

---

## MODELS

### Fat Model Rules

**Name methods after business behavior, not implementation:**
```ruby
# Bad
def mark_published_flag_true = update!(published: true, published_at: Time.current)

# Good
def publish! = update!(published: true, published_at: Time.current)
```

**Tell, don't ask — push behavior to the object:**
```ruby
# Bad — controller queries state then decides
if user.admin?
  send_admin_notification(user)
end

# Good — delegate to the object
user.send_relevant_notification
```

**Use `after_commit` for side effects, never `after_save`:**
```ruby
# Bad — email fires inside transaction; if rollback occurs, email already sent
after_save :send_confirmation_email

# Good — only fires when transaction actually commits
after_commit :send_confirmation_email, on: :create
```

**Avoid `default_scope` — it's evil:**
`default_scope` applies to ALL queries including `update_all`, `delete_all`, joins, and association loads. Escaping it requires `unscoped` everywhere. Never use it.
```ruby
# Never do this
default_scope { where(active: true) }

# Use explicit scopes instead
scope :active, -> { where(active: true) }
```

**Law of Demeter — use delegate for chain traversal:**
```ruby
# Bad — violates LoD
@invoice.user.address.city

# Good
class Invoice < ApplicationRecord
  belongs_to :user
  delegate :name, :city, to: :user, prefix: true, allow_nil: true
end
# Now: @invoice.user_city
```

**Keep finders on their own model — use scopes:**
```ruby
# Bad — raw query in controller
Post.where("created_at > ?", 1.week.ago).where(published: true).order(created_at: :desc)

# Good — named scope
scope :recent_published, -> { where(created_at: 1.week.ago.., published: true).order(created_at: :desc) }
```

**Use association build/create to avoid manual FK assignment:**
```ruby
# Bad
@post = Post.new(post_params)
@post.user_id = current_user.id

# Good
@post = current_user.posts.build(post_params)
```

**Extract cross-model behavior into modules:**
```ruby
module Taggable
  extend ActiveSupport::Concern
  included do
    has_many :taggings, as: :taggable
    has_many :tags, through: :taggings
  end
end

class Post < ApplicationRecord
  include Taggable
end
```

**Consistent model structure ordering:**
1. Class constants
2. `attr_*` macros
3. `enum` declarations
4. Associations (`belongs_to`, `has_many`, `has_one`)
5. Validations
6. Callbacks (in execution order)
7. Named scopes
8. Public methods
9. `private` — private methods

**Use `annotate` gem to embed schema comments:**
```ruby
# == Schema Information
# Table name: orders
#  id         :bigint    not null, primary key
#  status     :string    not null
#  amount     :decimal
#  user_id    :bigint    not null, indexed
```

---

## ACTIVE RECORD — QUERIES

### The Three Mistakes That Cause Most Performance Problems

#### Mistake 1: `.count` when `.size` is correct

`.count` **always executes a SQL COUNT query** — even if records are already loaded in memory.
`.size` is intelligent: uses `length` if loaded, falls back to `COUNT` if not.

```ruby
# Bad — fires two queries: COUNT then SELECT *
<h2>Messages: <%= @messages.count %></h2>
<% @messages.each do |m| %> ...

# Good — one query; size uses in-memory length after each loads
<% @messages.each do |m| %> ...
<h2>Messages: <%= @messages.size %></h2>

# Need count before iteration? Force load first
<% if @messages.load.any? %>
  <h2>You have <%= @messages.size %> messages:</h2>
  <% @messages.each do |m| %> ...
```

Use `.count` only when you need the total but will never load the full collection.

#### Mistake 2: Query methods in instance methods break preloading

`includes`/`preload`/`eager_load` can only preload associations — not dynamically queried sub-results.

```ruby
# Bad — N+1: includes(:comments) doesn't help; each post fires a new WHERE query
class Post < ApplicationRecord
  def active_comments
    comments.where(soft_deleted: false)  # query method in instance method
  end
end
# @posts.each { |p| p.active_comments }  → N+1

# Good — create a filtered association; now includes works
class Post < ApplicationRecord
  has_many :active_comments, -> { where(soft_deleted: false) }, class_name: 'Comment'
end
# Post.includes(:active_comments) → 2 queries total
```

Rule: Never use `where`, `order`, `limit`, `find`, `count`, `sum` in instance methods that will be called in a loop.

#### Mistake 3: Wrong predicate method for the context

| Method | SQL | Cached after load? | Re-queries if loaded? |
|---|---|---|---|
| `present?` | `SELECT *` (full load) | Yes | No |
| `blank?` | `SELECT *` (full load) | Yes | No |
| `any?` | `SELECT 1 LIMIT 1` | No | No |
| `empty?` | `SELECT 1 LIMIT 1` | No | No |
| `none?` | `SELECT 1 LIMIT 1` | No | No |
| `exists?` | `SELECT 1 LIMIT 1` | **Never** | **Always re-queries** |

```ruby
# Bad — two queries: SELECT 1 then SELECT *
if @comments.any?
  @comments.each { |c| ... }

# Good — one query: present? loads the relation, each reuses it
if @comments.present?
  @comments.each { |c| ... }

# Bad — exists? always re-queries; 4 queries here
if @comments.exists?
  @comments.size  # COUNT
  @comments.each  # SELECT *

# Good — force load once, all subsequent calls use memory
@comments.load
if @comments.any?     # in-memory, no query
  @comments.size      # in-memory, no query
  @comments.each { }  # in-memory, no query
```

### Query Rules

**Never interpolate user input into SQL strings — SQL injection:**
```ruby
# Bad (injection)
User.where("email = '#{params[:email]}'")

# Good
User.where("email = ?", params[:email])
User.where(email: params[:email])
```

**Use named placeholders for multiple params:**
```ruby
# OK
User.where("count >= ? AND country = ?", min, code)

# Better — self-documenting
User.where("count >= :min AND country = :code", min: min, code: code)
```

**`find` for PK (raises RecordNotFound), `find_by` for attributes (returns nil):**
```ruby
User.find(id)            # raises RecordNotFound if missing — use in controllers
User.find_by(email: e)   # returns nil — use when absence is valid
User.find_by!(email: e)  # raises if missing — use in service objects
```

**Use ranges in WHERE instead of comparison operators:**
```ruby
User.where(created_at: 30.days.ago..)        # >= 30 days ago (beginless range)
User.where(created_at: 30.days.ago..7.days.ago)  # between
User.where("created_at >= ?", 30.days.ago)   # Bad — use range form
```

**`pluck` for extracting values — no model instantiation:**
```ruby
User.pluck(:email)         # Good — array of values, one SQL
User.all.map(&:email)      # Bad — loads all objects
User.pick(:email)          # Single value from first record
User.ids                   # instead of pluck(:id)
```

**Use `size` not `count` or `length` on relations:**
```ruby
User.all.size    # Intelligent — uses length if loaded, COUNT if not
User.count       # Always SQL COUNT
@users.length    # Always loads all records
```

**`find_each` / `find_in_batches` for large datasets:**
```ruby
# Bad — loads all into memory
Person.all.each { |p| p.process }

# Good — batches of 1000
Person.find_each { |p| p.process }
Person.find_in_batches(batch_size: 500) { |batch| batch.each { |p| ... } }
```

**Fix N+1 queries with eager loading:**
```ruby
# Bad — N+1
@posts.each { |p| p.user.name }

# Good
@posts = Post.includes(:user).all
# or for complex filtering:
@posts = Post.eager_load(:user).where(users: { active: true })
```

Use the `bullet` gem to auto-detect N+1 in development.

**Memoize `find_by` with `defined?` not `||=`:**
```ruby
# Bad — memoization fails when result is nil
def current_user
  @current_user ||= User.find_by(id: session[:user_id])
end

# Good
def current_user
  return @current_user if defined?(@current_user)
  @current_user = User.find_by(id: session[:user_id])
end
```

**`where.missing` for records without associations (Rails 6.1+):**
```ruby
Post.where.missing(:author)  # Good
Post.left_joins(:author).where(authors: { id: nil })  # Bad
```

**Avoid multi-attribute `where.not` — Rails 6.1+ NOR semantics:**
```ruby
# Bad — generates NOR, not NAND (surprising in Rails 6.1+)
User.where.not(status: 'active', plan: 'basic')

# Good — explicit SQL
User.where.not('status = ? AND plan = ?', 'active', 'basic')
```

**Use symbol/hash syntax for order — avoids ambiguity in joins:**
```ruby
User.order(created_at: :desc)   # Good
User.order('created_at DESC')   # Bad — breaks with table-ambiguous joins
```

**Never order by `id` for chronological ordering:**
```ruby
scope :chronological, -> { order(created_at: :asc) }  # Good
scope :chronological, -> { order(id: :asc) }           # Bad — IDs aren't guaranteed sequential
```

---

## ACTIVE RECORD — MODEL RULES

**Hash syntax for `enum` — never array syntax:**
```ruby
# Good — values are explicit, stable regardless of order
enum :status, { pending: 0, active: 1, cancelled: 2 }

# Bad — inserting before 'active' shifts all values
enum :status, %i[pending active cancelled]
```

**`has_many :through` over `has_and_belongs_to_many`:**
```ruby
# Good — allows callbacks, validations, extra attributes on join
has_many :memberships
has_many :groups, through: :memberships

# Bad — no join model, no callbacks
has_and_belongs_to_many :groups
```

**Always define `dependent:` on `has_many`/`has_one`:**
```ruby
has_many :orders, dependent: :destroy   # Good
has_many :orders                        # Bad — orphaned records
```

**`before_destroy` with `prepend: true` for validation-style guards:**
```ruby
# Bad — runs after dependent: :destroy callbacks, too late
before_destroy :check_no_active_orders

# Good — runs before Rails-generated destroy callbacks
before_destroy :check_no_active_orders, prepend: true
```

**Skip-validation methods — be explicit:**
These bypass validations and callbacks:
- `update_attribute`, `update_columns`, `update_all`, `update_counters`
- `decrement!`, `increment!`, `toggle`, `touch`

Use `update` (with validations) except when intentionally bypassing (bulk updates, timestamps).

**Use `self[:attr]` over `read_attribute`/`write_attribute`:**
```ruby
self[:amount] * 100           # Good
read_attribute(:amount) * 100 # Bad
```

**New-style validations — one attribute per call:**
```ruby
validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :name, presence: true, length: { maximum: 100 }
# Not: validates :email, :name, presence: true (harder to add per-attribute options)
```

**`ignored_columns` — always append, never assign:**
```ruby
self.ignored_columns += %i[legacy_column]   # Good
self.ignored_columns = %i[legacy_column]    # Bad — overwrites prior assignments
```

---

## VIEWS

**Pass locals to partials — never rely on instance variables:**
```ruby
# Bad — partial implicitly depends on @post from controller
render 'post_summary'

# Good — explicit, testable, reusable
render 'post_summary', post: @post
```

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

## MIGRATIONS

**Always add DB indexes for foreign keys and query columns:**
```ruby
# Any column in WHERE, ORDER BY, GROUP BY, or a foreign key needs an index
add_index :orders, :user_id
add_index :orders, :status
add_index :orders, [:user_id, :status]  # compound for common query pattern
add_index :orders, :created_at
```

Rails 5+ adds FK indexes automatically for `references`, but not for manually added FK columns.

**Test migrations in both directions before committing:**
```
rails db:migrate && rails db:rollback
```

**Use `change_table bulk: true` for multiple column changes on large tables:**
```ruby
# Bad — each add_column is a separate ALTER TABLE lock
change_table :users do |t|
  t.string :phone
  t.string :country
end

# Good — single ALTER TABLE statement
change_table :users, bulk: true do |t|
  t.string :phone
  t.string :country
end
```

**No seed data in migrations — use `db/seeds.rb`:**
```ruby
# Bad — breaks on fresh db:schema:load
class AddDefaultRoles < ActiveRecord::Migration[7.0]
  def up
    Role.create!(name: 'admin')  # Never do this
  end
end

# Good — db/seeds.rb
Role.find_or_create_by!(name: 'admin')
```

**Reversible migrations — prefer `change`, use `reversible` for complex cases:**
```ruby
# Good — reversible
def change
  add_column :users, :phone, :string
end

# Good — explicit reversibility
def change
  reversible do |dir|
    dir.up   { execute "UPDATE users SET status = 'active'" }
    dir.down { execute "UPDATE users SET status = NULL" }
  end
end
```

**Use a dedicated migration model class for data migrations:**
```ruby
# Bad — breaks if User model changes later
def up
  User.where(old_status: 'inactive').update_all(status: 'archived')
end

# Good — isolated from future model changes
class MigrationUser < ActiveRecord::Base
  self.table_name = :users
end
def up
  MigrationUser.where(old_status: 'inactive').update_all(status: 'archived')
end
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

**Use feature flags for gradual rollout (flipper, rollout):**
```ruby
if Flipper.enabled?(:new_risk_engine, current_user)
  NewRiskEngine.call(@order)
else
  LegacyRiskEngine.call(@order)
end
```

**Monitor background workers separately from web processes:**
```
# Procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

---

## QUICK ANTIPATTERN CHECKLIST

- [ ] `default_scope` anywhere → remove it
- [ ] `after_save` with email/queue → move to `after_commit`
- [ ] `.count` before or after `.each` on same relation → use `.size`
- [ ] `.where` in an AR instance method → extract to filtered association
- [ ] `any?` before `each` on same relation → use `present?` or `.load.any?`
- [ ] `Time.now` or `Date.today` → use `Time.current`
- [ ] `rescue Exception` → use `rescue StandardError`
- [ ] No index on foreign keys → add `add_index`
- [ ] HTTP call with no timeout → add open + read timeouts
- [ ] `User.all.each` for 10k+ records → use `find_each`
- [ ] Instance variable in partial → pass as local
- [ ] Business logic in controller action → extract to service/model
- [ ] `save` return value ignored → use `save!` or handle false
- [ ] `update_attribute` in production code → use `update` (with validations)
- [ ] `enum` with array syntax → use hash syntax
