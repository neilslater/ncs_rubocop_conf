# Changelog

## 0.3.0 - 2026-09-21

- Audit regular Ruby scripts beneath the root `bin/` directory, including
  extensionless Ruby launchers. Preserve existing file selection and skip
  non-Ruby/binary launchers and extensionless symlinks.
- Statically inspect selected RuboCop YAML and report unsupported syntax,
  document/section shapes, global/department disabling, custom Ruby loading,
  and inheritance outside this gem's known profiles. These findings fail the
  audit with source locations; a rationale does not override them. No external
  inheritance is followed and no ERB, YAML objects, or custom code is evaluated.
- Preserve supported consumer syntax, optional plugins, source-profile
  self-hosting, existing rationale checks, and explicit config-path semantics.
  Unsupported means not supported yet, not permanently prohibited by policy.
- Migration: pin `v0.3.0`, update the consumer
  lockfile, and run the full consumer gate. Address newly found bin directives
  and unsupported configurations before adopting; request extended support
  only when needed. Shared profiles and runtime dependency lines are unchanged.

- Correct the native-profile description to its existing whole-cop exclusion
  for `**/ext/**/extconf.rb`; document current audit inputs, limitations, and
  public interfaces, and clarify tag versus consumer-lockfile guarantees.
- Strengthen profile boundary and installed-package validation without changing
  distributed policy. Enforce 95% line/branch coverage, dependency auditing,
  public API documentation, and lockfile-selected Bundler in development/CI.

## 0.2.1 - 2026-09-20

- Audit spaced `disable`/`todo` directives and negative `push` operands using
  an isolated adapter to the reviewed RuboCop grammar. Negative pushes now
  require specific cops, standalone placement, and an adjacent nonempty
  rationale, just like disables; positive pushes and restoration remain valid.
- Accept trailing `--` annotations without treating them as cop names or
  rationales. Ignore escaped example comments, strings, and heredocs; check
  directives embedded in Ruby block comments. Reject malformed suppressions
  even when RuboCop applies their parsed prefix.
- Recognize multi-component cop names and reuse one source snapshot per file
  audit. Add actual RuboCop suppression fixtures for grammar and nested
  push/pop restoration as an upgrade contract for the private parser API.
- Migration: update each consumer's immutable tag pin to `v0.2.1` and its
  lockfile, then run its complete gate. Resolve newly reported
  suppressions through removal or approved, documented specific-cop exceptions.

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
