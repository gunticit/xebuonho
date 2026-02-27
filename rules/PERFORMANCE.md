# ⚡ Performance Rules

## Latency Budgets

| Operation | Target | Max |
|-----------|--------|-----|
| API response (p50) | < 50ms | 200ms |
| API response (p99) | < 200ms | 500ms |
| Redis GEO query | < 1ms | 5ms |
| gRPC service-to-service | < 10ms | 50ms |
| MQTT message delivery | < 100ms | 500ms |
| WebSocket push | < 50ms | 200ms |
| DB query (simple) | < 5ms | 20ms |
| DB query (complex/geo) | < 20ms | 100ms |

## Database Performance

```sql
-- ✅ RULE: Always use indexes for WHERE clauses
-- ✅ RULE: Use EXPLAIN ANALYZE for new queries
-- ✅ RULE: Limit result sets (no SELECT * without LIMIT)
-- ✅ RULE: Use connection pooling (PgBouncer, max 20 connections)
-- ✅ RULE: Partition large tables by date (rides, payments)

-- Table partitioning for rides (by month)
CREATE TABLE rides (
    id UUID,
    created_at TIMESTAMPTZ,
    -- ...
) PARTITION BY RANGE (created_at);

CREATE TABLE rides_2025_01 PARTITION OF rides
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

## Caching Strategy

```
┌────────────────────────────────────────┐
│ Cache Layer           TTL    Hit Rate  │
├────────────────────────────────────────┤
│ L1: In-process       1min   > 80%     │
│ L2: Redis            5min   > 60%     │
│ L3: PostgreSQL       -      -         │
└────────────────────────────────────────┘

Cache invalidation: Write-through + TTL
```

## Monitoring & Alerting

| Metric | Tool | Alert |
|--------|------|-------|
| API latency p99 | Prometheus + Grafana | > 500ms |
| Error rate | Prometheus | > 1% |
| Redis memory | Redis INFO | > 80% |
| Kafka consumer lag | Kafka metrics | > 10k messages |
| PostgreSQL connections | pg_stat | > 80% pool |
| MQTT connected clients | EMQX dashboard | Drop > 20% |

## Load Testing Requirements

```bash
# Tool: k6 or Vegeta
# Target: 10,000 concurrent rides
# Scenario: Rush hour simulation
#   - 5,000 ride requests/minute
#   - 20,000 location updates/second
#   - 500 concurrent WebSocket connections
```
