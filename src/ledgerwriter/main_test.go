package main

import (
	"testing"
)

const testLocalRoute = "123456789"

func validTxn() txnRequest {
	return txnRequest{
		FromAccountNum: "1011226111",
		FromRoutingNum: testLocalRoute,
		ToAccountNum:   "1011226222",
		ToRoutingNum:   "987654321",
		Amount:         100,
	}
}

func TestAccountPatternValid(t *testing.T) {
	if !accountPattern.MatchString("1011226111") {
		t.Fatal("expected valid account")
	}
}

func TestAccountPatternInvalid(t *testing.T) {
	if accountPattern.MatchString("abc") {
		t.Fatal("expected invalid account")
	}
	if accountPattern.MatchString("123") {
		t.Fatal("expected short account to be invalid")
	}
}

func TestRoutePatternValid(t *testing.T) {
	if !routePattern.MatchString(testLocalRoute) {
		t.Fatal("expected valid routing number")
	}
}

func TestRoutePatternInvalid(t *testing.T) {
	if routePattern.MatchString("12345") {
		t.Fatal("expected invalid routing number")
	}
}

func TestValidateRequestOK(t *testing.T) {
	if err := validateRequest(validTxn(), testLocalRoute); err != nil {
		t.Fatalf("expected valid request: %v", err)
	}
}

func TestValidateRequestBadAccount(t *testing.T) {
	req := validTxn()
	req.FromAccountNum = "bad"
	if err := validateRequest(req, testLocalRoute); err == nil {
		t.Fatal("expected invalid account error")
	}
}

func TestValidateRequestBadRouting(t *testing.T) {
	req := validTxn()
	req.FromRoutingNum = "12345"
	if err := validateRequest(req, testLocalRoute); err == nil {
		t.Fatal("expected invalid routing error")
	}
}

func TestValidateRequestBadAmount(t *testing.T) {
	req := validTxn()
	req.Amount = 0
	if err := validateRequest(req, testLocalRoute); err == nil {
		t.Fatal("expected non-positive amount error")
	}
}

func TestValidateRequestSameParties(t *testing.T) {
	req := validTxn()
	req.ToAccountNum = req.FromAccountNum
	req.ToRoutingNum = req.FromRoutingNum
	if err := validateRequest(req, testLocalRoute); err == nil {
		t.Fatal("expected same sender/receiver error")
	}
}

func TestValidateRequestNoLocalAccount(t *testing.T) {
	req := validTxn()
	req.FromRoutingNum = "111111111"
	req.ToRoutingNum = "222222222"
	if err := validateRequest(req, testLocalRoute); err == nil {
		t.Fatal("expected no local account error")
	}
}
