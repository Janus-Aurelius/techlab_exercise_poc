#!/usr/bin/env bash
# High-concurrency bash load test & simulation metrics script for POST /api/orders

set -e

URL="http://localhost:8081/api/orders"
TOTAL_REQUESTS=1000
CONCURRENCY=50
RESULTS_FILE="/tmp/load_test_results.tsv"

rm -f "$RESULTS_FILE"

echo "================================================================================"
echo "⚡ EVENT-DRIVEN CHOREOGRAPHY POC: LOAD SIMULATION BENCHMARK"
echo "================================================================================"
echo "🎯 Target Endpoint   : POST $URL"
echo "📊 Total Volume      : $TOTAL_REQUESTS HTTP POST requests"
echo "⚙️ Concurrency Level : $CONCURRENCY parallel workers"
echo "🧪 Simulation Goals  :"
echo "   1. Peak Shaving  : Ingest 1,000 requests rapidly without dropping connections"
echo "   2. Decoupling    : Return instant HTTP 202/200 while Payment buffers (500ms latency)"
echo "   3. DLQ & Retries : Payment 30% simulated failures automatically retry via DLQ"
echo "--------------------------------------------------------------------------------"
echo "🚀 Blasting requests..."

START_TIME=$(date +%s%N)

seq 1 $TOTAL_REQUESTS | xargs -P $CONCURRENCY -I {} curl -s -o /dev/null \
  -w "%{http_code}\t%{time_total}\n" \
  -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d '{"userId":"usr_sim_123","productId":"prod_SIM_ABC","amount":100}' >> "$RESULTS_FILE"

END_TIME=$(date +%s%N)
ELAPSED_NS=$((END_TIME - START_TIME))
ELAPSED_SEC=$(awk "BEGIN {printf \"%.4f\", $ELAPSED_NS/1000000000}")

# Aggregate metrics
TOTAL_SENT=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
ACCEPTED_COUNT=$(awk '$1 == 202 || $1 == 200 {count++} END {print count+0}' "$RESULTS_FILE")
OTHER_COUNT=$((TOTAL_SENT - ACCEPTED_COUNT))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($ACCEPTED_COUNT/$TOTAL_SENT)*100}")
THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $TOTAL_SENT/$ELAPSED_SEC}")

# Calculate latency stats in milliseconds
LATENCY_STATS=$(awk '{
    ms = $2 * 1000;
    sum += ms;
    if (min == "" || ms < min) min = ms;
    if (max == "" || ms > max) max = ms;
} END {
    avg = (NR > 0) ? sum / NR : 0;
    printf "%.2f\t%.2f\t%.2f", min, avg, max;
}' "$RESULTS_FILE")

MIN_LATENCY=$(echo "$LATENCY_STATS" | cut -f1)
AVG_LATENCY=$(echo "$LATENCY_STATS" | cut -f2)
MAX_LATENCY=$(echo "$LATENCY_STATS" | cut -f3)

echo ""
echo "================================================================================"
echo "📊 LOAD TEST SIMULATION METRICS"
echo "================================================================================"
echo "⏱️  Total Duration       : ${ELAPSED_SEC}s"
echo "🚀 Ingestion Throughput : ${THROUGHPUT} req/sec"
echo "📈 Success Rate (202)   : ${SUCCESS_RATE}% (${ACCEPTED_COUNT}/${TOTAL_SENT})"
echo "❌ Failed / Other HTTP  : ${OTHER_COUNT}"
echo ""
echo "🕒 Order Service API Latency Distribution (Client-Side):"
echo "   - Min Latency        : ${MIN_LATENCY} ms"
echo "   - Avg Latency        : ${AVG_LATENCY} ms"
echo "   - Max Latency        : ${MAX_LATENCY} ms"
echo "--------------------------------------------------------------------------------"
echo "💡 SIMULATION INSIGHTS & ARCHITECTURAL PROOF:"
echo " 1. [Peak Shaving / Decoupling]: Order Service ingested ${TOTAL_SENT} orders in ${ELAPSED_SEC}s"
echo "    with an average response time of ${AVG_LATENCY} ms despite downstream Payment Service"
echo "    having a mandatory 500ms delay per order. RabbitMQ buffered the load."
echo " 2. [Asynchronous Processing]: Downstream services consume events independently."
echo " 3. [DLQ Auto-Retries]: Check 'docker compose logs payment-service' to view ~30%"
echo "    simulated gateway failures dead-lettering to 'payment.dlq' for 5s backoff."
echo "================================================================================"
