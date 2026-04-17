# Moving `oci-kove-terraform` to its own root

1. Copy or move the entire **`oci-kove-terraform/`** directory to the new location (e.g. `C:\work\oci-kove-terraform`).
2. Initialize Git there: `git init`, add remote, first commit.
3. Update **module `source`** in consumers:
   - From monorepo-relative paths → `git::https://.../oci-kove-terraform.git//modules/<name>?ref=<tag>`.
4. Update **CI** (GitHub Actions, ORM zip jobs) to clone or checkout this repo instead of a subfolder of `kove-oci-build-2`.
5. Tag releases (`v0.1.0`) when modules stabilize; pin examples and downstream stacks to tags.

Relative paths inside **this** repo (`examples/minimal` → `../../modules/kove-context`) stay valid as long as the folder layout is unchanged.
