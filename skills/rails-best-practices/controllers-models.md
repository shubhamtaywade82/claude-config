# Rails Best Practices — Controllers & Models

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

**Pass locals to partials — never rely on instance variables:**
```ruby
# Bad — partial implicitly depends on @post from controller
render 'post_summary'

# Good — explicit, testable, reusable
render 'post_summary', post: @post
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
