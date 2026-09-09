# STELLAR POS architecture

## Goal

Keep presentation, business rules, and persistence independent so local storage and a future cloud backend can be introduced without rewriting the POS.

## Dependency direction

`presentation -> domain -> data -> infrastructure`

UI widgets should not know about Hive, SQLite, Firebase, Supabase, HTTP clients, or SharedPreferences. Providers coordinate presentation state and invoke domain operations. Repositories are contracts; data sources implement persistence.

## Feature boundaries

The application is being migrated toward:

- `features/products`
- `features/inventory`
- `features/sales`
- `features/purchases`
- `features/clients`
- `features/debts`
- `features/electronic_balance`
- `features/catalog`
- `features/settings`

Each feature may grow into `data/`, `domain/`, and `presentation/` when its complexity justifies it. Small compatibility entry points are intentionally kept during migration to avoid a risky all-at-once import rewrite.

## Core rules

1. Business rules belong in pure domain services/use cases.
2. Providers own UI/application state, not database code.
3. Repositories hide persistence technology.
4. Data sources perform serialization and storage operations.
5. Persisted entities have stable IDs and sync metadata where applicable.
6. Deletion must be representable as a syncable state when cloud synchronization is required.
7. Monetary calculations use `double` consistently for the current application; a decimal/money value object can replace this later without changing presentation code.
8. Product group pricing is a line-pricing rule. The product's real unit price remains unchanged.
9. Import/export formats are adapters, not business logic.
10. New code should use package imports and the feature entry point where available.

## Persistence boundary

The intended runtime flow is:

`Widget -> Provider -> Use Case -> Repository -> DataSource -> Local/Remote storage`

The current repository/data-source abstractions are deliberately database-agnostic. Do not add a database SDK to a Provider.

## Migration policy

Do not move every file merely to make the tree look clean. Migrate by responsibility, keep compatibility exports when useful, and remove them only after all callers use the new boundary.
