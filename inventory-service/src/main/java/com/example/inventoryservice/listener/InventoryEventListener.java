package com.example.inventoryservice.listener;

import com.example.inventoryservice.config.RabbitMQConfig;
import com.example.inventoryservice.event.OrderCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class InventoryEventListener {

    private static final Logger log = LoggerFactory.getLogger(InventoryEventListener.class);

    @RabbitListener(queues = RabbitMQConfig.INVENTORY_RESERVE_QUEUE)
    public void processInventory(OrderCreatedEvent event) {
        log.info("Stock reserved for Order: {}", event.getOrderId());
    }
}
