# NCS RuboCop configuration

`ncs_rubocop_conf` packages Neil Slater's versioned RuboCop policy for Ruby
repositories. It is developed and tagged on GitHub, but is not published to
RubyGems.

Version 0.3.x supports Ruby 3.3 and later and constrains RuboCop/plugin updates
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
    tag: 'v0.3.0',
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
`path:line: message`, a finding count, and exit 1. Unsupported configuration also
exits 1, with a distinct `Configuration not supported yet by the exception
audit` explanation; the existing summary still calls findings offenses. Run RuboCop separately to
validate configuration and code. Operational and option errors currently may
raise exceptions; success is not proof that all possible inputs were inspected.

The audit recursively selects `.rubocop.yml` and `.rubocop.yaml`, and source
files ending in `.rb`, `.rake`, or `.gemspec`, plus `Gemfile` and `Rakefile`.
It also selects regular Ruby scripts under the audited root's `bin/` directory,
including nested extensionless scripts with a direct Ruby or `env ruby` /
`env -S ruby` shebang. Shell scripts, other language launchers, binary files,
and extensionless symlinks are not added by this rule. It rejects discovered `.rubocop_todo.yml` files. Directories named `.bundle`,
`.git`, `coverage`, `pkg`, `tmp`, and `vendor` are pruned at every depth below
the root. RuboCop's own exclusions do not control this scan.

The audit recognizes references to the four profiles in this gem without
following configuration inheritance. Consumer `inherit_gem` references must name
this gem and its known profile paths. Direct `inherit_from` references are
recognized only when they resolve lexically to profiles in the running audit's
own package or source checkout, preserving this repository's self-hosting and
source-profile fixtures. A consumer-local file named `config/base.yml` is not
one of those sources. Other inheritance is reported as unsupported without
opening its target.

A static YAML syntax check reports the first unsupported construct in each
selected configuration and stops exception interpretation for that file. It
never evaluates ERB, constructs YAML objects, loads custom Ruby or plugins, or
resolves anchors and merges. Within supported mappings, `AllCops` and cop-level
`Exclude`, `Max`, and literal `Enabled: false` settings require the preceding
rationale. This is a deliberately limited check; RuboCop remains responsible for
cop names, options, and effective configuration validation.

`.ru` files, extensionless scripts outside `bin`, and ERB/generated Ruby are not
newly discovered. Filesystem traversal still has limitations around symlinks
and unreadable directories, and root/argument handling is unchanged. These
limits are separate from the unsupported-configuration checks in 0.3.0.

### Configuration not supported yet by the exception audit

This tool assumes cooperative use: prefer fixing RuboCop findings by refactoring
code, and obtain approval for justified exceptions. It is not a comprehensive
interpreter of every RuboCop configuration form.

The supported workflow uses this gem's profiles and straightforward YAML with
unquoted mapping keys, two-space setting indentation, and literal `true`/`false`
booleans. Quoted values such as glob strings, ordinary lists, `inherit_mode`
list merging, and plugin declarations remain part of that workflow. This
repository loads its own tracked profiles directly for development.

The following configuration features are **not supported yet by the audit**:

- Quoted section or setting keys, flow mappings, alternative mapping indentation,
  and equivalent boolean spellings such as `Enabled: no`.
- YAML anchors, aliases, `<<` merges, explicit YAML tags, complex keys, duplicate keys,
  multiple documents, and ERB or configuration-driven custom Ruby loading.
- Whole-department exception settings and global default-disable switches such
  as `DisabledByDefault` and `EnabledByDefault`.
- Inheritance from sources other than this gem's known profiles, including
  custom local files, URLs, globs, and other gems. The audit does not follow or
  validate those sources; known profiles are the four listed above.

These are current implementation limits, not permanent policy prohibitions or
claims that the syntax is invalid in RuboCop. We will consider extending support
when a consuming repository needs it. Approval of an exception and support for
its configuration syntax are separate questions.

Version 0.3.0 reports these unsupported forms with a source location where
available, and fails the audit instead of silently accepting the configuration.
Invalid YAML and unexpected document/section shapes also fail. A rationale
comment cannot override an unsupported-form diagnostic. Use the documented
subset or request support for a concrete need; the checker does not rewrite
configuration or promise to detect every possible evasion. Continue running
RuboCop itself alongside the audit.

When upgrading from 0.2.x, run the audit against each consumer. Resolve newly
reported `bin` directives through the usual refactoring/exception review, and
simplify unsupported configuration or request the needed support. Commit the
consumer's new immutable tag pin and resolved lockfile together.

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
