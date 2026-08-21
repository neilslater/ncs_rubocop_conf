# Changelog

## 0.2.0 - 2026-08-21

Controlled upgrade and cross-project rollout baseline.

- Set `AllCops/TargetRubyVersion: 3.3` in the shared base profile so every
  consumer receives the accepted global Ruby minimum.
- Upgrade the reviewed RuboCop line from 1.88.x to 1.89.x. The release resolves
  to RuboCop 1.89.0 while retaining rubocop-rake 0.7.1 and rubocop-rspec 3.10.2.
- Review RuboCop 1.89's effective configuration changes. `NewCops: enable`
  accepts the new pending `Lint/DeprecatedReference` and `Lint/NameTypo` cops;
  both remain inactive without the upstream opt-in project index and optional
  `rubydex` dependency. The disabled `Lint/UnusedPrivateMethod` cop remains
  disabled.
- Validate the package fixtures and complete Convolver gate with no offenses,
  exceptions, behavior changes, or coverage changes before release.

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
- Require Ruby 3.3 or later.
- Migration: replace copied plugin and metric configuration with `inherit_gem`,
  opt into only relevant profiles, and run the exception audit beside RuboCop.
