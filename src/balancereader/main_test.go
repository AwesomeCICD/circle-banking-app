package main

import (
	"os"
	"testing"
)

func TestAccountPatternValid(t *testing.T) {
	if !accountPattern.MatchString("1011226111") {
		t.Fatal("expected valid account")
	}
}

func TestAccountPatternInvalidAlpha(t *testing.T) {
	if accountPattern.MatchString("abc") {
		t.Fatal("expected invalid account")
	}
}

func TestAccountPatternInvalidShort(t *testing.T) {
	if accountPattern.MatchString("12345") {
		t.Fatal("expected short account to be invalid")
	}
}

func TestAccountPatternInvalidLong(t *testing.T) {
	if accountPattern.MatchString("12345678901") {
		t.Fatal("expected long account to be invalid")
	}
}

func TestEnvStringDefault(t *testing.T) {
	os.Unsetenv("TEST_ENV_KEY")
	if env("TEST_ENV_KEY", "default") != "default" {
		t.Fatal("expected default env value")
	}
}

func TestEnvStringOverride(t *testing.T) {
	os.Setenv("TEST_ENV_KEY", "override")
	defer os.Unsetenv("TEST_ENV_KEY")
	if env("TEST_ENV_KEY", "default") != "override" {
		t.Fatal("expected overridden env value")
	}
}
