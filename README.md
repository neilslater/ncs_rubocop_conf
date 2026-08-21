# NCS RuboCop configuration

`ncs_rubocop_conf` packages Neil Slater's versioned RuboCop policy for Ruby
repositories. It is developed and tagged on GitHub, but is not published to
RubyGems.

Version 0.1.x supports Ruby 3.3 and later and constrains RuboCop/plugin updates
to the reviewed 1.88.x, rubocop-rake 0.7.x, and rubocop-rspec 3.10.x lines.
Changing any of those lines is a policy upgrade that must be reviewed against
the effective configuration and profile fixtures before release.

## Profiles

- `config/base.yml` targets Ruby 3.3, enables new cops, folds multiline array
  and hash literals in core length metrics, and excludes keyword arguments from
  parameter-list counts.
- `config/rake.yml` loads `rubocop-rake` and treats Rake `namespace` blocks as
  structural DSL containers.
- `config/rspec.yml` loads `rubocop-rspec` and applies the shared literal
  folding semantics to example length. RSpec's default length and expectation
  limits remain unchanged.
- `config/native_extension.yml` narrowly excludes `mkmf`'s supported global
  compiler variables from `Style/GlobalVars` in native `extconf.rb` files.

Consumers should pin an immutable Git tag:

```ruby
gem 'ncs_rubocop_conf',
    github: 'neilslater/ncs_rubocop_conf',
    tag: 'v0.1.0',
    require: false
```

Then opt into only the relevant profiles:

```yaml
inherit_gem:
  ncs_rubocop_conf:
    - config/base.yml
    - config/rake.yml
    - config/rspec.yml
    - config/native_extension.yml
```

Run `bundle exec ncs-rubocop-conf-audit` alongside RuboCop. The audit rejects a
`.rubocop_todo.yml`, inline `rubocop:todo` directives, nonspecific or
non-standalone disable directives, and exceptions without an immediately
preceding `# RuboCop rationale:` comment. Human review is still required before
adding or retaining any repository-specific exception.

## Development

Install dependencies and run the complete local gate:

```sh
bundle install
bundle exec rake
```
