# Contributing to IntacctRest

Thanks for helping out. IntacctRest is a small Ruby client for Sage Intacct's REST API v1, and contributions of all sizes are welcome.

## How to contribute

1. **Open an issue** describing the bug or feature (the bug report and feature request templates help). For anything larger than a small fix, wait for a maintainer to acknowledge the issue before you start.
2. **Fork** [bernespinoza/intacct-rest](https://github.com/bernespinoza/intacct-rest).
3. **Create a branch** following the repo convention:

   ```sh
   git checkout -b feature/<short-name>   # e.g. feature/create-bill
   ```

4. **Run the tests**, and keep them green. New behavior comes with tests (Minitest + WebMock, under `test/`, mirroring `lib/`):

   ```sh
   bundle install
   bundle exec rake test
   ```

5. **Open a pull request** against `main` that references the issue (`Closes #n`) and asks for a merge.
6. **A maintainer reviews and merges.**

## Design notes

- **Framework-agnostic.** No Rails, ActiveRecord, or Redis dependency. The host application can supply its own token store (in-memory by default, `IntacctRest::TokenStore::Memory`) and an optional `on_error` hook.
- **Nested objects stay raw Hashes** using Intacct's camelCase key names, e.g. `term: { "id" => "Net 30" }`. Only top-level fields get snake_case accessors. Helpers like `Model::Currency` and `Model::Contact` exist to build those Hashes via `#payload`; they're optional.
- **New endpoints follow the existing pattern:** a `Model::X < Model::Base` (data + `validate`, with `on: :create`/`on: :update` where it matters), the generic `IntacctRest::Post`/`IntacctRest::Patch`, and an `Endpoints::CreateX`/`Endpoints::UpdateX` use case that checks `results:`. `Model::Vendor` with `Endpoints::CreateVendor` and `Endpoints::UpdateVendor` is a good reference.
- **Update README.md** in the same pull request as any public API change.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE.txt).
