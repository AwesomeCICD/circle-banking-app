package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/golang-jwt/jwt/v5"
)

var accountPattern = regexp.MustCompile(`^\d{10}$`)

type txnRecord struct {
	FromAccountNum string `dynamodbav:"fromAccountNum" json:"fromAccountNum"`
	FromRoutingNum string `dynamodbav:"fromRoutingNum" json:"fromRoutingNum"`
	ToAccountNum   string `dynamodbav:"toAccountNum" json:"toAccountNum"`
	ToRoutingNum   string `dynamodbav:"toRoutingNum" json:"toRoutingNum"`
	Amount         int64  `dynamodbav:"amount" json:"amount"`
	Timestamp      string `dynamodbav:"timestamp" json:"timestamp"`
}

func main() {
	port := env("PORT", "8080")
	version := env("VERSION", "dev")
	table := mustEnv("DYNAMODB_TRANSACTIONS_TABLE")
	limit := envInt("HISTORY_LIMIT", 100)
	pubKey := loadPublicKey(mustEnv("PUB_KEY_PATH"))

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("aws config: %v", err)
	}
	ddb := dynamodb.NewFromConfig(cfg)

	mux := http.NewServeMux()
	mux.HandleFunc("/version", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, version)
	})
	mux.HandleFunc("/ready", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, "ok")
	})
	mux.HandleFunc("/healthy", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, "ok")
	})
	mux.HandleFunc("/transactions/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		accountID := strings.TrimPrefix(r.URL.Path, "/transactions/")
		if !accountPattern.MatchString(accountID) {
			http.Error(w, "invalid account", http.StatusBadRequest)
			return
		}
		if !authorize(r, pubKey, accountID) {
			http.Error(w, "not authorized", http.StatusUnauthorized)
			return
		}
		txns, err := listTransactions(r.Context(), ddb, table, accountID, limit)
		if err != nil {
			log.Printf("query error: %v", err)
			http.Error(w, "cache error", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(txns)
	})

	log.Printf("transactionhistory listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func listTransactions(ctx context.Context, ddb *dynamodb.Client, table, accountID string, limit int) ([]txnRecord, error) {
	limit32 := int32(limit)
	out, err := ddb.Query(ctx, &dynamodb.QueryInput{
		TableName:              &table,
		KeyConditionExpression: strPtr("accountId = :aid"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":aid": &types.AttributeValueMemberS{Value: accountID},
		},
		ScanIndexForward: boolPtr(false),
		Limit:            &limit32,
	})
	if err != nil {
		return nil, err
	}
	txns := make([]txnRecord, 0, len(out.Items))
	for _, item := range out.Items {
		var rec txnRecord
		if err := attributevalue.UnmarshalMap(item, &rec); err != nil {
			return nil, err
		}
		txns = append(txns, rec)
	}
	return txns, nil
}

func authorize(r *http.Request, pubKey interface{}, accountID string) bool {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		return false
	}
	token, err := jwt.Parse(auth[7:], func(t *jwt.Token) (interface{}, error) {
		return pubKey, nil
	})
	if err != nil || !token.Valid {
		return false
	}
	claims, _ := token.Claims.(jwt.MapClaims)
	acct, _ := claims["acct"].(string)
	return acct == accountID
}

func loadPublicKey(path string) interface{} {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Fatalf("read public key: %v", err)
	}
	key, err := jwt.ParseRSAPublicKeyFromPEM(data)
	if err != nil {
		log.Fatalf("parse public key: %v", err)
	}
	return key
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		var n int
		fmt.Sscanf(v, "%d", &n)
		if n > 0 {
			return n
		}
	}
	return def
}

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("missing required env %s", k)
	}
	return v
}

func strPtr(s string) *string { return &s }
func boolPtr(b bool) *bool    { return &b }
