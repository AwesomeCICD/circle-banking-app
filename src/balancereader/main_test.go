package main

import (
	"testing"
)

func TestAccountPattern(t *testing.T) {
	if !accountPattern.MatchString("1011226111") {
		t.Fatal("expected valid account")
	}
	if accountPattern.MatchString("abc") {
		t.Fatal("expected invalid account")
	}
}
