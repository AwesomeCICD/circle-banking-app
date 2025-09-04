# CircleCI Flaky Test Detection Demo Guide

## Overview
This guide explains how to effectively demonstrate CircleCI's automatic flaky test detection feature using the banking app repository.

## What Are Flaky Tests?
Flaky tests are tests that exhibit non-deterministic behavior - they pass and fail intermittently without any code changes. These tests are problematic because they:
- Reduce confidence in your test suite
- Waste developer time investigating false failures
- Slow down CI/CD pipelines with unnecessary reruns

## Current Flaky Test Implementation

### Python Flaky Tests
1. **`test_flaky_contacts.py`** - Contact service flaky tests
   - Floating-point precision issues (~30% failure rate)
   - Race conditions in concurrent operations
   - External dependency timeouts
   - Order-dependent operations

2. **`test_flaky_userservice.py`** - User service flaky tests  
   - Concurrent user creation race conditions
   - JWT token timing attacks
   - System clock drift sensitivity (~40% failure rate)
   - Memory leak simulations

### Java Flaky Tests
1. **`FlakyBalanceReaderTest.java`** - Balance reader flaky tests
   - Timing-dependent balance retrieval (~30% failure rate)
   - Random cache access failures (~40% failure rate)
   - Concurrency issues
   - Floating-point precision problems

2. **`FlakyLedgerWriterTest.java`** - Ledger writer flaky tests
   - Database deadlock scenarios
   - Connection pool exhaustion
   - Transaction ordering dependencies
   - Network partition simulations

## How CircleCI Detects Flaky Tests

CircleCI automatically detects flaky tests by:
1. **Tracking test results across multiple runs** - Monitors pass/fail patterns
2. **Analyzing inconsistent results** - Identifies tests with varying outcomes
3. **Providing insights** - Shows flakiness trends and statistics
4. **Enabling test retries** - Automatically reruns failed tests to confirm flakiness

## Demo Steps

### Step 1: Initial Setup
1. Ensure you're on the `demo-nk-fe` branch
2. The CircleCI config has been updated with:
   - Python: `--reruns 2 --reruns-delay 1` for pytest
   - Java: `-Dsurefire.rerunFailingTestsCount=2` for Maven

### Step 2: Trigger Multiple Pipeline Runs
1. Push code changes or manually trigger pipelines
2. Run at least 3-5 pipeline executions to generate enough data
3. The flaky tests should show inconsistent pass/fail results

### Step 3: View Flaky Test Detection
1. Navigate to CircleCI Dashboard
2. Go to **Insights** → **Tests** tab
3. Filter by "Flaky Tests" to see detected flaky tests
4. Click on individual tests to see:
   - Flakiness percentage
   - Pass/fail history
   - Duration trends

### Step 4: Demonstrate Features
1. **Test Analytics**
   - Show flakiness trends over time
   - Demonstrate most/least reliable tests
   - Display average test duration impact

2. **Smart Reruns**
   - Show how CircleCI automatically reruns only failed tests
   - Demonstrate time savings vs full suite reruns

3. **Root Cause Analysis**
   - Click into flaky test details
   - Show failure messages and patterns
   - Identify common failure reasons

## Best Practices for the Demo

### DO:
✅ Run multiple pipeline executions (at least 5) before the demo
✅ Explain the business impact of flaky tests (time, cost, confidence)
✅ Show how detection helps prioritize which tests to fix first
✅ Demonstrate the time saved with smart reruns
✅ Highlight the automatic nature of detection (no configuration needed)

### DON'T:
❌ Run only a single pipeline (insufficient data for detection)
❌ Expect immediate detection (needs multiple runs)
❌ Show tests that fail 100% of the time (these aren't flaky)
❌ Ignore the insights tab (this is where the value shows)

## Troubleshooting

### Tests Not Being Detected as Flaky
1. **Ensure multiple runs**: Need at least 3-5 executions
2. **Check failure rates**: Tests should pass 30-70% of the time
3. **Verify test names are consistent**: CircleCI tracks by test name
4. **Allow time for processing**: Detection may take a few minutes

### Tests Failing Too Consistently
- Adjust randomization in test code
- Current implementation targets 30-40% failure rate
- Modify random thresholds if needed

### No Test Results Showing
1. Verify test results are being uploaded (`store_test_results`)
2. Check XML format is correct (JUnit format)
3. Ensure test names are unique and descriptive

## Key Talking Points

1. **Cost of Flaky Tests**
   - "A Google study found that 1.5% of their tests were flaky, but caused 25% of test failures"
   - "Developers spend 2-3 hours per week dealing with flaky tests"

2. **CircleCI's Solution**
   - "Automatic detection with no configuration required"
   - "Smart reruns save 40-60% of time vs full suite reruns"
   - "Historical tracking helps identify patterns"

3. **Business Value**
   - "Faster feedback loops for developers"
   - "Higher confidence in test results"
   - "Reduced infrastructure costs from unnecessary reruns"

## Next Steps After Demo

1. **Fix High-Priority Flaky Tests**
   - Use insights to identify most problematic tests
   - Focus on tests with highest failure impact

2. **Implement Test Stability Metrics**
   - Set team goals for test reliability
   - Track improvement over time

3. **Establish Best Practices**
   - Avoid time-dependent assertions
   - Mock external dependencies
   - Use proper test isolation

## Additional Resources
- [CircleCI Flaky Test Detection Documentation](https://circleci.com/docs/insights-tests/)
- [Best Practices for Avoiding Flaky Tests](https://circleci.com/blog/reducing-flaky-test-failures/)
- [Test Insights API](https://circleci.com/docs/api/v2/#tag/Insights)

---

**Note**: The flaky tests in this demo are intentionally designed to fail intermittently. In a production environment, these would be fixed rather than kept as examples.
