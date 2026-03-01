# Rails Best Practices — Active Record

## QUERIES

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

## AR MODEL RULES

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
