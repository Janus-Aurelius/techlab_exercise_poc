package com.example.paymentservice.listener;

import com.example.paymentservice.config.RabbitMQConfig;
import com.example.paymentservice.event.OrderCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.AmqpRejectAndDontRequeueException;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class PaymentEventListener {

    private static final Logger log = LoggerFactory.getLogger(PaymentEventListener.class);

    @RabbitListener(queues = RabbitMQConfig.PAYMENT_PROCESS_QUEUE)
    public void processPayment(OrderCreatedEvent event) throws InterruptedException {
        log.info("Received payment processing event for Order: {}", event.getOrderId());

        // Simulate 500ms latency for third-party payment gateway call
        Thread.sleep(500);

        // Simulate 30% failure rate
        if (Math.random() < 0.30) {
            log.warn("[PAYMENT FAILURE] Payment gateway timeout/error for Order: {}. Sending to DLQ for retry.", event.getOrderId());
            throw new AmqpRejectAndDontRequeueException("Simulated payment failure (30% failure rate)");
        }

        log.info("Payment successful for Order: {}", event.getOrderId());
    }
}
