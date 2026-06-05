/*
 * Copyright 2020, Google LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.circleci.samples.bankcorp.ledgerwriter;

import static com.circleci.samples.bankcorp.ledgerwriter.ExceptionMessages.EXCEPTION_MESSAGE_INSUFFICIENT_BALANCE;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.interfaces.Claim;
import com.auth0.jwt.interfaces.DecodedJWT;
import io.micrometer.core.instrument.Clock;
import io.micrometer.core.lang.Nullable;
import io.micrometer.stackdriver.StackdriverConfig;
import io.micrometer.stackdriver.StackdriverMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

class TransactionValidationIT {

    private static final String VERSION = "v0.1.0";
    private static final String LOCAL_ROUTING_NUM = "123456789";
    private static final String BALANCES_API_URI =
            "http://balancereader:8080/balances";
    private static final String AUTHED_ACCOUNT_NUM = "1234567890";
    private static final String TO_ACCOUNT_NUM = "5678901234";
    private static final String TO_ROUTING_NUM = "567891234";
    private static final String BEARER_TOKEN = "Bearer abc";
    private static final String TOKEN = "abc";
    private static final int SENDER_BALANCE = 40;
    private static final int OVERDRAFT_AMOUNT = 1000;
    private static final int FALLBACK_BALANCE = 5000;

    private LedgerWriterController ledgerWriterController;
    private RestTemplate restTemplate;
    private Transaction transaction;

    @BeforeEach
    void setUp() {
        JWTVerifier verifier = mock(JWTVerifier.class);
        DecodedJWT jwt = mock(DecodedJWT.class);
        Claim claim = mock(Claim.class);
        TransactionRepository transactionRepository =
                mock(TransactionRepository.class);
        TransactionValidator transactionValidator = new TransactionValidator();
        Clock clock = mock(Clock.class);
        StackdriverMeterRegistry meterRegistry =
                new StackdriverMeterRegistry(new StackdriverConfig() {
                    @Override
                    public boolean enabled() {
                        return false;
                    }

                    @Override
                    public String projectId() {
                        return "test";
                    }

                    @Override
                    @Nullable
                    public String get(String key) {
                        return null;
                    }
                }, clock);

        ledgerWriterController = new LedgerWriterController(verifier,
                meterRegistry,
                transactionRepository, transactionValidator,
                LOCAL_ROUTING_NUM, BALANCES_API_URI, VERSION);
        restTemplate = mock(RestTemplate.class);
        ledgerWriterController.restTemplate = restTemplate;

        when(verifier.verify(TOKEN)).thenReturn(jwt);
        when(jwt.getClaim(LedgerWriterController.JWT_ACCOUNT_KEY))
                .thenReturn(claim);
        when(claim.asString()).thenReturn(AUTHED_ACCOUNT_NUM);

        transaction = mock(Transaction.class);
        when(transaction.getFromAccountNum()).thenReturn(AUTHED_ACCOUNT_NUM);
        when(transaction.getFromRoutingNum()).thenReturn(LOCAL_ROUTING_NUM);
        when(transaction.getToAccountNum()).thenReturn(TO_ACCOUNT_NUM);
        when(transaction.getToRoutingNum()).thenReturn(TO_ROUTING_NUM);
        when(transaction.getAmount()).thenReturn(OVERDRAFT_AMOUNT);
        when(transaction.getRequestUuid())
                .thenReturn("insufficient-funds-demo");

        when(restTemplate.exchange(anyString(), eq(HttpMethod.GET),
                any(HttpEntity.class), eq(Integer.class)))
                .thenReturn(new ResponseEntity<Integer>(
                        FALLBACK_BALANCE, HttpStatus.OK));
        when(restTemplate.exchange(eq(BALANCES_API_URI + "/"
                        + AUTHED_ACCOUNT_NUM), eq(HttpMethod.GET),
                any(HttpEntity.class), eq(Integer.class)))
                .thenReturn(new ResponseEntity<Integer>(
                        SENDER_BALANCE, HttpStatus.OK));
    }

    @Test
    @DisplayName("TransactionValidationTest.testInsufficientFunds")
    void testInsufficientFunds() {
        ResponseEntity actualResult =
                ledgerWriterController.addTransaction(BEARER_TOKEN,
                        transaction);

        assertNotNull(actualResult);
        assertEquals(HttpStatus.BAD_REQUEST, actualResult.getStatusCode(),
                "expected an overdraft to be DECLINED, but the transaction "
                        + "was APPROVED");
        assertEquals(EXCEPTION_MESSAGE_INSUFFICIENT_BALANCE,
                actualResult.getBody());
    }
}
