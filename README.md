# MailDude

MailDude is a mountable Rails engine and Ruby gem that captures Action Mailer deliveries in development, QA, and test-like environments. It registers an Action Mailer delivery method named `:mail_dude`, stores outgoing email instead of sending it externally, and exposes a mailbox UI for reviewing messages, headers, raw source, and attachments.

## Why It Exists

Local and QA applications often need realistic email delivery flows without risking real SMTP delivery to customers. MailDude captures the final `Mail::Message` through a delivery method, which prevents SMTP, sendmail, or other external delivery agents from being used.

## Requirements

MailDude supports Ruby 3.1+ and Rails >= 7.0.3.1, < 8.0. CI covers Ruby 3.1 and 3.2 across Rails 7.0.3.1, 7.1, and 7.2.

## Installation

```ruby
group :development, :qa do
  gem "mail_dude"
end
```

Run the installer:

```bash
bin/rails generate mail_dude:install
```

For database storage:

```bash
bin/rails generate mail_dude:install --database
bin/rails db:migrate
```

## Action Mailer Configuration

```ruby
config.action_mailer.delivery_method = :mail_dude
config.action_mailer.perform_deliveries = true
```

MailDude registers this delivery method when Action Mailer loads:

```ruby
ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :mail_dude, MailDude::DeliveryMethod
end
```

## Secure Mounting

MailDude does not authenticate or authorize users. Mount it behind your host application’s existing controls.

```ruby
authenticate :user, lambda { |u| Ability.new(u).can?(:manage, MailDude::Dashboard) } do
  mount MailDude::Engine, at: "/mail_dude"
end
```

Example CanCanCan-style subject:

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    can :manage, MailDude::Dashboard if user.admin?
  end
end
```

MailDude does not depend on Devise, CanCanCan, Sidekiq, Redis, or a host app user model.

## Configuration

```ruby
MailDude.configure do |config|
  config.enabled_environments = %w[development qa test]
  config.storage = :file
  config.storage_path = Rails.root.join("tmp", "mail_dude")
  config.max_messages = 1_000
  config.retention_period = 7.days
  config.max_message_size = 25.megabytes
  config.allow_production = false
  config.capture_attachments = true
  config.capture_mailer_metadata_headers = true
  config.default_per_page = 50
  config.live_updates = false
  config.live_update_stream_name = "mail_dude:#{Rails.env}:messages"
  config.live_update_authorizer = ->(_connection) { false }
end
```

`MailDude.enabled?`, `MailDude.store`, `MailDude.reset_store!`, and `MailDude.reset_configuration!` are available. The reset helpers mainly exist for tests and isolated tooling.

## Storage Options

| Storage | Best for | Pros | Cons |
|---|---|---|---|
| `:file` | Local development and single-node QA | No DB migrations, easy to inspect, easy to clear | Local disk may be ephemeral; not shared across containers/dynos |
| `:database` | QA/staging-like environments with multiple app processes | Shared, persistent, searchable, works across nodes | Requires migration; can store sensitive content in DB; needs cleanup |
| `:memory` | Tests and throwaway demos | Fast, simple | Process-local, lost on restart |

## FileStore Path

The default FileStore path is `Rails.root/tmp/mail_dude`. MailDude does not default to global `/tmp/mail_dude`, because multiple Rails apps on the same machine could collide. If Rails root is unavailable, MailDude falls back to `Dir.tmpdir/mail_dude`.

FileStore under `Rails.root/tmp/mail_dude` may be wiped by deploys, container restarts, or cleanup scripts. Use `:database` or persistent shared disk for multi-node QA.

## DatabaseStore Setup

Use database storage when QA runs multiple processes, containers, or dynos:

```ruby
config.storage = :database
```

Then copy and run the migration:

```bash
bin/rails generate mail_dude:install --database
bin/rails db:migrate
```

DatabaseStore uses `mail_dude_stored_emails` and does not require Active Storage.

## MemoryStore

MemoryStore is useful for tests and throwaway demos:

```ruby
config.storage = :memory
```

It is thread-safe but process-local and loses messages on restart.

## UI Overview

Mounting the engine exposes a mailbox UI with a message list, selected message metadata, HTML preview in a sandboxed iframe, plain text, headers, raw source, search, pagination, delete, clear, and attachment download links.

## Action Cable Live Updates

MailDude can optionally use Action Cable to show a “New message captured” banner without requiring a page reload. This is disabled by default.

```ruby
MailDude.configure do |config|
  config.live_updates = true
  config.live_update_stream_name = "mail_dude:#{Rails.env}:messages"
  config.live_update_authorizer = lambda { |connection|
    user = connection.respond_to?(:current_user) ? connection.current_user : nil
    user && Ability.new(user).can?(:manage, MailDude::Dashboard)
  }
end
```

The authorizer receives the Action Cable `connection`, not a controller. This is intentional: mounting `/mail_dude` behind a route constraint does not protect `/cable`. Your host app must expose whatever identity the authorizer needs from `ApplicationCable::Connection`.

Example host connection:

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      env["warden"].user || reject_unauthorized_connection
    end
  end
end
```

MailDude rejects cable subscriptions when `live_updates` is false or when `live_update_authorizer` returns false. Broadcast payloads include only list metadata such as id, subject, sender, recipients, captured time, and attachment count. They do not include raw source, headers, bodies, or attachment bytes.

## Cleanup And Retention

MailDude prunes after capture using:

```ruby
config.max_messages = 1_000
config.retention_period = 7.days
```

Set either value to `nil` to disable that pruning dimension.

## Rake Tasks

```bash
bin/rails mail_dude:clear
bin/rails mail_dude:prune
bin/rails mail_dude:stats
```

`clear` removes all captured messages. `prune` applies the configured retention and count limits. `stats` prints the storage adapter, total count, and storage location details.

## Security Considerations

Captured emails may contain PII, password reset links, invoices, tokens, and secrets.

Do not expose `/mail_dude` publicly. Do not enable in production unless you fully understand the risk. Prefer short retention. Prefer DatabaseStore or persistent disk in multi-node QA. FileStore under `Rails.root/tmp/mail_dude` may be wiped by deploys, container restarts, or cleanup scripts.

Captured HTML is rendered in a sandboxed iframe with a restrictive Content Security Policy. Attachments are extracted from raw `.eml` data on request and filenames are sanitized.

If Action Cable live updates are enabled, protect subscriptions with `live_update_authorizer`. The `/mail_dude` route constraint does not authorize `/cable`.

## Production Warning

Production is disabled by default. If `:mail_dude` is configured in a disabled environment, delivery raises `MailDude::DisabledEnvironmentError` and does not store or send the email.

An escape hatch exists:

```ruby
config.allow_production = true
```

Avoid this unless you have a reviewed operational and data-retention plan.

## Testing The Gem Locally

```bash
bundle install
bundle exec rspec
bundle exec rubocop
bundle exec rake
```

The test suite uses a dummy Rails app, SQLite for DatabaseStore specs, RSpec, and SimpleCov with 100% line and branch coverage gates.

## Contributing

Keep changes small, covered, and consistent with Rails engine conventions. Do not add host-app authentication dependencies to MailDude itself.

## License

MIT. See `LICENSE.txt`.
