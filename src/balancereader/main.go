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

type balanceRecord struct {
	AccountID string `dynamodbav:"accountId"`
	Balance   int64  `dynamodbav:"balance"`
}

func main() {
	port := env("PORT", "8080")
	version := env("VERSION", "dev")
	table := mustEnv("DYNAMODB_BALANCES_TABLE")
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
	mux.HandleFunc("/balances/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		accountID := strings.TrimPrefix(r.URL.Path, "/balances/")
		if !accountPattern.MatchString(accountID) {
			http.Error(w, "invalid account", http.StatusBadRequest)
			return
		}
		if !authorize(r, pubKey, accountID) {
			http.Error(w, "not authorized", http.StatusUnauthorized)
			return
		}
		balance, err := getBalance(r.Context(), ddb, table, accountID)
		if err != nil {
			log.Printf("balance error: %v", err)
			http.Error(w, "cache error", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(balance)
	})

	log.Printf("balancereader listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func getBalance(ctx context.Context, ddb *dynamodb.Client, table, accountID string) (int64, error) {
	out, err := ddb.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: &table,
		Key: map[string]types.AttributeValue{
			"accountId": &types.AttributeValueMemberS{Value: accountID},
		},
	})
	if err != nil {
		return 0, err
	}
	if out.Item == nil {
		return 0, nil
	}
	var rec balanceRecord
	if err := attributevalue.UnmarshalMap(out.Item, &rec); err != nil {
		return 0, err
	}
	return rec.Balance, nil
}

func authorize(r *http.Request, pubKey interface{}, accountID string) bool {
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Bearer ") {
		return false
	}
	token, err := jwt.Parse(auth[7:], func(t *jwt.Token) (interface{}, error) {
		if t.Method.Alg() != jwt.SigningMethodRS256.Alg() {
			return nil, fmt.Errorf("unexpected alg")
		}
		return pubKey, nil
	})
	if err != nil || !token.Valid {
		return false
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return false
	}
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

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("missing required env %s", k)
	}
	return v
}
