# NCS RuboCop configuration

`ncs_rubocop_conf` packages Neil Slater's versioned RuboCop policy for Ruby
repositories. It is developed and tagged on GitHub, but is not published to
RubyGems.

Version 0.2.x supports Ruby 3.3 and later and constrains RuboCop/plugin updates
to the reviewed 1.89.x, rubocop-rake 0.7.x, and rubocop-rspec 3.10.x lines.
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
    tag: 'v0.2.0',
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
`.rubocop_todo.yml`, active `rubocop:todo` directives, nonspecific or
non-standalone suppressions, and exceptions without an immediately preceding,
nonempty `# RuboCop rationale:` comment. Human review is still required before
adding or retaining any repository-specific exception.

For source directives, the audit recognizes the reviewed RuboCop grammar,
including whitespace around `:` and the mode. A `disable` must name specific
cops (comma-separated for multiple cops). Every negative `push` operand must
also name a specific cop; negative departments and `-all` are rejected. Both
forms must be on their own line with an immediately preceding rationale:

```ruby
# RuboCop rationale: the external DSL requires this global variable.
# rubocop : disable Style/GlobalVars -- optional annotation
$example = 1
# rubocop:enable Style/GlobalVars

# RuboCop rationale: the external DSL requires this global variable.
# rubocop:push +Layout/LineLength -Style/GlobalVars
$example = 2
# rubocop:pop
```

A trailing `-- annotation` is accepted but does not replace the preceding
rationale. Bare or positive-only pushes and `pop`/`enable` restoration do not
introduce new exceptions. Restoring a prior suppression does not excuse its
original directive from the policy.

Strings, heredocs, and RuboCop's escaped `# # rubocop:...` examples are ignored.
Ruby block comments are recognized as whole comment tokens; suppressing
directives embedded in them do not qualify as standalone directives. Recognized
`todo` forms are always rejected. Malformed `disable` and `push` forms are
rejected even when RuboCop applies a parsed prefix. Unknown modes and
restoration syntax are left to RuboCop's own validation. Specific cop names may
contain multiple namespace components; the audit checks their form, while
RuboCop checks which cops are available.

## Development

Install dependencies and run the complete local gate:

```sh
bundle install
bundle exec rake
```
