# Rails Advanced Patterns — AI Slop Reference

Covers the six patterns AI most commonly generates incorrectly in Rails:
Form Objects, Query Objects, Presenters/Decorators, Serializers, Sidekiq Jobs, and Pundit/CanCan Policies.

Each section includes a decision rule (when to use the pattern at all), specific AI mistakes with risk scores, before/after Ruby code, and safety checks to run before merging.

---

## FORM OBJECTS

### Decision Rule

| Situation | Use |
|-----------|-----|
| Single model, simple fields, no custom logic | Strong params in controller |
| Multiple models updated together | Form object |
| Complex cross-field validations not owned by one model | Form object |
| Multi-step wizard flow | Form object (one per step or a state machine) |
| Computed attributes before persistence | Form object |

If your form object has one model and zero extra validations, inline it.

---

### AI Mistake 1 — Form Object Wrapping One Model With No Added Logic

**Risk: 2/5** — Unnecessary indirection. Low danger but adds dead code that grows.

**Smell:** Form object that `delegate`s everything to a single model with no extra validations or transformations.

```ruby
# BEFORE (AI slop)
class UserForm
  include ActiveModel::Model

  attr_accessor :name, :email, :password

  def save
    User.create(name: name, email: email, password: password)
  end
end

# Controller
def create
  form = UserForm.new(params[:user])
  if form.save
    redirect_to root_path
  else
    render :new
  end
end
```

```ruby
# AFTER — strong params, form object deleted
def create
  @user = User.new(user_params)
  if @user.save
    redirect_to root_path
  else
    render :new, status: :unprocessable_entity
  end
end

private

def user_params
  params.require(:user).permit(:name, :email, :password)
end
```

**Safety checks before inlining:**
- [ ] Confirm zero cross-field validations exist inside the form object
- [ ] Confirm only one model is touched in `save`
- [ ] Search for `UserForm.new` call sites — update all of them
- [ ] Check if the form object is used in tests as a collaborator (update mocks)

---

### AI Mistake 2 — Form Object Without `ActiveModel::Model`

**Risk: 4/5** — `valid?`, `errors`, and form helpers silently break. Errors never surface in the view.

**Smell:** Class with `attr_accessor` and a `save` method but no `ActiveModel::Model` include. Validations are declared but never run.

```ruby
# BEFORE (AI slop)
class RegistrationForm
  attr_accessor :email, :password, :password_confirmation

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }
  validate :passwords_match

  def save
    User.create!(email: email, password: password)
  end

  private

  def passwords_match
    errors.add(:password_confirmation, "doesn't match") if password != password_confirmation
  end
end
```

```ruby
# AFTER
class RegistrationForm
  include ActiveModel::Model   # ← required for validates, errors, valid?
  include ActiveModel::Validations  # already included via ActiveModel::Model but explicit for clarity

  attr_accessor :email, :password, :password_confirmation

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }
  validate :passwords_match

  def save
    return false unless valid?

    User.create!(email: email, password: password)
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def passwords_match
    errors.add(:password_confirmation, "doesn't match") if password != password_confirmation
  end
end
```

**Safety checks:**
- [ ] Run `form.valid?` in a console — it must return `false` for invalid data before fix
- [ ] Verify `form_with(model: form)` in the view generates correct error rendering
- [ ] Confirm `model_name` is defined (it is, via `ActiveModel::Model`)
- [ ] If used with `form_for`, check Rails version — `form_with` preferred in Rails 5.1+

---

### AI Mistake 3 — Form Object Persisting Data Directly (Bypassing the Model)

**Risk: 5/5** — Model callbacks, validations, and `before_save` hooks are skipped. Can corrupt data silently.

**Smell:** Form object calls `DB.execute`, `ActiveRecord::Base.connection.execute`, or `Model.update_all` directly instead of delegating to the model instance.

```ruby
# BEFORE (AI slop)
class ProfileForm
  include ActiveModel::Model

  attr_accessor :user_id, :bio, :website, :avatar_url

  def save
    # bypasses all User callbacks and validations
    User.where(id: user_id).update_all(bio: bio, website: website, avatar_url: avatar_url)
  end
end
```

```ruby
# AFTER — delegate persistence to the model
class ProfileForm
  include ActiveModel::Model

  attr_accessor :user, :bio, :website, :avatar_url

  validates :bio, length: { maximum: 500 }
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  def self.from_user(user)
    new(user: user, bio: user.bio, website: user.website, avatar_url: user.avatar_url)
  end

  def save
    return false unless valid?

    user.update(bio: bio, website: website, avatar_url: avatar_url)
  end
end
```

**Safety checks:**
- [ ] Grep for `update_all`, `connection.execute`, `execute(` inside any form object
- [ ] Confirm all model `before_save`, `after_commit` hooks are still triggered with the fix
- [ ] Verify that the model's own validations are not being re-duplicated in the form (either delegate or consolidate)
- [ ] If avatar upload is involved, ensure CarrierWave/ActiveStorage assignment still works through the model

---

### Correct Form Object Pattern

```ruby
# app/forms/checkout_form.rb
class CheckoutForm
  include ActiveModel::Model

  attr_accessor :user, :address_line1, :address_line2, :city,
                :postal_code, :country_code, :card_token

  validates :address_line1, :city, :postal_code, :country_code, :card_token, presence: true
  validates :postal_code, format: { with: /\A[0-9A-Z\s\-]{3,10}\z/i }
  validate :card_token_format

  def save
    return false unless valid?

    ApplicationRecord.transaction do
      address = user.addresses.create!(address_attributes)
      order   = user.orders.create!(address: address, status: :pending)
      PaymentService.new(order, card_token).charge! # raises on failure
      order
    end
  rescue PaymentService::Error => e
    errors.add(:card_token, e.message)
    false
  end

  private

  def address_attributes
    { line1: address_line1, line2: address_line2, city: city,
      postal_code: postal_code, country_code: country_code }
  end

  def card_token_format
    errors.add(:card_token, "is invalid") unless card_token.to_s.start_with?("tok_")
  end
end
```

**Key properties of a correct form object:**
- `include ActiveModel::Model`
- `valid?` gates `save`
- Persistence delegated to model instances inside a transaction
- Returns falsy on failure, sets `errors`
- `save!` variant raises if you need that contract

---

## QUERY OBJECTS

### Decision Rule

| Situation | Use |
|-----------|-----|
| Single table, one `where` clause | Named scope on model |
| Single table, complex conditionals on same model's columns | Named scope is still fine |
| Query joins multiple tables | Query object |
| Query has many conditionals that build on each other | Query object |
| Query result needs to be reused across different controllers / jobs | Query object |
| Query has sub-selects, CTEs, window functions | Query object |

If the query fits in a one-liner scope, it belongs in the model. Move it only when it grows.

---

### AI Mistake 1 — Query Object Wrapping a Single `where`

**Risk: 1/5** — No harm, just unnecessary ceremony that makes the codebase harder to scan.

**Smell:** Entire class exists to call one `where`.

```ruby
# BEFORE (AI slop)
class ActiveUsersQuery
  def initialize(relation = User.all)
    @relation = relation
  end

  def call
    @relation.where(active: true)
  end
end

# Called as:
ActiveUsersQuery.new.call
```

```ruby
# AFTER — named scope on the model
class User < ApplicationRecord
  scope :active, -> { where(active: true) }
end

# Called as:
User.active
User.active.order(:created_at)  # still chainable
```

**Safety checks:**
- [ ] Grep all call sites of `ActiveUsersQuery.new.call` and replace
- [ ] Confirm the scope is chainable (it is — scopes return relations)
- [ ] Delete the query object file; verify no other class inherits from it

---

### AI Mistake 2 — Query Object Returning an Array

**Risk: 3/5** — Callers cannot chain `.order`, `.limit`, `.page`, `.count`, or pass to `render json:` expecting a relation. Often causes N+1 in pagination.

**Smell:** `call` ends with `.to_a`, `.map`, `.each`, or similar terminal operation.

```ruby
# BEFORE (AI slop)
class RecentOrdersQuery
  def initialize(user)
    @user = user
  end

  def call
    # returns Array — caller can't chain
    @user.orders
         .joins(:items)
         .where("orders.created_at > ?", 30.days.ago)
         .to_a
  end
end
```

```ruby
# AFTER — return the relation, let caller decide when to load
class RecentOrdersQuery
  def initialize(relation = Order.all)
    @relation = relation
  end

  def self.call(relation = Order.all)
    new(relation).call
  end

  def call
    @relation
      .joins(:items)
      .where(orders: { created_at: 30.days.ago.. })
      .distinct
  end
end

# Callers can now chain freely:
RecentOrdersQuery.call(user.orders).order(created_at: :desc).page(params[:page])
RecentOrdersQuery.call(user.orders).count
```

**Safety checks:**
- [ ] Grep for `.to_a`, `.map`, `.each` at end of query object `call` — each is a smell
- [ ] Check caller code for `.each` directly on the return value — if it chains `.order` or `.page`, the array would have blown up already (find the bug)
- [ ] Confirm no caller depends on the Array duck type (e.g., `result[0]` — works on relation too via `first`)

---

### AI Mistake 3 — No Consistent `.call` Interface

**Risk: 2/5** — Each query object has a different calling convention (`execute`, `run`, `perform`, `results`). Hard to grep, hard to mock, violates the principle of least surprise.

**Smell:** Mix of `QueryObject.new(args).execute`, `.new(args).results`, `.new(args).relation`, or no class-level `.call` shortcut.

```ruby
# BEFORE (AI slop — three different conventions in the same codebase)
FeaturedProductsQuery.new(category).results
ExpiredSubscriptionsQuery.new.run
DraftPostsQuery.new(author: user).relation
```

```ruby
# AFTER — unified interface: class-level `.call` + instance `call`
module QueryObject
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def call(*args, **kwargs)
      new(*args, **kwargs).call
    end
  end
end

class FeaturedProductsQuery
  include QueryObject

  def initialize(relation = Product.all, category: nil)
    @relation = relation
    @category = category
  end

  def call
    @relation
      .where(featured: true)
      .then { |r| @category ? r.where(category: @category) : r }
  end
end

# Uniform call sites:
FeaturedProductsQuery.call                         # all featured
FeaturedProductsQuery.call(category: "electronics") # scoped
FeaturedProductsQuery.call(Product.published)       # composable base
```

**Safety checks:**
- [ ] Grep for any class ending in `Query` that lacks a `.call` class method
- [ ] Standardize all query objects to accept an optional base relation as first arg
- [ ] Verify RSpec uses `described_class.call(...)` not `described_class.new(...).execute`

---

### Correct Query Object Pattern

```ruby
# app/queries/overdue_invoices_query.rb
class OverdueInvoicesQuery
  def initialize(relation = Invoice.all)
    @relation = relation
  end

  def self.call(relation = Invoice.all)
    new(relation).call
  end

  def call
    @relation
      .joins(:subscription)
      .where(status: :unpaid)
      .where("invoices.due_date < ?", Date.current)
      .where(subscriptions: { active: true })
      .select("invoices.*, subscriptions.plan_id")
      .distinct
  end
end

# Usage
OverdueInvoicesQuery.call                          # all
OverdueInvoicesQuery.call(Invoice.where(currency: "USD")) # composable
OverdueInvoicesQuery.call.includes(:user).page(1)  # chainable
```

---

## PRESENTER / DECORATOR PATTERNS

### Decision Rule

| Situation | Use |
|-----------|-----|
| Pure formatting (currency, date, string truncation) | Presenter / Decorator |
| Conditional display logic based on model state | Presenter / Decorator |
| View logic reused across multiple templates | Helper (stateless) or Presenter |
| Model needs display-oriented string methods | Do NOT put in model — use presenter |
| Complex wrapped object needing all model methods | Draper or SimpleDelegator |
| Simple one-off formatting | Inline in view or helper |

---

### AI Mistake 1 — Presenter With Database Calls (N+1 Factory)

**Risk: 5/5** — Each call to the presenter method fires a query. Multiplied across a collection, this is a silent N+1.

**Smell:** Presenter calls `.count`, `.find`, `.where`, `.includes`, or any AR query method.

```ruby
# BEFORE (AI slop)
class PostPresenter
  def initialize(post)
    @post = post
  end

  def comment_count
    @post.comments.count        # DB hit every render
  end

  def latest_comment_author
    @post.comments.last&.user&.name  # 2 DB hits if not preloaded
  end

  def related_posts
    Post.where(tag: @post.tag).limit(3).to_a  # query inside presenter
  end
end
```

```ruby
# AFTER — presenter is a view-layer formatter only; data must already be loaded
class PostPresenter
  def initialize(post)
    @post = post
  end

  # comment_count: caller must eager-load `includes(:comments)` and pass the object
  # Use counter_cache on the model instead
  def comment_count_label
    count = @post.comments_count  # counter_cache column, zero DB hits
    count == 1 ? "1 comment" : "#{count} comments"
  end

  def latest_comment_author
    # assumes comments already loaded via includes(:comments, :user)
    @post.comments.last&.user&.name || "No comments yet"
  end

  def formatted_published_at
    return "Draft" unless @post.published_at
    @post.published_at.strftime("%B %-d, %Y")
  end
end

# Controller ensures eager loading — presenter never touches DB
@posts = Post.published.includes(:comments, comments: :user).page(params[:page])
@presenters = @posts.map { |p| PostPresenter.new(p) }
```

**Safety checks:**
- [ ] Grep presenter files for `.where`, `.find`, `.count`, `.includes`, `.joins`, `.order` — each is a bug
- [ ] Check whether model has `counter_cache: true` on `belongs_to` before using `_count` columns
- [ ] Confirm the controller eager-loads every association the presenter accesses

---

### AI Mistake 2 — Presentation Logic in the Model

**Risk: 3/5** — Models should know nothing about HTML, CSS classes, or display format. This logic pollutes the domain object and can't be overridden per-context.

**Smell:** Model methods returning HTML strings, CSS class names, or format-specific output.

```ruby
# BEFORE (AI slop)
class Order < ApplicationRecord
  def status_badge_html
    css = status == "paid" ? "badge-success" : "badge-danger"
    "<span class=\"badge #{css}\">#{status.humanize}</span>".html_safe
  end

  def formatted_total
    "$#{'%.2f' % total}"
  end

  def display_name
    "Order ##{id} — #{user.name}"
  end
end
```

```ruby
# AFTER — model has zero HTML/CSS; presenter handles display
class Order < ApplicationRecord
  # model only: business predicates
  def paid? = status == "paid"
  def refunded? = status == "refunded"
end

class OrderPresenter < SimpleDelegator
  def status_badge_css
    __getobj__.paid? ? "badge-success" : "badge-danger"
  end

  def status_label
    __getobj__.status.humanize
  end

  def formatted_total
    ActionController::Base.helpers.number_to_currency(total)
  end

  def display_name
    "Order ##{id}"  # user.name accessed in view or passed in
  end
end

# View
presenter = OrderPresenter.new(@order)
presenter.status_badge_css   # "badge-success"
presenter.formatted_total    # "$12.50"
presenter.paid?              # delegated to model — true/false
```

**Safety checks:**
- [ ] Grep model files for `.html_safe`, `content_tag`, `tag.`, CSS class strings
- [ ] Grep model files for `strftime`, `number_to_currency`, `humanize` used for display — move to presenter
- [ ] Confirm tests for display methods move to presenter spec, model spec stays focused on business logic

---

### AI Mistake 3 — Helper Methods That Are Really Presenter Methods

**Risk: 2/5** — Helpers are global and stateless. Putting object-specific formatting in a helper pollutes the global helper namespace and can't be tested in isolation easily.

**Smell:** Helper takes a model object as its first argument and returns formatted output.

```ruby
# BEFORE (AI slop)
# app/helpers/user_helper.rb
module UserHelper
  def user_avatar_url(user)
    user.avatar.attached? ? url_for(user.avatar) : asset_path("default-avatar.png")
  end

  def user_full_name(user)
    [user.first_name, user.last_name].compact.join(" ").presence || "Anonymous"
  end

  def user_role_label(user)
    user.admin? ? "Administrator" : user.role.humanize
  end
end
```

```ruby
# AFTER — move to presenter; helper can remain as a thin bridge if needed in views
class UserPresenter < SimpleDelegator
  include Rails.application.routes.url_helpers

  def avatar_url
    avatar.attached? ? rails_blob_url(avatar) : ActionController::Base.helpers.asset_path("default-avatar.png")
  end

  def full_name
    [first_name, last_name].compact.join(" ").presence || "Anonymous"
  end

  def role_label
    admin? ? "Administrator" : role.humanize
  end
end

# Helper becomes a one-liner factory (optional, keeps old view syntax working)
module UserHelper
  def present_user(user)
    UserPresenter.new(user)
  end
end
```

**Safety checks:**
- [ ] Grep `app/helpers/` for methods whose first param is a model object
- [ ] Count call sites — if a helper is called in only one view, move to that view's presenter or local partial
- [ ] After extracting to presenter, run the helper test suite to catch any missed delegates

---

### Draper vs. SimpleDelegator vs. Plain Ruby Presenter

```ruby
# Option A: Plain Ruby (zero dependencies, explicit delegation)
class InvoicePresenter
  def initialize(invoice, view_context)
    @invoice = invoice
    @view    = view_context
  end

  def formatted_amount
    @view.number_to_currency(@invoice.amount_cents / 100.0)
  end

  def method_missing(name, ...) = @invoice.send(name, ...)
  def respond_to_missing?(name, ...) = @invoice.respond_to?(name, ...) || super
end

# Option B: SimpleDelegator (auto-delegates all model methods, no gem)
class InvoicePresenter < SimpleDelegator
  def formatted_amount
    ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)
  end
  # all Invoice methods available automatically
end

# Option C: Draper (if the team already uses it — do not add just for one presenter)
class InvoiceDecorator < Draper::Decorator
  delegate_all

  def formatted_amount
    h.number_to_currency(amount_cents / 100.0)
  end
end
```

**Rule:** Use `SimpleDelegator` by default (zero deps, simple). Use Draper if it's already in the Gemfile. Never add Draper just for one presenter.

---

## SERIALIZERS

### Decision Rule

| Library | Use when |
|---------|----------|
| ActiveModelSerializers (AMS) | Legacy API, team already uses it |
| Blueprinter | Performance-sensitive API, prefer explicit attribute lists |
| JSONAPI::Serializer (fast_jsonapi successor) | JSON:API spec required |
| Manual `as_json` override | Almost never — only for trivially simple models |
| Jbuilder | View-like JSON (server-rendered pages with turbo, not REST APIs) |

---

### AI Mistake 1 — Serializer Triggering N+1

**Risk: 5/5** — Serializing a collection fires a query per object for each association method.

**Smell:** Serializer accesses `object.association`, `object.association.count`, or calls methods that load associations not specified in `includes`.

```ruby
# BEFORE (AI slop — AMS)
class ArticleSerializer < ActiveModel::Serializer
  attributes :id, :title, :author_name, :comment_count, :tag_list

  def author_name
    object.user.full_name   # N+1: loads user for each article
  end

  def comment_count
    object.comments.count   # N+1: COUNT query per article
  end

  def tag_list
    object.tags.map(&:name).join(", ")  # N+1: loads tags per article
  end
end
```

```ruby
# AFTER — serializer only reads preloaded data; controller owns includes
class ArticleSerializer < ActiveModel::Serializer
  attributes :id, :title, :author_name, :comment_count, :tag_list

  def author_name
    object.user.full_name  # safe: controller eager-loads user
  end

  def comment_count
    object.comments_count  # counter_cache column — no query
  end

  def tag_list
    object.tags.map(&:name).join(", ")  # safe: controller eager-loads tags
  end
end

# Controller
@articles = Article.published
                   .includes(:user, :tags)   # ← must match serializer's associations
                   .page(params[:page])
render json: @articles
```

**Blueprinter alternative (explicit, harder to accidentally N+1):**

```ruby
class ArticleBlueprint < Blueprinter::Base
  identifier :id
  fields :title

  field :author_name do |article|
    article.user.full_name  # still needs eager load
  end

  field :comment_count do |article|
    article.comments_count
  end

  association :tags, blueprint: TagBlueprint  # explicit — Blueprinter warns if not loaded
end

render json: ArticleBlueprint.render_as_hash(@articles, root: :articles)
```

**Safety checks:**
- [ ] Run the API endpoint through Bullet gem or `to_json` in console with `verbose: true`
- [ ] Every association referenced in serializer must appear in the controller `includes`
- [ ] Use `counter_cache: true` on `belongs_to` for count fields — never `.count` in serializer

---

### AI Mistake 2 — Manual `to_json` Override in Model

**Risk: 4/5** — Breaks Rails' built-in JSON rendering, hard to override per-context, couples the model to a specific API format, and leaks sensitive fields.

**Smell:** `def to_json(...)` or `def as_json(options = {})` inside a model with a long list of attributes.

```ruby
# BEFORE (AI slop)
class User < ApplicationRecord
  def as_json(options = {})
    super(options.merge(
      only: [:id, :name, :email, :created_at],
      methods: [:full_name, :avatar_url]
    ))
  end

  # somewhere else in model...
  def to_json(*)
    { id: id, name: name, token: api_token }.to_json  # LEAKS api_token if called wrong place
  end
end
```

```ruby
# AFTER — model has no JSON knowledge; serializer per context
class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :created_at, :full_name, :avatar_url
end

class UserPublicSerializer < ActiveModel::Serializer
  attributes :id, :name, :avatar_url
end

class UserAdminSerializer < ActiveModel::Serializer
  attributes :id, :name, :email, :created_at, :full_name, :avatar_url, :role, :last_sign_in_at
end

# Controller picks the right one
serializer = current_user.admin? ? UserAdminSerializer : UserPublicSerializer
render json: @user, serializer: serializer
```

**Safety checks:**
- [ ] Grep all models for `def as_json`, `def to_json` — each is a removal candidate
- [ ] Audit what attributes are currently exposed — check for `api_token`, `password_digest`, `reset_token`
- [ ] Verify that calling `user.to_json` in console after removal uses Rails default (fine — serializer is called at render time)

---

### AI Mistake 3 — Serializer Doing Business Logic

**Risk: 4/5** — Business logic in serializers is untested by domain tests, creates hidden side effects, and ties formatting to computation.

**Smell:** Serializer computes prices, applies discounts, formats currency from raw values, or calls external services.

```ruby
# BEFORE (AI slop)
class OrderSerializer < ActiveModel::Serializer
  attributes :id, :subtotal, :discount_amount, :tax, :total

  def discount_amount
    # Business logic: applying promo code discount
    if object.promo_code.present?
      PromoCode.find_by(code: object.promo_code)&.calculate_discount(object.subtotal) || 0
    else
      0
    end
  end

  def tax
    TaxCalculator.new(object.shipping_address).calculate(object.subtotal)  # external service call
  end

  def total
    object.subtotal - discount_amount + tax
  end
end
```

```ruby
# AFTER — serializer reads pre-computed values; model or service handles computation
class Order < ApplicationRecord
  monetize :subtotal_cents
  monetize :discount_amount_cents
  monetize :tax_cents
  monetize :total_cents

  # computed at order-creation time or via a dedicated calculation service
  def compute_totals!
    OrderPricingService.new(self).compute!
  end
end

class OrderSerializer < ActiveModel::Serializer
  attributes :id, :subtotal_cents, :discount_amount_cents, :tax_cents, :total_cents, :currency
end

# Or with Blueprinter for explicit formatting
class OrderBlueprint < Blueprinter::Base
  identifier :id
  fields :currency
  field(:subtotal)        { |o| o.subtotal.format }
  field(:discount_amount) { |o| o.discount_amount.format }
  field(:tax)             { |o| o.tax.format }
  field(:total)           { |o| o.total.format }
end
```

**Safety checks:**
- [ ] Grep serializers for service class instantiations, `find_by`, `calculate`, `compute`
- [ ] Move any computation into a model method or service, persist result if it's deterministic
- [ ] Serializer fields should be simple attribute reads or lightweight format transformations only

---

### AI Mistake 4 — Fat Serializer With 30+ Attributes and No Composition

**Risk: 3/5** — Hard to maintain, returns too much data in every context (over-fetching), and cannot be reused for nested resources.

**Smell:** One serializer class with 25+ `attributes` and deeply nested `has_many` / `has_one` inline, all in one file.

```ruby
# BEFORE (AI slop)
class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :first_name, :last_name, :phone, :bio,
             :avatar_url, :role, :created_at, :updated_at, :last_sign_in_at,
             :sign_in_count, :confirmed_at, :failed_attempts, :locked_at,
             :time_zone, :locale, :newsletter_opted_in, :marketing_opted_in,
             :stripe_customer_id, :referral_code, :referral_count,
             :orders_count, :total_spent_cents, :average_order_value

  has_many :orders
  has_many :addresses
  has_one :subscription
end
```

```ruby
# AFTER — split by context, compose with nested serializers
# app/serializers/user_summary_serializer.rb (used in lists)
class UserSummarySerializer < ActiveModel::Serializer
  attributes :id, :email, :full_name, :avatar_url, :role
end

# app/serializers/user_profile_serializer.rb (used in profile endpoints)
class UserProfileSerializer < ActiveModel::Serializer
  attributes :id, :email, :first_name, :last_name, :phone, :bio,
             :avatar_url, :time_zone, :locale, :created_at

  has_many :addresses, serializer: AddressSummarySerializer
  has_one :subscription, serializer: SubscriptionSerializer
end

# app/serializers/user_admin_serializer.rb (admin panel)
class UserAdminSerializer < UserProfileSerializer
  attributes :role, :last_sign_in_at, :sign_in_count, :locked_at,
             :stripe_customer_id, :orders_count
end

# Controllers pick the right serializer
# GET /users — list
render json: @users, each_serializer: UserSummarySerializer

# GET /profile
render json: @user, serializer: UserProfileSerializer
```

**Safety checks:**
- [ ] If a serializer has more than 15 attributes, question whether it's context-specific
- [ ] Check for `stripe_customer_id`, `api_token`, `encrypted_password` — must be admin-only serializer
- [ ] Nested `has_many` without its own serializer file is a code smell — extract it

---

## SIDEKIQ / BACKGROUND JOBS

### Decision Rule

**A job should do one thing: call a service with an ID.**

```ruby
# Canonical correct job — the template to compare everything against
class SendWelcomeEmailJob < ApplicationJob
  queue_as :mailers

  sidekiq_options retry: 5, dead: true

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end
```

---

### AI Mistake 1 — Job With Business Logic

**Risk: 4/5** — Business logic in a job cannot be unit-tested without a worker context, is hard to reuse, and hides complexity.

**Smell:** Job `perform` method is more than 10 lines, contains conditionals, updates multiple models, or calls external APIs directly.

```ruby
# BEFORE (AI slop)
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    order = Order.find(order_id)
    return if order.processed?

    # 40 lines of business logic...
    charge = Stripe::Charge.create(
      amount: order.total_cents,
      currency: order.currency,
      customer: order.user.stripe_customer_id,
      description: "Order ##{order.id}"
    )

    order.update!(stripe_charge_id: charge.id, status: :paid, processed_at: Time.current)

    inventory = order.line_items.map { |li| [li.product_id, li.quantity] }
    inventory.each do |product_id, qty|
      Product.decrement_counter(:stock_count, product_id, by: qty)
    end

    OrderMailer.confirmation(order).deliver_now
  end
end
```

```ruby
# AFTER — job is a thin dispatcher; all logic in service
class ProcessOrderJob < ApplicationJob
  queue_as :payments
  sidekiq_options retry: 3, dead: true

  def perform(order_id)
    OrderProcessingService.new(order_id).call
  end
end

# app/services/order_processing_service.rb
class OrderProcessingService
  def initialize(order_id)
    @order_id = order_id
  end

  def call
    order = Order.find(@order_id)
    return if order.processed?   # idempotency guard

    ApplicationRecord.transaction do
      charge_order!(order)
      deduct_inventory!(order)
      order.update!(status: :paid, processed_at: Time.current)
    end

    OrderMailer.confirmation(order).deliver_later
  end

  private

  def charge_order!(order)
    # ... Stripe logic
  end

  def deduct_inventory!(order)
    # ... inventory logic
  end
end
```

**Safety checks:**
- [ ] Job `perform` method should be under 10 lines — extract everything else to a service
- [ ] The service should be independently unit-testable without Sidekiq
- [ ] Ensure `deliver_later` (not `deliver_now`) in jobs — avoids blocking

---

### AI Mistake 2 — Non-Idempotent Job

**Risk: 5/5** — If a job runs twice (Sidekiq retry, network timeout, deploy during job), non-idempotent jobs can double-charge, double-send emails, or create duplicate records.

**Smell:** No guard at the top of `perform` checking if work is already done.

```ruby
# BEFORE (AI slop — will double-charge on retry)
class ChargeSubscriptionJob < ApplicationJob
  def perform(subscription_id)
    subscription = Subscription.find(subscription_id)
    charge = Stripe::Charge.create(
      amount: subscription.amount_cents,
      customer: subscription.stripe_customer_id
    )
    subscription.payments.create!(stripe_charge_id: charge.id, amount_cents: subscription.amount_cents)
  end
end
```

```ruby
# AFTER — idempotency key prevents double-charge
class ChargeSubscriptionJob < ApplicationJob
  queue_as :billing
  sidekiq_options retry: 5, dead: true

  def perform(subscription_id, billing_period_start)
    subscription = Subscription.find(subscription_id)
    idempotency_key = "sub_#{subscription_id}_#{billing_period_start}"

    # Guard: already charged for this period?
    return if subscription.payments.exists?(idempotency_key: idempotency_key)

    ApplicationRecord.transaction do
      charge = Stripe::Charge.create(
        amount: subscription.amount_cents,
        customer: subscription.stripe_customer_id,
        idempotency_key: idempotency_key  # Stripe-side idempotency
      )

      subscription.payments.create!(
        stripe_charge_id: charge.id,
        amount_cents: subscription.amount_cents,
        idempotency_key: idempotency_key
      )
    end
  end
end
```

**Safety checks:**
- [ ] Every job that writes to DB or calls a payment/email API needs an idempotency guard
- [ ] Pass the billing period / date as a job argument — not `Date.current` inside the job (changes on retry)
- [ ] Stripe, SendGrid, and most APIs support `idempotency_key` — always use it for financial operations
- [ ] Add a unique index on `payments.idempotency_key` to enforce at the DB level

---

### AI Mistake 3 — Passing ActiveRecord Objects as Job Arguments

**Risk: 5/5** — AR objects are serialized to YAML in Sidekiq. The object in the queue becomes stale if the record changes before the job runs. Large objects bloat Redis.

**Smell:** Job argument is `user`, `order`, or any AR instance instead of `user_id`, `order_id`.

```ruby
# BEFORE (AI slop)
class SendInvoiceJob < ApplicationJob
  def perform(user, invoice)   # AR objects in arguments — serialized to YAML
    InvoiceMailer.send_invoice(user, invoice).deliver_now
  end
end

# Enqueued as:
SendInvoiceJob.perform_later(current_user, @invoice)
```

```ruby
# AFTER — IDs only; reload fresh record inside job
class SendInvoiceJob < ApplicationJob
  queue_as :mailers
  sidekiq_options retry: 3

  def perform(user_id, invoice_id)
    user    = User.find(user_id)
    invoice = Invoice.find(invoice_id)

    InvoiceMailer.send_invoice(user, invoice).deliver_now
  end
end

# Enqueued as:
SendInvoiceJob.perform_later(current_user.id, @invoice.id)
```

**Special case — GlobalID:** Rails `perform_later` supports GlobalID objects, which serialize as `gid://` URIs. This is safer than raw YAML but still loads from DB at execution time. Prefer IDs for clarity and Rails-version independence.

**Safety checks:**
- [ ] Grep job files for `def perform` with typed AR arguments
- [ ] Grep `perform_later` call sites — any argument that isn't a scalar (integer, string, boolean) is suspect
- [ ] Check Sidekiq Web UI queue payload — AR YAML in jobs will show `!ruby/object:User` in the JSON

---

### AI Mistake 4 — No Retry Configuration

**Risk: 3/5** — Default Sidekiq retry is 25 attempts over 21 days. Payment or email jobs that fail on external API downtime will silently retry for weeks without the team knowing.

**Smell:** Job class has no `sidekiq_options retry:` or `sidekiq_retry_in`.

```ruby
# BEFORE (AI slop — inherits Sidekiq's 25-retry default)
class SendPasswordResetJob < ApplicationJob
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.password_reset(user).deliver_now
  end
end
```

```ruby
# AFTER — explicit retry + dead-letter config
class SendPasswordResetJob < ApplicationJob
  queue_as :mailers

  # 3 retries; if all fail, move to dead queue for inspection
  sidekiq_options retry: 3, dead: true

  # Optional: custom backoff (seconds)
  sidekiq_retry_in do |count, _exception|
    [30, 120, 300][count] || 300  # 30s, 2m, 5m
  end

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.password_reset(user).deliver_now
  end
end
```

**Retry strategy by job type:**

| Job type | Recommended retries | Notes |
|----------|---------------------|-------|
| Payment / billing | 5 with idempotency key | Always use Stripe idempotency |
| Email | 3 | Emails older than 1h may be useless |
| Data sync / ETL | 10 | Usually safe to retry many times |
| Webhook dispatch | 5 | External system may deduplicate |
| Report generation | 2 | Expensive — limit retries |

**Safety checks:**
- [ ] Grep all job files for missing `sidekiq_options retry:` — add appropriate value per type
- [ ] Set up Sidekiq dead queue alerting (e.g., `sidekiq_pro` or a cron that counts dead queue size)
- [ ] Review default retry setting in `config/initializers/sidekiq.rb` — should not be global 25

---

### AI Mistake 5 — `perform_now` in Production Code

**Risk: 3/5** — `perform_now` runs synchronously in the web request, blocking the response and defeating the purpose of background jobs. Often happens when AI wants to "test" jobs or "ensure" they run.

**Smell:** `perform_now` called from a controller, model callback, or service outside of test code.

```ruby
# BEFORE (AI slop)
class OrdersController < ApplicationController
  def create
    @order = Order.create!(order_params)
    ProcessOrderJob.perform_now(@order.id)   # blocks web request
    render json: @order
  end
end
```

```ruby
# AFTER
class OrdersController < ApplicationController
  def create
    @order = Order.create!(order_params)
    ProcessOrderJob.perform_later(@order.id)  # async
    render json: @order, status: :created
  end
end
```

**Legitimate uses of `perform_now`:**
- Tests (RSpec with `have_enqueued_job` or inline mode)
- One-off rake tasks where async makes no sense
- Migrations that need synchronous job completion

**Safety checks:**
- [ ] Grep production code (`app/`, not `spec/`, `test/`) for `perform_now`
- [ ] In tests, prefer `have_enqueued_job` matcher + let Sidekiq test mode handle execution
- [ ] If synchronous execution is truly needed, call the service directly — not `perform_now`

---

### AI Mistake 6 — No Dead-Letter Handling

**Risk: 4/5** — Jobs that exhaust all retries silently disappear into the dead queue. Without monitoring, failed payments or critical operations are never retried or escalated.

**Smell:** No `sidekiq_death_handler` or alerting configured; dead queue grows indefinitely.

```ruby
# BEFORE (AI slop — jobs die silently)
class ProcessRefundJob < ApplicationJob
  sidekiq_options retry: 3

  def perform(refund_id)
    RefundService.new(refund_id).call
  end
end
```

```ruby
# AFTER — death handler alerts and records failure
class ProcessRefundJob < ApplicationJob
  queue_as :billing
  sidekiq_options retry: 3, dead: true

  sidekiq_death_handler do |job, ex|
    # Alert the team
    Sentry.capture_exception(ex, extra: { job: job })
    PagerDutyClient.trigger("Refund job failed permanently", job_id: job["jid"], refund_id: job["args"].first)

    # Record for audit
    FailedJob.create!(
      job_class: job["class"],
      job_id: job["jid"],
      args: job["args"],
      error: ex.message,
      failed_at: Time.current
    )
  end

  def perform(refund_id)
    RefundService.new(refund_id).call
  end
end

# Alternatively, a global death handler in config/initializers/sidekiq.rb:
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, ex) do
    Sentry.capture_exception(ex, extra: { job: job["class"], jid: job["jid"] })
  end
end
```

**Safety checks:**
- [ ] Check `config/initializers/sidekiq.rb` for at least one `death_handlers` entry
- [ ] Monitor dead queue size with a cron job or Sidekiq Pro metrics
- [ ] For financial jobs, `FailedJob` audit table ensures no charge/refund goes untracked

---

## PUNDIT / CANCAN POLICIES

### Decision Rule

| Situation | Use |
|-----------|-----|
| Simple role-based access | Pundit (`app/policies/`) |
| Complex attribute-level permissions | Pundit + policy scopes |
| Legacy app with many roles | CanCanCan (ability.rb) |
| Per-object access that varies by record state | Pundit (`record.state` in policy) |

---

### AI Mistake 1 — Policy That Always Returns True

**Risk: 5/5** — Open access to all actions. Often left in by AI as a "template" that was never completed.

**Smell:** All policy methods return `true`, or the policy inherits a permissive base without overriding.

```ruby
# BEFORE (AI slop)
class DocumentPolicy < ApplicationPolicy
  def show?
    true   # TODO: implement
  end

  def update?
    true
  end

  def destroy?
    true
  end
end
```

```ruby
# AFTER — explicit, minimal permissions
class DocumentPolicy < ApplicationPolicy
  # `user` and `record` are set by ApplicationPolicy initializer

  def show?
    record.public? || owner_or_admin?
  end

  def update?
    owner_or_admin? && !record.archived?
  end

  def destroy?
    user.admin?
  end

  def create?
    user.present?  # any authenticated user
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user).or(scope.where(visibility: :public))
      end
    end
  end

  private

  def owner_or_admin?
    user.admin? || record.user_id == user.id
  end
end
```

**Safety checks:**
- [ ] Grep all policy files for methods that return bare `true` — each is a security hole
- [ ] Run `bundle exec pundit-audit` or grep for `# TODO` in policy files
- [ ] Ensure `authorize` is called in every controller action (use `verify_authorized` in base controller)

---

### AI Mistake 2 — Checking Role String Instead of Predicate Method

**Risk: 3/5** — String comparison is brittle (typos, case sensitivity), cannot be refactored safely, and duplicates role logic across policies.

**Smell:** `user.role == "admin"` or `user.role == "manager"` inline in policy methods.

```ruby
# BEFORE (AI slop)
class ProjectPolicy < ApplicationPolicy
  def update?
    user.role == "admin" || user.role == "manager" || user.id == record.owner_id
  end

  def destroy?
    user.role == "admin"
  end

  def archive?
    user.role == "admin" || user.role == "manager"
  end
end
```

```ruby
# AFTER — role predicate methods on User model; policy delegates
class User < ApplicationRecord
  enum :role, { viewer: 0, editor: 1, manager: 2, admin: 3 }

  def admin? = role == "admin"
  def manager? = role == "manager"
  def manager_or_above? = manager? || admin?
end

class ProjectPolicy < ApplicationPolicy
  def update?
    user.manager_or_above? || owner?
  end

  def destroy?
    user.admin?
  end

  def archive?
    user.manager_or_above?
  end

  private

  def owner?
    record.owner_id == user.id
  end
end
```

**Safety checks:**
- [ ] Grep all policy files for `user.role ==` — each should become a predicate call
- [ ] Confirm the predicate methods exist on the `User` model (or extract to a `Roleable` concern)
- [ ] If using `enum`, confirm the integer → string mapping is stable before replacing string checks

---

### AI Mistake 3 — Business Logic in Policy

**Risk: 4/5** — Policies are authorization (can this user perform this action?), not business rules (should this action happen given domain state?). Business logic in policies is untestable by domain tests and creates hidden coupling.

**Smell:** Policy calls external services, calculates pricing, checks subscription limits, or modifies records.

```ruby
# BEFORE (AI slop)
class PostPolicy < ApplicationPolicy
  def publish?
    # authorization + business logic mixed
    return false unless user.admin? || record.author_id == user.id

    # business rule: check subscription limit — does NOT belong here
    published_count = user.posts.where(status: :published).count
    user.subscription.plan == "pro" || published_count < 3
  end

  def update?
    # modifying a record in a policy — a side effect!
    record.touch(:last_policy_check_at)
    user.admin? || record.author_id == user.id
  end
end
```

```ruby
# AFTER — policy checks only authorization; business rules in service/model
class Post < ApplicationRecord
  def publishable_by?(user)
    # domain rule lives in the model
    return true if user.subscription.plan == "pro"
    user.posts.published.count < 3
  end
end

class PostPolicy < ApplicationPolicy
  def publish?
    # authorization: can this user publish at all?
    author_or_admin? && record.publishable_by?(user)
  end

  def update?
    # no side effects — pure predicate
    author_or_admin? && !record.locked?
  end

  private

  def author_or_admin?
    user.admin? || record.author_id == user.id
  end
end

# In the controller, business validation is separate from authorization
def publish
  authorize @post
  result = PostPublishingService.new(@post, current_user).call
  # handle result...
end
```

**Safety checks:**
- [ ] Grep policy files for `.save`, `.update`, `.create`, `.destroy`, `.touch` — side effects in policies
- [ ] Grep policy files for external service instantiations (`StripeClient`, `HTTP.get`, etc.)
- [ ] Grep policy files for subscription limit checks, quota checks — move to model predicates
- [ ] Policy methods should be pure predicates: input (user, record) → boolean output only

---

### Correct Pundit Policy Pattern

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user

    @user   = user
    @record = record
  end

  def index?  = false
  def show?   = false
  def create? = false
  def new?    = create?
  def update? = false
  def edit?   = update?
  def destroy? = false

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class}#resolve has not been implemented"
    end

    private

    attr_reader :user, :scope
  end
end

# app/policies/invoice_policy.rb
class InvoicePolicy < ApplicationPolicy
  def show?
    user.admin? || record.user_id == user.id
  end

  def create?
    user.present?
  end

  def update?
    user.admin? && record.draft?
  end

  def destroy?
    user.admin? && record.draft?
  end

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user: user)
    end
  end
end

# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @invoices = policy_scope(Invoice).order(created_at: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
    authorize @invoice
  end
end
```

**Key properties of a correct Pundit policy:**
- `ApplicationPolicy` defaults all actions to `false` — opt in, not opt out
- `Scope#resolve` always implemented — no `NotImplementedError` surprises
- `after_action :verify_authorized` ensures no action skips authorization
- Policy is a pure predicate — no side effects, no external calls

---

## QUICK REFERENCE — RISK SCORES AND SAFETY CHECKS SUMMARY

### Risk Score Legend

| Score | Meaning |
|-------|---------|
| 1 | Cosmetic / unnecessary code — safe to remove any time |
| 2 | Indirect / maintenance issue — low urgency |
| 3 | Potential bug or performance degradation in production |
| 4 | Silent data corruption or security issue — fix before next deploy |
| 5 | Active security hole, data loss, or financial impact — fix immediately |

### Top 10 High-Risk Patterns (4-5 Score)

1. **Risk 5** — Form object persisting via `update_all` / raw SQL (bypasses model callbacks)
2. **Risk 5** — Form object missing `ActiveModel::Model` (validations silently never run)
3. **Risk 5** — Presenter/serializer triggering N+1 DB queries
4. **Risk 5** — Non-idempotent Sidekiq job (double-charge, double-send on retry)
5. **Risk 5** — Passing AR objects as job arguments (stale data, bloated Redis)
6. **Risk 5** — Pundit policy that returns `true` for all actions (open access)
7. **Risk 4** — Serializer with manual `to_json` override leaking sensitive fields
8. **Risk 4** — Serializer computing business logic (prices, discounts) inline
9. **Risk 4** — Business logic in Pundit policy (side effects, untestable)
10. **Risk 4** — No dead-letter handling on financial Sidekiq jobs

### Grep Commands for Fast Audit

```bash
# Form objects missing ActiveModel::Model
grep -rn "class.*Form$" app/forms/ | grep -v "ActiveModel::Model"

# Form objects persisting directly
grep -rn "update_all\|connection\.execute" app/forms/

# Query objects returning arrays
grep -rn "\.to_a\|\.map\|\.each" app/queries/

# Presenters/serializers with DB calls
grep -rn "\.where\|\.find\|\.count\|\.includes" app/presenters/ app/serializers/

# Models with to_json / as_json overrides
grep -rn "def to_json\|def as_json" app/models/

# Jobs with business logic (> 15 lines in perform)
grep -n "def perform" app/jobs/**/*.rb

# Jobs with AR objects as arguments (look for .new with object types)
grep -rn "perform_later\|perform_now" app/ --include="*.rb" | grep -v "_id"

# Jobs with perform_now in production code
grep -rn "perform_now" app/ --include="*.rb"

# Pundit policies always returning true
grep -rn "true$" app/policies/ | grep "def "

# Policies checking role strings directly
grep -rn 'user\.role ==' app/policies/

# Policies with side effects
grep -rn "\.save\|\.update\|\.create\|\.destroy\|\.touch" app/policies/
```

---

*Last updated: 2026-06-06 | Covers Rails 7.x / 8.x, Sidekiq 7.x, Pundit 2.x, ActiveModelSerializers 0.10.x, Blueprinter 1.x*
