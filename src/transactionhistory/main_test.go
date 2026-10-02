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

func TestAccountPatternInvalid(t *testing.T) {
	if accountPattern.MatchString("notanacct") {
		t.Fatal("expected invalid account")
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

func TestEnvIntDefault(t *testing.T) {
	os.Unsetenv("TEST_ENV_INT")
	if envInt("TEST_ENV_INT", 42) != 42 {
		t.Fatal("expected default int")
	}
}

func TestEnvIntFromEnv(t *testing.T) {
	os.Setenv("TEST_ENV_INT", "99")
	defer os.Unsetenv("TEST_ENV_INT")
	if envInt("TEST_ENV_INT", 42) != 99 {
		t.Fatal("expected env int override")
	}
}

func TestEnvIntInvalidUsesDefault(t *testing.T) {
	os.Setenv("TEST_ENV_INT", "0")
	defer os.Unsetenv("TEST_ENV_INT")
	if envInt("TEST_ENV_INT", 42) != 42 {
		t.Fatal("expected default when env int is non-positive")
	}
}
