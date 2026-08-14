# SF6-Rating Feature Specifications

Status: Reviewed

## Source of Truth

When documents overlap, use this order: the most specific Feature Spec, then
`docs/architecture.md`, then `docs/product-spec.md`. Cross-feature invariants
defined in this index apply to every Feature Spec; a local document must not
redefine them incompatibly. Implementation plans and code are downstream of
these specifications.

## Feature Specs

| Feature | Specification | Primary responsibility |
| --- | --- | --- |
| Account / Profile | [account-profile.md](./account-profile.md) | Identity, onboarding, account lifecycle |
| Matchmaking / Waiting Pool | [matchmaking.md](./matchmaking.md) | Availability, matching eligibility, rated cooldown |
| Match Room | [match-room.md](./match-room.md) | Confirmed match room and lifecycle UX |
| FT3 Match | [ft3-match.md](./ft3-match.md) | First-to-three rules, forfeit, completion incidents |
| Result Reporting | [result-reporting.md](./result-reporting.md) | Blind reports, confirmation, mismatch, rated gate |
| Rating System | [rating-system.md](./rating-system.md) | Rating calculation, application, correction |
| Placement | [placement.md](./placement.md) | Initial rating and first ten rated matches |
| Public Profile | [public-profile.md](./public-profile.md) | Public identity, current stats, public history |
| Ranking | [ranking.md](./ranking.md) | Active-season ranking and ties |
| Seasons | [seasons.md](./seasons.md) | Rollover, snapshots, cutoff, soft reset |
| Admin / Dispute | [admin-dispute.md](./admin-dispute.md) | Dispute resolution, incidents, restrictions, audit |

## Cross-feature relationships

- Matchmaking creates a Match; Match Room and FT3 govern play; Result Reporting finalizes it.
- Rating System and active `season_player_records` update in the same domain transaction after a rated result is confirmed.
- Seasons freezes completed-season records; Ranking and Public Profile read those records according to season state.
- Admin / Dispute may resolve or invalidate a Match only through audited domain actions.

## Canonical match terminology

- `status`: `matched | room_setup | reporting | disputed | completed | cancelled`
- `resolution_type`: `normal | forfeit | admin_result | mutual_cancel | nonresponse_no_rating | mutual_no_rating | admin_invalid_no_rating | season_boundary_no_rating`
- `result_validity`: `valid | invalidated` for a result-bearing completed Match
- `rating_status`: `not_applicable | pending | applied | correction_pending | corrected`

`completed` always means a formal winner and loser exist. `cancelled` always
means the Match ended without a winner and without Rating. UI conditions and
resolution causes are never additional Match statuses.
