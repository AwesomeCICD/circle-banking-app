# Cost-Effective Flaky Test Demo Guide

## 🎯 The Challenge
Running 5+ full pipelines just to demonstrate flaky test detection is expensive and time-consuming. Here are better alternatives:

## Option 1: Lightweight Test-Only Pipeline (Most Realistic)
**Cost: ~80% less than full pipeline**

### Setup:
1. Use the lightweight config that ONLY runs tests:
```bash
# This config skips all builds, deployments, and resource-heavy jobs
.circleci/flaky-demo-config.yml
```

2. Trigger multiple runs with our script:
```bash
# Set your CircleCI API token
export CIRCLECI_TOKEN='your-token-here'

# Trigger 5 lightweight runs
./demo-assets/trigger-flaky-demo.sh 5
```

### Benefits:
- ✅ Real CircleCI test data
- ✅ ~2-3 minutes per run vs 15+ for full pipeline
- ✅ Uses `medium` resource class instead of `xlarge`
- ✅ No Docker builds or deployments
- ✅ Still generates real flaky test insights

## Option 2: Local Simulation (Zero Cost)
**Cost: FREE - No CircleCI credits used**

### Run the simulation:
```bash
python3 demo-assets/simulate-flaky-tests.py
```

### What it shows:
- Simulates 5 pipeline runs locally
- Shows the ~35% failure rate in action
- Demonstrates how tests pass/fail inconsistently
- Analyzes results to identify flaky tests
- Perfect for explaining the concept without spending credits

### Sample Output:
```
Pipeline Run #1
Python - Contacts:
  ✅ test_timing_dependent_contact_creation: passed
  ❌ test_random_failure_contact_validation: failed
  ✅ test_race_condition_contact_list: passed
  ...

FLAKY TEST ANALYSIS
🔍 FLAKY TESTS DETECTED: 37
These tests showed inconsistent behavior across runs:
  📊 Python - Contacts/test_timing_dependent_contact_creation
     Passed: 3/5 runs
     Failed: 2/5 runs
     Flakiness Score: 40.0%
```

## Option 3: Hybrid Approach (Recommended for Sales Demos)
**Best balance of cost and authenticity**

1. **Start with local simulation** to explain the concept
2. **Run 2-3 lightweight pipelines** to show real CircleCI UI
3. **Show pre-recorded screenshots** of mature flaky test detection

### Pre-Demo Setup:
```bash
# Run this once before your demo to seed some data
export CIRCLECI_TOKEN='your-token'
./demo-assets/trigger-flaky-demo.sh 3

# Wait for runs to complete (~10 minutes total)
# Then during demo, trigger 1-2 more to show live
```

## Option 4: API-Based Approach
**For technical audiences**

Create a script that uses CircleCI API to:
1. Trigger test-only jobs
2. Poll for results
3. Re-trigger failed tests
4. Generate a flaky test report

```python
# This approach lets you:
# - Control exactly which tests run
# - Minimize resource usage
# - Generate results faster
# - Show API integration capabilities
```

## Cost Comparison

| Approach | Time | Credits Used | Realism |
|----------|------|-------------|---------|
| Full Pipeline x5 | 75+ min | High | 100% |
| Lightweight x5 | 15 min | Low | 95% |
| Local Simulation | 30 sec | None | 60% |
| Hybrid (3 light + demo) | 10 min | Very Low | 90% |

## Demo Talk Track

### For Local Simulation:
"Let me show you how flaky tests behave across multiple runs. This simulation demonstrates what happens in our CI environment..."

### For Lightweight Pipeline:
"I've created a focused test pipeline that isolates just our test suite. This gives us the same flaky test detection without the overhead of building and deploying..."

### For Hybrid:
"I've already run a few test cycles to seed our data. Now let me trigger one more run live, and while that's running, I'll show you the insights we've already gathered..."

## Quick Commands Reference

```bash
# Make scripts executable
chmod +x demo-assets/*.sh demo-assets/*.py

# Run local simulation
python3 demo-assets/simulate-flaky-tests.py

# Trigger lightweight pipelines
export CIRCLECI_TOKEN='your-token'
./demo-assets/trigger-flaky-demo.sh 5

# Check results in CircleCI UI
# https://app.circleci.com/insights/github/AwesomeCICD/circle-banking-app/workflows/flaky-test-demo
```

## Tips for Maximum Impact

1. **Start with the problem**: Show the local simulation first to demonstrate the pain of flaky tests
2. **Show the solution**: Trigger 1-2 lightweight runs live during the demo
3. **Focus on value**: Emphasize time saved, confidence gained, and cost reduced
4. **Use pre-seeded data**: Have some runs already complete before the demo starts

## Remember
- The lightweight pipeline runs in ~3 minutes vs 15+ for full pipeline
- You only need 3-5 runs for CircleCI to detect patterns
- The simulation accurately represents the 35% failure rate
- This approach saves ~80% on demo costs while maintaining authenticity
