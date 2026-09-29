#!/usr/bin/env python3
"""
Load Test Script for Event-Driven Choreography POC
Sends 1,000 HTTP POST requests to the Order Service (http://localhost:8081/api/orders) in parallel within ~1 second.
Uses Python standard library (urllib + concurrent.futures) - no external packages required.
"""

import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.request
import urllib.error

URL = "http://localhost:8081/api/orders"
TOTAL_REQUESTS = 1000
CONCURRENCY = 100

PAYLOAD = json.dumps({
    "userId": "usr_999",
    "productId": "prod_ABC",
    "amount": 100
}).encode("utf-8")

HEADERS = {
    "Content-Type": "application/json"
}

def send_request(req_id):
    req = urllib.request.Request(URL, data=PAYLOAD, headers=HEADERS, method="POST")
    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            latency = (time.time() - start_time) * 1000
            return response.status, latency
    except urllib.error.HTTPError as e:
        latency = (time.time() - start_time) * 1000
        return e.code, latency
    except Exception as e:
        latency = (time.time() - start_time) * 1000
        return 500, latency

def main():
    print(f"🚀 Starting load test: Blasting {TOTAL_REQUESTS} requests to {URL} with concurrency {CONCURRENCY}...")
    start_total = time.time()

    status_counts = {}
    latencies = []

    with ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
        futures = [executor.submit(send_request, i) for i in range(TOTAL_REQUESTS)]
        for future in as_completed(futures):
            status, latency = future.result()
            status_counts[status] = status_counts.get(status, 0) + 1
            latencies.append(latency)

    elapsed_total = time.time() - start_total
    rps = TOTAL_REQUESTS / elapsed_total if elapsed_total > 0 else 0
    avg_latency = sum(latencies) / len(latencies) if latencies else 0

    print("\n--- Load Test Results ---")
    print(f"Total Time Taken : {elapsed_total:.2f} seconds")
    print(f"Throughput       : {rps:.2f} req/sec")
    print(f"Average Latency  : {avg_latency:.2f} ms")
    print("Status Codes     :")
    for code, count in status_counts.items():
        print(f"  HTTP {code}: {count}")

if __name__ == "__main__":
    main()
