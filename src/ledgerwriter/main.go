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
	"time"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/golang-jwt/jwt/v5"
)

var (
	accountPattern = regexp.MustCompile(`^\d{10}$`)
	routePattern   = regexp.MustCompile(`^\d{9}$`)
)

type txnRequest struct {
	FromAccountNum string `json:"fromAccountNum"`
	FromRoutingNum string `json:"fromRoutingNum"`
	ToAccountNum   string `json:"toAccountNum"`
	ToRoutingNum   string `json:"toRoutingNum"`
	Amount         int64  `json:"amount"`
	UUID           string `json:"uuid"`
}

type txnRecord struct {
	AccountID       string `dynamodbav:"accountId"`
	TimestampTxnID  string `dynamodbav:"timestampTxnId"`
	FromAccountNum  string `dynamodbav:"fromAccountNum"`
	FromRoutingNum  string `dynamodbav:"fromRoutingNum"`
	ToAccountNum    string `dynamodbav:"toAccountNum"`
	ToRoutingNum    string `dynamodbav:"toRoutingNum"`
	Amount          int64  `dynamodbav:"amount"`
	Timestamp       string `dynamodbav:"timestamp"`
}

func main() {
	port := env("PORT", "8080")
	version := env("VERSION", "dev")
	localRoute := mustEnv("LOCAL_ROUTING_NUM")
	txnTable := mustEnv("DYNAMODB_TRANSACTIONS_TABLE")
	balTable := mustEnv("DYNAMODB_BALANCES_TABLE")
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
	mux.HandleFunc("/transactions", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var req txnRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
		if err := validateRequest(req, localRoute); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		fromLocal := req.FromRoutingNum == localRoute
		if fromLocal && !authorize(r, pubKey, req.FromAccountNum) {
			http.Error(w, "not authorized", http.StatusUnauthorized)
			return
		}
		if err := writeTransaction(r.Context(), ddb, txnTable, balTable, req, localRoute); err != nil {
			log.Printf("write error: %v", err)
			if strings.Contains(err.Error(), "insufficient") {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusCreated)
		fmt.Fprint(w, "ok")
	})

	log.Printf("ledgerwriter listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func validateRequest(req txnRequest, localRoute string) error {
	if !accountPattern.MatchString(req.FromAccountNum) || !accountPattern.MatchString(req.ToAccountNum) {
		return fmt.Errorf("invalid account number")
	}
	if !routePattern.MatchString(req.FromRoutingNum) || !routePattern.MatchString(req.ToRoutingNum) {
		return fmt.Errorf("invalid routing number")
	}
	if req.Amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}
	if req.FromAccountNum == req.ToAccountNum && req.FromRoutingNum == req.ToRoutingNum {
		return fmt.Errorf("sender and receiver must differ")
	}
	if req.FromRoutingNum != localRoute && req.ToRoutingNum != localRoute {
		return fmt.Errorf("at least one account must be local")
	}
	return nil
}

func writeTransaction(ctx context.Context, ddb *dynamodb.Client, txnTable, balTable string, req txnRequest, localRoute string) error {
	fromLocal := req.FromRoutingNum == localRoute
	toLocal := req.ToRoutingNum == localRoute

	if fromLocal {
		bal, err := getBalance(ctx, ddb, balTable, req.FromAccountNum)
		if err != nil {
			return err
		}
		if bal < req.Amount {
			return fmt.Errorf("insufficient balance")
		}
	}

	ts := time.Now().UTC().Format(time.RFC3339Nano)
	sortKey := fmt.Sprintf("%s#%s", ts, req.UUID)
	rec := txnRecord{
		FromAccountNum: req.FromAccountNum,
		FromRoutingNum: req.FromRoutingNum,
		ToAccountNum:   req.ToAccountNum,
		ToRoutingNum:   req.ToRoutingNum,
		Amount:         req.Amount,
		Timestamp:      ts,
	}

	items := make([]types.TransactWriteItem, 0, 4)
	if fromLocal {
		item, _ := attributevalue.MarshalMap(txnRecord{
			AccountID:      req.FromAccountNum,
			TimestampTxnID: sortKey,
			FromAccountNum: rec.FromAccountNum,
			FromRoutingNum: rec.FromRoutingNum,
			ToAccountNum:   rec.ToAccountNum,
			ToRoutingNum:   rec.ToRoutingNum,
			Amount:         rec.Amount,
			Timestamp:      rec.Timestamp,
		})
		items = append(items, types.TransactWriteItem{Put: &types.Put{TableName: &txnTable, Item: item}})
		items = append(items, types.TransactWriteItem{Update: &types.Update{
			TableName: &balTable,
			Key: map[string]types.AttributeValue{
				"accountId": &types.AttributeValueMemberS{Value: req.FromAccountNum},
			},
			UpdateExpression:          strPtr("ADD balance :dec"),
			ExpressionAttributeValues: map[string]types.AttributeValue{":dec": &types.AttributeValueMemberN{Value: fmt.Sprintf("-%d", req.Amount)}},
		}})
	}
	if toLocal {
		item, _ := attributevalue.MarshalMap(txnRecord{
			AccountID:      req.ToAccountNum,
			TimestampTxnID: sortKey,
			FromAccountNum: rec.FromAccountNum,
			FromRoutingNum: rec.FromRoutingNum,
			ToAccountNum:   rec.ToAccountNum,
			ToRoutingNum:   rec.ToRoutingNum,
			Amount:         rec.Amount,
			Timestamp:      rec.Timestamp,
		})
		items = append(items, types.TransactWriteItem{Put: &types.Put{TableName: &txnTable, Item: item}})
		items = append(items, types.TransactWriteItem{Update: &types.Update{
			TableName: &balTable,
			Key: map[string]types.AttributeValue{
				"accountId": &types.AttributeValueMemberS{Value: req.ToAccountNum},
			},
			UpdateExpression:          strPtr("ADD balance :inc"),
			ExpressionAttributeValues: map[string]types.AttributeValue{":inc": &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", req.Amount)}},
		}})
	}

	_, err := ddb.TransactWriteItems(ctx, &dynamodb.TransactWriteItemsInput{TransactItems: items})
	return err
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
	if v, ok := out.Item["balance"].(*types.AttributeValueMemberN); ok {
		var bal int64
		fmt.Sscanf(v.Value, "%d", &bal)
		return bal, nil
	}
	return 0, nil
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

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("missing required env %s", k)
	}
	return v
}

func strPtr(s string) *string { return &s }
