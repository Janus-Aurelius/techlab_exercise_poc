package com.example.orderservice.dto;

import java.math.BigDecimal;

public class OrderRequest {
    private String userId;
    private String productId;
    private BigDecimal amount;

    public OrderRequest() {
    }

    public OrderRequest(String userId, String productId, BigDecimal amount) {
        this.userId = userId;
        this.productId = productId;
        this.amount = amount;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getProductId() {
        return productId;
    }

    public void setProductId(String productId) {
        this.productId = productId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }
}
