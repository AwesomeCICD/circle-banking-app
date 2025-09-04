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
import io.micrometer.stackdriver.StackdriverConfig;
import io.micrometer.stackdriver.StackdriverMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;

import javax.annotation.Nullable;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.fail;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.mockito.MockitoAnnotations.initMocks;

/**
 * Flaky tests for LedgerWriter service to demonstrate CircleCI's flaky test detection
 */
@DisplayName("Flaky tests for LedgerWriter")
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
        StackdriverConfig stackdriverConfig = new StackdriverConfig() {
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
        };
        StackdriverMeterRegistry meterRegistry = StackdriverMeterRegistry.builder(stackdriverConfig).build();

        ledgerWriterController = new LedgerWriterController(
            verifier, meterRegistry, transactionRepository, transactionValidator,
            LOCAL_ROUTING_NUM, "http://" + BALANCES_API_ADDR + "/balances", VERSION);

        when(verifier.verify(anyString())).thenReturn(jwt);
        when(jwt.getClaim(anyString())).thenReturn(claim);
        when(claim.asString()).thenReturn("test-account");
    }

    @Test
    @DisplayName("Test that fails based on transaction ordering")
    void testTransactionOrderDependentBehavior() {
        List<Transaction> transactions = new ArrayList<>();
        
        // Create mocked transactions with random ordering
        for (int i = 0; i < random.nextInt(20) + 10; i++) {
            Transaction tx = mock(Transaction.class);
            when(tx.getFromAccountNum()).thenReturn("1234567890");
            when(tx.getToAccountNum()).thenReturn("0987654321");
            when(tx.getAmount()).thenReturn(random.nextInt(1000));
            transactions.add(tx);
        }

        // Shuffle transactions - some orders might fail validation
        Collections.shuffle(transactions);

        // Process transactions in random order
        int runningBalance = 0;
        for (Transaction tx : transactions) {
            runningBalance = runningBalance + tx.getAmount();
            
            // This check will be flaky based on transaction order (85% failure)
            if ((runningBalance > 5000) || random.nextDouble() < 0.85) {
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
                
                Transaction tx = mock(Transaction.class);
                when(tx.getFromAccountNum()).thenReturn(accountA);
                when(tx.getToAccountNum()).thenReturn(accountB);
                when(tx.getAmount()).thenReturn(random.nextInt(100));

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
        int[] testAmounts = {
            1,       // 1 cent
            999999,  // Large amount
            333,     // Amount that divides unevenly
            30,      // 0.1 + 0.2 = 0.3 in cents
        };

        for (int amount : testAmounts) {
            Transaction tx = mock(Transaction.class);
            when(tx.getFromAccountNum()).thenReturn("1234567890");
            when(tx.getToAccountNum()).thenReturn("0987654321");
            when(tx.getAmount()).thenReturn(amount);

            // Precision validation that might be flaky
            double dollarAmount = amount / 100.0;
            double roundedAmount = Math.round(dollarAmount * 100) / 100.0;
            if (Math.abs(dollarAmount - roundedAmount) > 0.001 && random.nextDouble() < 0.8) {
                fail("Precision loss detected for amount: " + amount + " cents");
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
            
            // Business logic that depends on time zone (80% failure during off-hours)
            if ((hourOfDay < 6 || hourOfDay > 22) && random.nextDouble() < 0.8) {
                fail("Transactions not allowed during off-hours in timezone " + zone + " (hour: " + hourOfDay + ")");
            }
        }

        Transaction tx = mock(Transaction.class);
        when(tx.getFromAccountNum()).thenReturn("1234567890");
        when(tx.getToAccountNum()).thenReturn("0987654321");
        when(tx.getAmount()).thenReturn(100);

        // Check if transaction is allowed based on local time
        LocalTime localTime = LocalTime.now();
        if (localTime.isBefore(LocalTime.of(9, 0)) || localTime.isAfter(LocalTime.of(17, 0))) {
            fail("Transaction outside business hours: " + localTime);
        }
    }

    @Test
    @DisplayName("Test with garbage collection interference")
    void testGarbageCollectionInterference() {
        List<byte[]> memoryConsumer = new ArrayList<>();
        
        try {
            // Consume memory to trigger GC (85% failure rate)
            for (int i = 0; i < random.nextInt(100) + 50; i++) {
                memoryConsumer.add(new byte[1024 * 1024]); // 1MB chunks
                
                if (random.nextDouble() < 0.85) {
                    System.gc(); // Suggest garbage collection
                    Thread.sleep(10);
                }
                
                Transaction tx = mock(Transaction.class);
                when(tx.getFromAccountNum()).thenReturn("ACC" + i);
                when(tx.getToAccountNum()).thenReturn("ACC" + (i + 1));
                when(tx.getAmount()).thenReturn(random.nextInt(100));
                
                when(transactionRepository.save(tx)).thenReturn(tx);
            }
            
            // Check if GC caused issues
            Runtime runtime = Runtime.getRuntime();
            long usedMemory = runtime.totalMemory() - runtime.freeMemory();
            long maxMemory = runtime.maxMemory();
            
            if (usedMemory > maxMemory * 0.8) {
                fail("Memory pressure too high: " + (usedMemory * 100 / maxMemory) + "%");
            }
        } catch (InterruptedException e) {
            fail("Test interrupted during memory allocation");
        } finally {
            memoryConsumer.clear();
        }
    }

    @Test
    @DisplayName("Test with connection pool exhaustion")
    void testConnectionPoolExhaustion() throws InterruptedException {
        int poolSize = 10;
        Semaphore connectionPool = new Semaphore(poolSize);
        AtomicInteger failureCount = new AtomicInteger(0);
        
        Runnable databaseOperation = () -> {
            boolean acquired = false;
            try {
                // Try to acquire connection with timeout
                acquired = connectionPool.tryAcquire(50, TimeUnit.MILLISECONDS);
                
                if (!acquired) {
                    failureCount.incrementAndGet();
                    return;
                }
                
                // Simulate database operation
                Transaction tx = mock(Transaction.class);
                when(tx.getFromAccountNum()).thenReturn("ACC" + random.nextInt(100));
                when(tx.getToAccountNum()).thenReturn("ACC" + random.nextInt(100));
                when(tx.getAmount()).thenReturn(random.nextInt(1000));
                
                Thread.sleep(random.nextInt(100)); // Simulate work
                
                when(transactionRepository.save(tx)).thenReturn(tx);
                
            } catch (InterruptedException e) {
                failureCount.incrementAndGet();
            } finally {
                if (acquired) {
                    connectionPool.release();
                }
            }
        };
        
        // Create many concurrent operations to exhaust pool
        ExecutorService executor = Executors.newFixedThreadPool(50);
        for (int i = 0; i < 100; i++) {
            executor.submit(databaseOperation);
        }
        
        executor.shutdown();
        executor.awaitTermination(5, TimeUnit.SECONDS);
        
        // Flaky assertion - 80% failure rate if connections were exhausted
        if (failureCount.get() > 5 || random.nextDouble() < 0.8) {
            fail("Connection pool exhausted: " + failureCount.get() + " failures");
        }
    }

    @Test
    @DisplayName("Test with duplicate transaction ID race condition")
    void testDuplicateTransactionIdRaceCondition() throws InterruptedException {
        Map<String, Integer> transactionIds = new ConcurrentHashMap<>();
        AtomicInteger duplicateCount = new AtomicInteger(0);
        
        Runnable transactionCreator = () -> {
            for (int i = 0; i < 10; i++) {
                String transactionId = "TXN_" + random.nextInt(100);
                
                Integer previousCount = transactionIds.putIfAbsent(transactionId, 1);
                if (previousCount != null) {
                    duplicateCount.incrementAndGet();
                    
                    // Simulate duplicate transaction handling
                    Transaction tx = mock(Transaction.class);
                    when(tx.getRequestUuid()).thenReturn(transactionId);
                    when(tx.getFromAccountNum()).thenReturn("ACC001");
                    when(tx.getToAccountNum()).thenReturn("ACC002");
                    when(tx.getAmount()).thenReturn(100);
                    
                    when(transactionRepository.save(tx))
                        .thenThrow(new DataIntegrityViolationException("Duplicate transaction ID"));
                }
            }
        };
        
        // Run concurrent threads that might create duplicates
        ExecutorService executor = Executors.newFixedThreadPool(20);
        for (int i = 0; i < 20; i++) {
            executor.submit(transactionCreator);
        }
        
        executor.shutdown();
        executor.awaitTermination(5, TimeUnit.SECONDS);
        
        // Flaky check - 85% failure if duplicates detected
        if (duplicateCount.get() > 0 || random.nextDouble() < 0.85) {
            fail("Duplicate transaction IDs detected: " + duplicateCount.get());
        }
    }

    @Test
    @DisplayName("Test with network partition simulation")
    void testNetworkPartitionBehavior() {
        // Simulate network delays and partitions
        int[] networkDelays = {0, 100, 500, 1000, 5000}; // milliseconds
        
        for (int delay : networkDelays) {
            try {
                if (delay > 0) {
                    Thread.sleep(delay);
                }
                
                // Simulate network partition (75% failure for high delays)
                if (delay > 1000 && random.nextDouble() < 0.75) {
                    throw new DataAccessResourceFailureException("Network partition detected");
                }
                
                // Try to save transaction
                Transaction tx = mock(Transaction.class);
                when(tx.getFromAccountNum()).thenReturn("1234567890");
                when(tx.getToAccountNum()).thenReturn("0987654321");
                when(tx.getAmount()).thenReturn(100);
                
                when(transactionRepository.save(tx)).thenReturn(tx);
                
                // Check if operation succeeded within timeout
                if (delay > 2000) {
                    fail("Operation timeout after " + delay + "ms");
                }
                
            } catch (InterruptedException e) {
                fail("Network operation interrupted");
            } catch (DataAccessResourceFailureException e) {
                fail("Network partition caused failure: " + e.getMessage());
            }
        }
    }

    @Test
    @DisplayName("Test with leap year date handling")
    void testLeapYearDateHandling() {
        // Test dates around leap year boundaries
        LocalDate[] testDates = {
            LocalDate.of(2020, 2, 29), // Leap year date
            LocalDate.of(2021, 2, 28), // Non-leap year
            LocalDate.of(2024, 2, 29), // Next leap year
        };
        
        for (LocalDate date : testDates) {
            Transaction tx = mock(Transaction.class);
            when(tx.getFromAccountNum()).thenReturn("1234567890");
            when(tx.getToAccountNum()).thenReturn("0987654321");
            when(tx.getAmount()).thenReturn(100);
            
            // Check if date is valid for transactions (80% failure for leap day)
            if (date.getDayOfMonth() == 29 && date.getMonthValue() == 2) {
                if (random.nextDouble() < 0.8) {
                    fail("Special handling required for leap year date: " + date);
                }
            }
            
            // Simulate date-based business logic
            DayOfWeek dayOfWeek = date.getDayOfWeek();
            if (dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY) {
                fail("Transactions not allowed on weekends: " + date);
            }
        }
    }

    @Test
    @DisplayName("Test with database constraint violation timing")
    void testDatabaseConstraintViolationTiming() {
        // Test various constraint scenarios
        for (int i = 0; i < 10; i++) {
            Transaction tx = mock(Transaction.class);
            when(tx.getFromAccountNum()).thenReturn("1234567890");
            when(tx.getToAccountNum()).thenReturn("0987654321");
            when(tx.getAmount()).thenReturn(100);
            
            // Randomly violate different constraints (85% total failure rate)
            double randomValue = random.nextDouble();
            if (randomValue < 0.3) {
                // Foreign key violation
                when(transactionRepository.save(tx))
                    .thenThrow(new DataIntegrityViolationException("Foreign key constraint violation"));
                fail("Foreign key constraint violated");
            } else if (randomValue < 0.6) {
                // Unique constraint violation  
                when(transactionRepository.save(tx))
                    .thenThrow(new DataIntegrityViolationException("Unique constraint violation"));
                fail("Unique constraint violated");
            } else if (randomValue < 0.85) {
                // Check constraint violation
                when(transactionRepository.save(tx))
                    .thenThrow(new DataIntegrityViolationException("Check constraint violation"));
                fail("Check constraint violated");
            } else {
                // Success case
                when(transactionRepository.save(tx)).thenReturn(tx);
            }
        }
    }
}