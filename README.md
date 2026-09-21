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
- `config/native_extension.yml` excludes the entire `Style/GlobalVars` check
  for files matching `**/ext/**/extconf.rb`, including arbitrary globals in
  those files. Other checks still run there; globals elsewhere remain checked.

Consumers should pin an immutable Git tag:

```ruby
gem 'ncs_rubocop_conf',
    github: 'neilslater/ncs_rubocop_conf',
    tag: 'v0.2.1',
    require: false
```

The immutable tag pins this package's sources and dependency constraints. Each
consumer must commit its own `Gemfile.lock` to pin the resolved RuboCop, plugin,
and transitive dependency versions. A tag alone does not guarantee identical
toolchains. This repository's development lockfile is deliberately not packaged.

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

For YAML exceptions, put the rationale immediately before the section header,
not before the individual setting:

```yaml
# RuboCop rationale: the external DSL requires globals in this adapter.
Style/GlobalVars:
  Exclude:
    - lib/external_adapter.rb
```

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

## Audit interface and current limits

```sh
bundle exec ncs-rubocop-conf-audit --root /path/to/repository
bundle exec ncs-rubocop-conf-audit --help
```

The root defaults to the current directory. Clean audits print
`RuboCop exception audit passed` and exit 0; policy findings print
`path:line: message`, an offense count, and exit 1. Run RuboCop separately to
validate configuration and code. Operational and option errors currently may
raise exceptions; success is not proof that all possible inputs were inspected.

The audit recursively selects `.rubocop.yml` and `.rubocop.yaml`, and source
files ending in `.rb`, `.rake`, or `.gemspec`, plus `Gemfile` and `Rakefile`.
It rejects discovered `.rubocop_todo.yml` files. Directories named `.bundle`,
`.git`, `coverage`, `pkg`, `tmp`, and `vendor` are pruned at every depth below
the root. RuboCop's own exclusions do not control this scan.

Current discovery does not follow configuration inheritance or recognize `.ru`
files and extensionless Ruby executables. YAML checking recognizes unquoted
`AllCops` or `Department/Cop` section headers and two-space-indented `Exclude`,
`Max`, or literal `Enabled: false` settings. It is a textual check, not a YAML
validator: alternative spellings, department/global switches, aliases, and
invalid YAML can escape detection. Filesystem traversal also has limitations
around symlinks and unreadable directories. These limitations require separate
behaviour changes; they are not guarantees supplied by this release.

### Ruby API

Require `ncs_rubocop_conf`. The supported Ruby entry point is
`NcsRuboCopConf::ExceptionAudit.new(root: Dir.pwd, config_paths: nil)`.
Explicit `config_paths:` accepts absolute paths or paths relative to the root
and **replaces** automatic configuration selection; it does not replace source
or TODO-file scanning. Use `offenses` for the cached array of `PolicyOffense`
values (`path`, `line`, `message`), `success?` for a boolean, and `report(out:)`
to write diagnostics and the summary to an IO (default `$stdout`, returns nil).
`PolicyOffense#format(root:)` formats a relative location. Create a new audit
after changing files. Other implementation classes are internal.

The public documentation contract covers this CLI, these Ruby interfaces, and
all four profiles above. YARD comments document the Ruby API; this README owns
the CLI, profile reference, and current limitations.

## Development

Install dependencies and run the complete local gate:

```sh
bundle install
bundle exec rake
```

The complete gate runs specs with at least 95% line and 95% branch coverage of
all maintained library code, RuboCop, the exception audit, dependency auditing
against an updated advisory database, and public API documentation checks.
Dependency auditing requires network access and fails if its database cannot be
updated. Generated coverage and YARD output remain untracked and unpackaged.

Run `bundle exec rake package_check` for an offline build, exact file-inventory
check, disposable installation, and consumer profile/CLI smoke test using the
already resolved dependencies. CI runs the complete gate on Ruby 3.3, 3.4, and
4.0, with package integration on 4.0 and Bundler selected by the lockfile.

When upgrading RuboCop or plugins, review changed defaults, new/renamed/removed
cops, dependency resolution, directive grammar (including push/pop), and
configuration loading and file discovery. Run the profile boundaries and actual
suppression/restoration conformance tests before accepting the upgrade.
