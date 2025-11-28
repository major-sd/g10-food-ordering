package com.foodorder.payment.repository;

import com.foodorder.payment.model.PaymentRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentRepository extends JpaRepository<PaymentRecord, Long> {
}

