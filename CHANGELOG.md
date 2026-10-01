# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-01

First public release.

### Added

- OAuth2 token handling (`client_credentials` and `refresh_token` grants) with pluggable token storage; `IntacctRest::TokenStore::Memory` is the default.
- `IntacctRest::Query` for `POST /services/core/query`, with `IntacctRest::Filter` operators (`eq`, `not_eq`, `gt`, `gte`, `lt`, `lte`, `and`) and pagination via `#each_page` (raises `TooManyPagesError` past `max_pages`).
- `IntacctRest::Objects#list`/`#find` for reading records from the objects API.
- `IntacctRest::SchemaGenerator` and `IntacctRest::SchemaSource` for discovering and loading per-resource field lists.
- Create endpoints: `Endpoints::CreateVendor`, `CreateCustomer`, `CreateInvoice`, `CreateInvoiceLine`, `CreateTerm`, `CreateBill`, `CreateBillLine`, built on the generic `IntacctRest::Post`.
- Vendor update (`PATCH`) via `Endpoints::UpdateVendor` and the generic `IntacctRest::Patch`; only the fields set are sent.
- Endpoints check the `results:` fields they expect on a successful response and raise `ApiError` when one is missing.
- Custom fields via `IntacctRest::CustomField`, serialized as `"namespace::name"` (default namespace `nsp`).
- `Model::Currency` and `Model::Contact` helpers for building nested payloads.
- A validation DSL (`Model::Base.validate`) with `:presence`, `:kind_of`, `:inclusion` and `:custom` validators and `on: :create`/`on: :update` contexts.
- `IntacctRest::Result::Success`/`Result::Error`: endpoints return a Result and never raise for the HTTP outcome.
- An error hierarchy under `IntacctRest::Error`: `AuthenticationError`, `ApiError`, `ResponseParseError`, `ValidationError`, `TooManyPagesError`, `SchemaGenerationError`, `SchemaLoadError`.
- Optional `on_error` hook on `Configuration`, called with `(error, context:)` right before the gem raises an `ApiError` from an Intacct request (non-2xx response or `ia::error` payload), an `AuthenticationError`, a `ResponseParseError`, or a `SchemaLoadError`; exceptions raised by the hook are ignored.
- MIT license, CONTRIBUTING.md, and GitHub issue/pull request templates.

[Unreleased]: https://github.com/bernespinoza/intacct-rest/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/bernespinoza/intacct-rest/releases/tag/v1.0.0
