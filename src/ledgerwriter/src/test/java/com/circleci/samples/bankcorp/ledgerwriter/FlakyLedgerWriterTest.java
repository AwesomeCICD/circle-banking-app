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

package anthos.samples.bankofanthos.ledgerwriter;

import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.interfaces.Claim;
import com.auth0.jwt.interfaces.DecodedJWT;
import io.micrometer.core.instrument.Clock;
import io.micrometer.stackdriver.StackdriverConfig;
import io.micrometer.stackdriver.StackdriverMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.lang.Nullable;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.MockitoAnnotations.initMocks;

/**
 * Flaky tests for LedgerWriter to demonstrate various flakiness patterns
 */
class FlakyLedgerWriterTest {

    @Mock
    private TransactionRepository transactionRepository;
    @Mock
    private TransactionValidator transactionValidator;
    @Mock
    private JWTVerifier verifier;
    @Mock
    private DecodedJWT jwt;
    @Mock
    private Claim claim;
    @Mock
    private Clock clock;

    private LedgerWriterController ledgerWriterController;
    private static final Random random = new Random();
    private static final String VERSION = "v0.1.0";
    private static final String LOCAL_ROUTING_NUM = "123456789";
    private static final String BALANCES_API_ADDR = "balancereader:8080";

    @BeforeEach
    void setUp() {
        initMocks(this);
        StackdriverMeterRegistry meterRegistry = new StackdriverMeterRegistry(new StackdriverConfig() {
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
                LOCAL_ROUTING_NUM, BALANCES_API_ADDR, VERSION);
    }

    @Test
    @DisplayName("Test that fails based on transaction ordering")
    void testTransactionOrderDependentBehavior() {
        List<Transaction> transactions = new ArrayList<>();
        
        // Create transactions with random ordering
        for (int i = 0; i < random.nextInt(20) + 10; i++) {
            Transaction tx = new Transaction();
            tx.setTransactionId(UUID.randomUUID().toString());
            tx.setFromAccountNum("1234567890");
            tx.setToAccountNum("0987654321");
            tx.setAmount(new BigDecimal(random.nextDouble() * 1000));
            tx.setTimestamp(Instant.now().plusSeconds(random.nextInt(3600)));
            transactions.add(tx);
        }

        // Shuffle transactions - some orders might fail validation
        Collections.shuffle(transactions);

        // Process transactions in random order
        BigDecimal runningBalance = BigDecimal.ZERO;
        for (Transaction tx : transactions) {
            runningBalance = runningBalance.add(tx.getAmount());
            
            // This check will be flaky based on transaction order (85% failure)
            if ((runningBalance.compareTo(BigDecimal.valueOf(5000)) > 0) || random.nextDouble() < 0.85) {
                fail("Transaction order caused balance overflow: " + runningBalance);
            }
        }
    }

    @Test
    @DisplayName("Test with database deadlock simulation")
    void testDatabaseDeadlockScenario() throws InterruptedException {
        AtomicInteger deadlockCount = new AtomicInteger(0);
        List<String> errors = Collections.synchronizedList(new ArrayList<>());

        Runnable transactionWriter = () -> {
            try {
                // Simulate database operations that might deadlock
                String accountA = "account_" + (random.nextInt(5) + 1);
                String accountB = "account_" + (random.nextInt(5) + 1);
                
                // Random delay to increase deadlock probability
                Thread.sleep(random.nextInt(50));
                
                Transaction tx = new Transaction();
                tx.setTransactionId(UUID.randomUUID().toString());
                tx.setFromAccountNum(accountA);
                tx.setToAccountNum(accountB);
                tx.setAmount(BigDecimal.valueOf(random.nextDouble() * 100));

                // Simulate deadlock detection
                if (random.nextDouble() < 0.75) { // 75% chance of deadlock
                    deadlockCount.incrementAndGet();
                    throw new DataAccessResourceFailureException("Deadlock detected");
                }
                
                when(transactionRepository.save(tx)).thenReturn(tx);
                
            } catch (Exception e) {
                errors.add("Database error: " + e.getMessage());
            }
        };

        // Run multiple threads to create potential deadlocks
        ExecutorService executor = Executors.newFixedThreadPool(10);
        for (int i = 0; i < 50; i++) {
            executor.submit(transactionWriter);
        }
        
        executor.shutdown();
        executor.awaitTermination(10, TimeUnit.SECONDS);

        if (deadlockCount.get() > 2 || random.nextDouble() < 0.8) {
            fail("Too many deadlocks detected: " + deadlockCount.get());
        }
        
        if (!errors.isEmpty() && errors.size() > 3) {
            fail("Multiple database errors: " + errors.get(0));
        }
    }

    @Test
    @DisplayName("Test with currency precision edge cases")
    void testCurrencyPrecisionEdgeCases() {
        // Test various precision scenarios that might fail
        BigDecimal[] testAmounts = {
            new BigDecimal("0.001"),    // Sub-cent precision
            new BigDecimal("999999.999"), // Large amount with precision
            new BigDecimal("1").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP), // Repeating decimal
            new BigDecimal("0.1").add(new BigDecimal("0.2")), // Classic float precision issue
        };

        for (BigDecimal amount : testAmounts) {
            Transaction tx = new Transaction();
            tx.setTransactionId(UUID.randomUUID().toString());
            tx.setFromAccountNum("1234567890");
            tx.setToAccountNum("0987654321");
            tx.setAmount(amount);

            // Precision validation that might be flaky
            BigDecimal scaledAmount = amount.setScale(2, RoundingMode.HALF_UP);
            if (!amount.equals(scaledAmount) && amount.scale() > 2) {
                fail("Precision loss detected for amount: " + amount + " -> " + scaledAmount);
            }
        }
    }

    @Test
    @DisplayName("Test with time zone dependent behavior")
    void testTimeZoneDependentTransactionProcessing() {
        // Get current time in different time zones
        Instant now = Instant.now();
        ZoneOffset[] zones = {
            ZoneOffset.UTC,
            ZoneOffset.of("-05:00"), // EST
            ZoneOffset.of("+09:00"), // JST
            ZoneOffset.of("+01:00"), // CET
        };

        for (ZoneOffset zone : zones) {
            int hourOfDay = now.atOffset(zone).getHour();
            
            // Business logic that depends on time zone
            if (hourOfDay < 6 || hourOfDay > 22) {
                fail("Transactions not allowed during off-hours in timezone " + zone + " (hour: " + hourOfDay + ")");
            }
        }

        Transaction tx = new Transaction();
        tx.setTransactionId(UUID.randomUUID().toString());
        tx.setFromAccountNum("1234567890");
        tx.setToAccountNum("0987654321");
        tx.setAmount(BigDecimal.valueOf(100.00));
        tx.setTimestamp(now);

        when(transactionRepository.save(tx)).thenReturn(tx);
    }

    @Test
    @DisplayName("Test with garbage collection interference")
    void testGarbageCollectionInterference() {
        List<Object> memoryPressure = new ArrayList<>();
        
        try {
            // Create memory pressure to trigger GC
            for (int i = 0; i < random.nextInt(10000) + 5000; i++) {
                memoryPressure.add(new byte[random.nextInt(1000) + 100]);
                
                // Occasionally trigger GC explicitly
                if (i % 1000 == 0) {
                    System.gc();
                    
                    // Measure time sensitive operations during GC
                    long startTime = System.nanoTime();
                    
                    Transaction tx = new Transaction();
                    tx.setTransactionId("tx_" + i);
                    tx.setFromAccountNum("1234567890");
                    tx.setToAccountNum("0987654321");
                    tx.setAmount(BigDecimal.valueOf(i));
                    
                    long elapsedTime = System.nanoTime() - startTime;
                    
                    // This might fail during GC pauses
                    if (elapsedTime > 50_000_000) { // 50ms threshold
                        fail("Transaction processing too slow during GC: " + elapsedTime + "ns");
                    }
                }
            }
        } finally {
            memoryPressure.clear();
        }
    }

    @Test
    @DisplayName("Test with connection pool exhaustion")
    void testConnectionPoolExhaustion() throws InterruptedException {
        AtomicLong activeConnections = new AtomicLong(0);
        final long MAX_CONNECTIONS = 20;
        List<String> connectionErrors = Collections.synchronizedList(new ArrayList<>());

        Runnable databaseOperation = () -> {
            try {
                long currentConnections = activeConnections.incrementAndGet();
                
                if (currentConnections > MAX_CONNECTIONS) {
                    connectionErrors.add("Connection pool exhausted: " + currentConnections + " active connections");
                    return;
                }

                // Simulate database work
                Thread.sleep(random.nextInt(100) + 50);
                
                Transaction tx = new Transaction();
                tx.setTransactionId(UUID.randomUUID().toString());
                tx.setFromAccountNum("1234567890");
                tx.setToAccountNum("0987654321");
                tx.setAmount(BigDecimal.valueOf(random.nextDouble() * 100));

                when(transactionRepository.save(tx)).thenReturn(tx);
                
            } catch (Exception e) {
                connectionErrors.add("Database connection error: " + e.getMessage());
            } finally {
                activeConnections.decrementAndGet();
            }
        };

        // Simulate high load
        ExecutorService executor = Executors.newFixedThreadPool(50);
        for (int i = 0; i < 100; i++) {
            executor.submit(databaseOperation);
        }
        
        executor.shutdown();
        executor.awaitTermination(15, TimeUnit.SECONDS);

        if (!connectionErrors.isEmpty()) {
            fail("Connection pool issues: " + connectionErrors.get(0));
        }
    }

    @Test
    @DisplayName("Test with duplicate transaction ID race condition")
    void testDuplicateTransactionIdRaceCondition() throws InterruptedException {
        Set<String> usedIds = Collections.synchronizedSet(new HashSet<>());
        List<String> duplicateErrors = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger transactionCounter = new AtomicInteger(0);

        Runnable transactionCreator = () -> {
            try {
                // Simulate transaction ID generation with potential conflicts
                int counter = transactionCounter.incrementAndGet();
                String baseId = "tx_" + (counter / 10); // Intentionally create potential duplicates
                
                // Add some randomness
                String transactionId = baseId + "_" + random.nextInt(3);
                
                if (!usedIds.add(transactionId)) {
                    duplicateErrors.add("Duplicate transaction ID detected: " + transactionId);
                    return;
                }

                Transaction tx = new Transaction();
                tx.setTransactionId(transactionId);
                tx.setFromAccountNum("1234567890");
                tx.setToAccountNum("0987654321");
                tx.setAmount(BigDecimal.valueOf(random.nextDouble() * 100));

                when(transactionRepository.save(tx)).thenReturn(tx);
                
            } catch (Exception e) {
                duplicateErrors.add("Transaction creation error: " + e.getMessage());
            }
        };

        // Run many concurrent transaction creations
        ExecutorService executor = Executors.newFixedThreadPool(20);
        for (int i = 0; i < 200; i++) {
            executor.submit(transactionCreator);
        }
        
        executor.shutdown();
        executor.awaitTermination(10, TimeUnit.SECONDS);

        if (!duplicateErrors.isEmpty()) {
            fail("Duplicate transaction ID issues: " + duplicateErrors.get(0));
        }
    }

    @Test
    @DisplayName("Test with network partition simulation")
    void testNetworkPartitionBehavior() {
        List<CompletableFuture<Boolean>> networkCalls = new ArrayList<>();
        int partitionProbability = random.nextInt(30) + 10; // 10-40% partition chance

        for (int i = 0; i < 10; i++) {
            CompletableFuture<Boolean> networkCall = CompletableFuture.supplyAsync(() -> {
                try {
                    // Simulate network call with potential partition
                    if (random.nextInt(100) < partitionProbability) {
                        throw new RuntimeException("Network partition detected");
                    }
                    
                    Thread.sleep(random.nextInt(100) + 50);
                    return true;
                } catch (Exception e) {
                    return false;
                }
            });
            networkCalls.add(networkCall);
        }

        // Wait for all network calls to complete
        long successfulCalls = networkCalls.stream()
                .mapToLong(future -> {
                    try {
                        return future.get(2, TimeUnit.SECONDS) ? 1 : 0;
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .sum();

        double successRate = (double) successfulCalls / networkCalls.size();
        
        // Fail if success rate is too low
        if (successRate < 0.7) { // Require 70% success rate
            fail("Network partition caused too many failures: " + String.format("%.1f%%", successRate * 100) + " success rate");
        }
    }

    @Test
    @DisplayName("Test with leap year date handling")
    void testLeapYearDateHandling() {
        // Test date handling around leap year edge cases
        int[] leapYears = {2020, 2024, 2028};
        int testYear = leapYears[random.nextInt(leapYears.length)];
        
        // Test February 29th handling
        try {
            Instant leapDay = Instant.parse(testYear + "-02-29T12:00:00Z");
            Instant dayAfter = leapDay.plusSeconds(24 * 3600);
            
            Transaction tx = new Transaction();
            tx.setTransactionId(UUID.randomUUID().toString());
            tx.setFromAccountNum("1234567890");
            tx.setToAccountNum("0987654321");
            tx.setAmount(BigDecimal.valueOf(100.00));
            tx.setTimestamp(leapDay);

            // Date arithmetic that might fail in non-leap years
            if (dayAfter.atOffset(ZoneOffset.UTC).getDayOfMonth() != 1) {
                fail("Leap year date handling failed: " + leapDay + " + 1 day = " + dayAfter);
            }

            when(transactionRepository.save(tx)).thenReturn(tx);
            
        } catch (Exception e) {
            fail("Leap year date processing failed: " + e.getMessage());
        }
    }

    @Test
    @DisplayName("Test with database constraint violation timing")
    void testDatabaseConstraintViolationTiming() {
        List<Transaction> conflictingTransactions = new ArrayList<>();
        
        // Create potentially conflicting transactions
        String sharedAccount = "shared_account_123";
        BigDecimal totalWithdraws = BigDecimal.ZERO;
        BigDecimal accountBalance = BigDecimal.valueOf(1000); // Simulate account balance
        
        for (int i = 0; i < random.nextInt(20) + 10; i++) {
            Transaction tx = new Transaction();
            tx.setTransactionId(UUID.randomUUID().toString());
            tx.setFromAccountNum(sharedAccount);
            tx.setToAccountNum("target_" + i);
            
            BigDecimal amount = BigDecimal.valueOf(random.nextDouble() * 200 + 50); // 50-250
            tx.setAmount(amount);
            totalWithdraws = totalWithdraws.add(amount);
            
            conflictingTransactions.add(tx);
        }
        
        // Process transactions - might violate balance constraint
        for (Transaction tx : conflictingTransactions) {
            if (totalWithdraws.compareTo(accountBalance) > 0) {
                fail("Insufficient funds constraint violation: withdrawing " + totalWithdraws + " from balance " + accountBalance);
            }
            
            // Simulate decreasing balance
            accountBalance = accountBalance.subtract(tx.getAmount());
            if (accountBalance.compareTo(BigDecimal.ZERO) < 0) {
                fail("Negative balance constraint violation: " + accountBalance);
            }
        }
    }
}