# Event-Driven Choreography Architecture POC (Spring Boot 3 + RabbitMQ + Docker Compose)

This Proof of Concept (POC) demonstrates an **Event-Driven Choreography** architecture designed to:
1. **Eliminate Synchronous Tight Coupling**: Order Service accepts orders and emits events without waiting for downstream microservices.
2. **Prevent Order Timeouts**: Slow payment processing (e.g., 500ms latency) does not block API response times (Order API responds with HTTP 202 Accepted in ~13ms).
3. **Automatic Retries via Dead Letter Queue (DLQ)**: Failed payment processing attempts trigger an automatic 5-second backoff retry loop via RabbitMQ TTL + DLQ dead-lettering back to `shop.exchange`.

---

## Simulation Architecture & Concept

| Simulation Pillar | Mechanism & Behavior | Architectural Proof |
| :--- | :--- | :--- |
| **1. The Spike (Peak Shaving)** | A concurrency blast of **1,000 HTTP POST requests** in ~3 seconds against the Order Service. | Order Service accepts all requests instantly without dropping connections or crashing under load. |
| **2. The Bottleneck (Decoupling)** | The Payment Service simulates a **500ms mandatory pause** on every request (simulating a slow 3rd-party payment gateway). | In a synchronous system, this would cause HTTP timeouts and thread exhaustion. Here, the Order Service responds with **HTTP 202 Accepted in ~13ms avg**, while RabbitMQ safely buffers the backlog. |
| **3. The Failure (DLQ & Retries)** | The Payment Service simulates a **30% random failure rate**, throwing `AmqpRejectAndDontRequeueException`. | RabbitMQ moves failed messages to `payment.dlq`, holds them for **5000ms (TTL)**, and re-routes them to `shop.exchange` (`order.created`) for automatic infrastructure-managed retries. |

---

## Exchange & Queue Topology

```
                  ┌──────────────────────┐
                  │ POST /api/orders     │
                  │ (HTTP 202 Accepted)  │
                  └──────────┬───────────┘
                             │
                             ▼
                    [ Order Service ]
                             │
                    Publishes order.created
                             │
                             ▼
                    ┌─────────────────┐
                    │  shop.exchange  │ (Topic Exchange)
                    └────┬────────┬───┘
        order.created    │        │    order.created
            ┌────────────┘        └────────────┐
            ▼                                  ▼
┌───────────────────────┐          ┌───────────────────────┐
│inventory.reserve.queue│          │ payment.process.queue │
└───────────┬───────────┘          └───────────┬───────────┘
            │                                  │
            ▼                                  ▼
  [Inventory Service]                 [Payment Service]
  (Instant stock reserved)            - 500ms Simulated Latency
                                      - 30% Failure Rate
                                               │
                                               │ Throws AmqpRejectAndDontRequeueException
                                               ▼
                                      ┌─────────────────┐
                                      │   payment.dlq   │ (TTL: 5000ms)
                                      └────────┬────────┘
                                               │
                                               │ Expiration (5s backoff)
                                               │ Dead-letters back to shop.exchange
                                               └────────────────────────┐
                                                                        ▼
                                                             [shop.exchange (order.created)]
```

---

## Project Structure

```
.
├── docker-compose.yml
├── load-test.sh
├── load_test.py
├── order-service/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/main/java/com/example/orderservice/
│       ├── OrderServiceApplication.java
│       ├── config/RabbitMQConfig.java
│       ├── controller/OrderController.java
│       ├── dto/OrderRequest.java
│       └── event/OrderCreatedEvent.java
├── payment-service/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/main/java/com/example/paymentservice/
│       ├── PaymentServiceApplication.java
│       ├── config/RabbitMQConfig.java
│       ├── event/OrderCreatedEvent.java
│       └── listener/PaymentEventListener.java
└── inventory-service/
    ├── Dockerfile
    ├── pom.xml
    └── src/main/java/com/example/inventoryservice/
        ├── InventoryServiceApplication.java
        ├── config/RabbitMQConfig.java
        ├── event/OrderCreatedEvent.java
        └── listener/InventoryEventListener.java
```

---

## Simulation Results

### Load Test Output (`./load-test.sh`)

```text
================================================================================
⚡ EVENT-DRIVEN CHOREOGRAPHY POC: LOAD SIMULATION BENCHMARK
================================================================================
🎯 Target Endpoint   : POST http://localhost:8081/api/orders
📊 Total Volume      : 1000 HTTP POST requests
⚙️ Concurrency Level : 50 parallel workers
🧪 Simulation Goals  :
   1. Peak Shaving  : Ingest 1,000 requests rapidly without dropping connections
   2. Decoupling    : Return instant HTTP 202/200 while Payment buffers (500ms latency)
   3. DLQ & Retries : Payment 30% simulated failures automatically retry via DLQ
--------------------------------------------------------------------------------
🚀 Blasting requests...

================================================================================
📊 LOAD TEST SIMULATION METRICS
================================================================================
⏱️  Total Duration       : 3.2889s
🚀 Ingestion Throughput : 304.05 req/sec
📈 Success Rate (202)   : 100.00% (1000/1000)
❌ Failed / Other HTTP  : 0

🕒 Order Service API Latency Distribution (Client-Side):
   - Min Latency        : 2.67 ms
   - Avg Latency        : 13.60 ms
   - Max Latency        : 60.28 ms
--------------------------------------------------------------------------------
💡 SIMULATION INSIGHTS & ARCHITECTURAL PROOF:
 1. [Peak Shaving / Decoupling]: Order Service ingested 1000 orders in 3.2889s
    with an average response time of 13.60 ms despite downstream Payment Service
    having a mandatory 500ms delay per order. RabbitMQ buffered the load.
 2. [Asynchronous Processing]: Downstream services consume events independently.
 3. [DLQ Auto-Retries]: Check 'docker compose logs payment-service' to view ~30%
    simulated gateway failures dead-lettering to 'payment.dlq' for 5s backoff.
================================================================================
```

---

## Raw Log Evidence from Services

### 1. Order Service: Non-Blocking High-Throughput Ingestion
The Order Service accepted orders and published events to RabbitMQ in ~13ms:
```text
2026-09-29T08:50:30.281Z  INFO 1 --- [order-service] [nio-8081-exec-2] c.e.o.controller.OrderController         : Order received and order.created event published for Order: c202287d-30e6-4e7d-bf01-f177df258354
2026-09-29T08:50:30.285Z  INFO 1 --- [order-service] [nio-8081-exec-2] c.e.o.controller.OrderController         : Order received and order.created event published for Order: 1505a708-9919-4b7c-b594-953696823eb0
2026-09-29T08:50:30.286Z  INFO 1 --- [order-service] [nio-8081-exec-4] c.e.o.controller.OrderController         : Order received and order.created event published for Order: ae36d62e-164b-42b1-bf46-e72f851b00a8
2026-09-29T08:50:30.286Z  INFO 1 --- [order-service] [io-8081-exec-16] c.e.o.controller.OrderController         : Order received and order.created event published for Order: 417edafb-05f7-49fc-ba39-6167bb28a325
2026-09-29T08:50:30.290Z  INFO 1 --- [order-service] [io-8081-exec-20] c.e.o.controller.OrderController         : Order received and order.created event published for Order: 282f5eb5-f169-463e-9db4-16f381fb7254
```

### 2. Inventory Service: Instant Parallel Reservation
Inventory consumed the exact same `order.created` event independently:
```text
2026-09-29T08:26:20.908Z  INFO 1 --- [inventory-service] [ntContainer#0-2] c.e.i.listener.InventoryEventListener    : Stock reserved for Order: 817db57d-4f30-4ce1-8c37-87bea610d3e4
2026-09-29T08:27:42.310Z  INFO 1 --- [inventory-service] [ntContainer#0-2] c.e.i.listener.InventoryEventListener    : Stock reserved for Order: 31a042b7-0b78-430c-94b8-c47f42f9193a
2026-09-29T08:27:42.311Z  INFO 1 --- [inventory-service] [ntContainer#0-2] c.e.i.listener.InventoryEventListener    : Stock reserved for Order: 495f328e-d984-4230-9b34-005574aefa0b
```

### 3. Payment Service: Simulated 500ms Delay, 30% Failure, and DLQ Retry
Payment processed with simulated latency, triggered DLQ routing upon simulated failure, and succeeded upon redelivery:
```text
2026-09-29T08:51:04.202Z  INFO 1 --- [payment-service] [ntContainer#0-2] c.e.p.listener.PaymentEventListener      : Received payment processing event for Order: d7ac5a15-f054-4c8a-b6e1-b2bcb2f9a1e9
2026-09-29T08:51:04.702Z  INFO 1 --- [payment-service] [ntContainer#0-2] c.e.p.listener.PaymentEventListener      : Payment successful for Order: d7ac5a15-f054-4c8a-b6e1-b2bcb2f9a1e9
2026-09-29T08:51:06.205Z  INFO 1 --- [payment-service] [ntContainer#0-2] c.e.p.listener.PaymentEventListener      : Received payment processing event for Order: 693e7d51-9c4b-42f1-8019-704344e90a74
2026-09-29T08:51:06.705Z  WARN 1 --- [payment-service] [ntContainer#0-2] c.e.p.listener.PaymentEventListener      : [PAYMENT FAILURE] Payment gateway timeout/error for Order: 693e7d51-9c4b-42f1-8019-704344e90a74. Sending to DLQ for retry.
2026-09-29T08:51:06.705Z  WARN 1 --- [payment-service] [ntContainer#0-2] s.a.r.l.ConditionalRejectingErrorHandler : Execution of Rabbit message listener failed.
Caused by: org.springframework.amqp.AmqpRejectAndDontRequeueException: Simulated payment failure (30% failure rate)
	at com.example.paymentservice.listener.PaymentEventListener.processPayment(PaymentEventListener.java:26)
```

---

## Simulation Disclaimer & Limitations

> [!NOTE]
> **Localhost POC & Happy Path Context**:
> This test is an isolated localhost simulation designed to demonstrate the mechanical guarantees of AMQP Topic Exchanges, Buffer Queues, and Dead Letter Exchange TTL routing.
> - **Idempotency**: In a production environment, consumers should maintain idempotent deduplication (e.g. tracking processed `orderId` in Redis/DB) because infinite retries can cause duplicated processing if not guarded.
> - **Poison Pill Handling**: For production resilience, infinite DLQ loops are typically capped with a `max-retry-count` header before routing to a Parking Lot Queue for manual inspection.

---

## Running the Stack

```bash
# Start all containers
docker compose up -d --build

# Run the simulation benchmark
./load-test.sh

# Observe logs in real time
docker compose logs -f payment-service
```

## Contact
This is the poc to the exercise, this property is owned by:
Nguyen Thien An