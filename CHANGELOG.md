# Changelog

## 0.1.0 - 2026-08-20

Initial Convolver pilot release.

- Add base metric semantics that fold array/hash literals and do not count
  keyword arguments in parameter lists.
- Add opt-in Rake, RSpec, and native-extension profiles. Upstream RSpec limits
  remain five lines and one expectation; Rake `namespace` joins the upstream
  `refine` block-length allowance; the native profile excludes only
  `Style/GlobalVars` in `ext/**/extconf.rb`.
- Add `ncs-rubocop-conf-audit` to reject TODO configs/directives, nonspecific
  inline disables, and local exceptions without adjacent rationale comments.
- Constrain the policy to RuboCop 1.88.x, rubocop-rake 0.7.x, and
  rubocop-rspec 3.10.x. The pilot resolves to 1.88.2, 0.7.1, and 3.10.2.
- Migration: replace copied plugin and metric configuration with `inherit_gem`,
  opt into only relevant profiles, and run the exception audit beside RuboCop.
