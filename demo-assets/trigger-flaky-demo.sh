#!/bin/bash

# Script to trigger multiple lightweight test runs for flaky test detection
# Usage: ./trigger-flaky-demo.sh <number-of-runs>

CIRCLECI_TOKEN=${CIRCLECI_TOKEN:-"YOUR_CIRCLECI_API_TOKEN"}
ORG="AwesomeCICD"
PROJECT="circle-banking-app"
BRANCH="demo-nk-fe"
NUM_RUNS=${1:-5}  # Default to 5 runs if not specified

echo "🚀 Triggering $NUM_RUNS lightweight test runs for flaky detection..."
echo "This will only run the test jobs, not the full pipeline."

# Function to trigger a pipeline with custom config
trigger_pipeline() {
    local run_number=$1
    echo "Triggering run $run_number/$NUM_RUNS..."
    
    response=$(curl -s -X POST \
        -H "Circle-Token: $CIRCLECI_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "branch": "'$BRANCH'",
            "parameters": {
                "config": ".circleci/flaky-demo-config.yml"
            }
        }' \
        "https://circleci.com/api/v2/project/gh/$ORG/$PROJECT/pipeline")
    
    pipeline_id=$(echo $response | grep -o '"id":"[^"]*' | sed 's/"id":"//')
    
    if [ -n "$pipeline_id" ]; then
        echo "✅ Run $run_number triggered: Pipeline ID $pipeline_id"
        echo "   View at: https://app.circleci.com/pipelines/github/$ORG/$PROJECT?branch=$BRANCH"
    else
        echo "❌ Failed to trigger run $run_number"
        echo "Response: $response"
    fi
    
    # Small delay between triggers
    sleep 2
}

# Check if token is set
if [ "$CIRCLECI_TOKEN" = "YOUR_CIRCLECI_API_TOKEN" ]; then
    echo "❌ Please set your CircleCI API token:"
    echo "   export CIRCLECI_TOKEN='your-token-here'"
    echo "   Get token from: https://app.circleci.com/settings/user/tokens"
    exit 1
fi

# Trigger multiple runs
for i in $(seq 1 $NUM_RUNS); do
    trigger_pipeline $i
done

echo ""
echo "✅ All runs triggered!"
echo "📊 After runs complete, view flaky tests at:"
echo "   https://app.circleci.com/insights/github/$ORG/$PROJECT/workflows/flaky-test-demo"
echo ""
echo "💡 Tips:"
echo "   - Tests have ~35% failure rate, so you should see mixed results"
echo "   - CircleCI needs 3-5 runs to identify flaky patterns"
echo "   - Check the Tests tab after all runs complete"
