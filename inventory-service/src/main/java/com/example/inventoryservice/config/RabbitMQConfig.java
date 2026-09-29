package com.example.inventoryservice.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE_NAME = "shop.exchange";
    public static final String ROUTING_KEY_ORDER_CREATED = "order.created";
    public static final String INVENTORY_RESERVE_QUEUE = "inventory.reserve.queue";

    @Bean
    public TopicExchange shopExchange() {
        return new TopicExchange(EXCHANGE_NAME, true, false);
    }

    @Bean
    public Queue inventoryReserveQueue() {
        return QueueBuilder.durable(INVENTORY_RESERVE_QUEUE).build();
    }

    @Bean
    public Binding inventoryReserveBinding(Queue inventoryReserveQueue, TopicExchange shopExchange) {
        return BindingBuilder.bind(inventoryReserveQueue).to(shopExchange).with(ROUTING_KEY_ORDER_CREATED);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}
