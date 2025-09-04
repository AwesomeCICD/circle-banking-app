#!/bin/bash

# Local testing script for flaky tests before pushing to CircleCI
# This runs the flaky test simulation multiple times to verify behavior

echo "🔬 LOCAL FLAKY TEST VERIFICATION"
echo "================================"
echo ""

# Check if we have the required files
echo "✅ Checking flaky test files exist..."
for file in \
    "src/contacts/tests/test_flaky_contacts.py" \
    "src/userservice/tests/test_flaky_userservice.py" \
    "src/balancereader/src/test/java/com/circleci/samples/bankcorp/balancereader/FlakyBalanceReaderTest.java" \
    "src/ledgerwriter/src/test/java/com/circleci/samples/bankcorp/ledgerwriter/FlakyLedgerWriterTest.java"
do
    if [ -f "$file" ]; then
        echo "  ✓ Found: $file"
    else
        echo "  ✗ Missing: $file"
        exit 1
    fi
done

echo ""
echo "✅ Checking CircleCI configs..."
if [ -f ".circleci/config.yml" ]; then
    echo "  ✓ Main config exists"
fi
if [ -f ".circleci/flaky-demo-config.yml" ]; then
    echo "  ✓ Lightweight flaky demo config exists"
fi

echo ""
echo "📊 Running Flaky Test Simulation (3 runs)..."
echo "Each run should show ~35% failure rate"
echo ""

for i in 1 2 3; do
    echo "Run $i:"
    python3 demo-assets/simulate-flaky-tests.py 2>/dev/null | grep -E "Run #1 Summary|Total Tests:|Passed:|Failed:" | head -4
    echo ""
    sleep 1
done

echo ""
echo "💡 How to use the configs:"
echo ""
echo "1. DEFAULT PUSH (uses main config):"
echo "   git add -A && git commit -m 'message' && git push"
echo ""
echo "2. LIGHTWEIGHT FLAKY TEST ONLY (via API):"
echo "   export CIRCLECI_TOKEN='your-token'"
echo "   ./demo-assets/trigger-flaky-demo.sh 5"
echo ""
echo "3. CHECK CURRENT CHANGES:"
echo "   git status --short"
echo ""

# Show current git status
echo "Current Git Status:"
git status --short
