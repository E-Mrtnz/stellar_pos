# STELLAR POS architecture

## Goal

Keep presentation, business rules, and persistence independent so local storage and a future cloud backend can be introduced without rewriting the POS.

## Dependency direction

`presentation -> application/state -> domain -> data -> infrastructure`

UI widgets must not know about Hive, SQLite, Firebase, Supabase, HTTP clients, or storage SDKs. Providers coordinate UI/application state and delegate business operations to domain services/use cases. Repositories are contracts; data sources implement persistence.

## Feature boundaries

The application is organized around these capabilities:

- `features/products`
- `features/inventory`
- `features/sales`
- `features/purchases`
- `features/clients`
- `features/debts`
- `features/electronic_balance`
- `features/catalog`
- `features/settings`

Small compatibility entry points may remain during migration. A feature can grow into `data/`, `domain/`, and `presentation/` once it has enough complexity to justify the additional boundaries.

## Core rules

1. Business rules belong in pure domain services/use cases.
2. Providers own application/UI state, not persistence implementation.
3. Repositories hide the persistence technology.
4. Data sources perform serialization and storage operations.
5. Persisted entities use stable IDs and sync metadata where applicable.
6. Deletion must be representable as a syncable state when cloud synchronization is required.
7. Product group pricing is a line-pricing rule. The product's real unit price remains unchanged.
8. Inventory stock changes are domain operations; UI code must not calculate stock mutations itself.
9. Import/export formats are adapters, not business rules.
10. Monetary/date/string formatting belongs outside domain entities.
11. Electronic-balance validation and commission calculations belong to domain services.
12. Public ticket numbers and internal entity IDs are different concepts.

## Current domain services

- `ProductPricingService`: group pricing and product profitability rules.
- `SaleTotalsService`: line subtotal, proportional discount, and sale total calculations.
- `InventoryStockService`: stock increase/decrease, sellability, low-stock, and maximum-stock rules.
- `ElectronicBalanceService`: valid categories, provider cost/profit calculations, and configured amount validation.
- `SaleIdentityService`: generates stable internal sale IDs independently from ticket numbers.

## Catalog modeling decision

Products currently expose catalog values through the existing UI-compatible fields. The persistence model should eventually represent **category, brand, and distributor as entities with stable IDs**, while retaining display names as denormalized snapshots where useful for historical records.

This migration should happen before cloud synchronization, but not by silently changing existing UI contracts. The intended relationships are:

`Product -> CategoryId / BrandId / DistributorId`

and historical sale/purchase lines keep the descriptive snapshot required to display past transactions even if the catalog entry is renamed later.

## Persistence boundary

The intended runtime flow is:

`Widget -> Provider -> Domain operation -> Repository -> DataSource -> Local/Remote storage`

The repository/data-source abstractions are database-agnostic. A database SDK must never be added directly to a Provider.

## Migration policy

Do not move every file merely to make the tree look clean. Migrate by responsibility, preserve behavior, and remove compatibility layers only after all callers use the new boundary.

Before introducing the database, the remaining high-risk application logic should be extracted from the large Providers, especially sales lifecycle, stock mutations, and electronic-balance coordination. The database should then implement the repository contracts rather than forcing another architecture rewrite.
