# Project Pattern Detection Checklist

Use this when executing Step 2 of the code review. Read 2–3 sibling files and extract answers to these questions.

## Controllers

- [ ] What is the base controller? What does it provide? (`ApplicationController`, `Api::BaseController`, etc.)
- [ ] How are successful responses returned? (`render json:`, Jbuilder, serializer gem, `respond_with`)
- [ ] How are errors returned? (specific format, status codes, error serializer)
- [ ] How is authentication handled? (before_action name, devise helper, JWT check)
- [ ] How is authorization handled? (Pundit, CanCan, inline check)
- [ ] What is the permitted params naming convention? (`user_params`, `permitted_params`, `order_params`)
- [ ] Are there rescue_from blocks? What do they rescue and how do they respond?
- [ ] How are records loaded? (before_action, inline, scoped to current_user)

## Models

- [ ] Is there a shared base concern all models include? (e.g. `Auditable`, `Timestampable`)
- [ ] Are validations inline or in custom validator classes in `app/validators/`?
- [ ] How are enums defined? (hash syntax, symbol/string values, prefix)
- [ ] How are scopes named? (verb, adjective, noun convention)
- [ ] How are complex class methods structured vs scopes?
- [ ] Is there an `annotate` schema comment block at the top?
- [ ] Are STI or polymorphic associations used? How?
- [ ] How are callbacks ordered? Is there a consistent ordering convention?

## Service Objects

- [ ] What is the calling convention? (`.call(args)`, `.new(args).call`, `.run(args)`)
- [ ] What does a service return? (Result object, boolean, model instance, raises on failure)
- [ ] What class naming convention? (`Orders::Create`, `CreateOrder`, `OrderCreationService`)
- [ ] Is there a base class? (`ApplicationService`, `BaseService`) What does it provide?
- [ ] How are dependencies injected? (constructor, keyword args, defaults)
- [ ] Is there a consistent Result/response object pattern?

## Background Jobs / Workers

- [ ] What job framework? (Sidekiq, ActiveJob, Delayed::Job)
- [ ] How are retries configured?
- [ ] How are errors handled? (retry, dead letter, alert)
- [ ] Naming convention? (`OrderProcessingJob`, `ProcessOrderWorker`)

## Specs

- [ ] Factory style? (`create(:order)`, `FactoryBot.create(:order)`, `build_stubbed`)
- [ ] Are shared examples used? Where? (`shared_examples_for`, `it_behaves_like`)
- [ ] What helpers are included? (`include JsonHelpers`, `include AuthHelpers`, `include ActiveSupport::Testing::TimeHelpers`)
- [ ] How are contexts named? ("when...", "with...", "given...")
- [ ] Is there a consistent subject/let block ordering?
- [ ] How are request specs structured? (describe verb+path, context for auth states)
- [ ] What matchers are commonly used? (custom matchers, shoulda-matchers)
