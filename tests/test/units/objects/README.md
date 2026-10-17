# Private legacy-object test fixture

`LegacyObjects` is the original FPC Objects implementation, with its unit name
changed to prevent it from being treated as a public runtime API. Its original
copyright and license header are retained. The
[original runtime license](../../../../rtl/COPYING.FPC) remains in the compiler tree. The forwarding include in `tests/tbs`
lets the compiler regressions use this same fixture without an installed unit.

The tests retain inheritance/property, nested callback/self, constructor status,
virtual constructor dispatch, destructor/stream ownership, type identity and
managed-string collection coverage. `testobj` and `testobj1` exercise a legacy
ShortString stream format and explicitly declare those types. `$H-` does not
select ShortString in Nexus; see `nexusfpc-language-rule-changes.md`.

Compile from an external output directory with the matching RTL and this
fixture directory on the unit path. Generated binaries, units and temporary
files belong under the development worktree, never in this source folder.
